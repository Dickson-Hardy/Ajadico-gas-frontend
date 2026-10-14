import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/bank_deposit.dart';
import '../../models/operations_policy.dart';
import '../../models/shift_adjustment.dart';
import '../../models/credit_customer.dart';
import '../../models/interim_cash_drop.dart';
import '../../models/monthly_payroll_settlement.dart';
import '../../models/nozzle.dart';
import '../../models/pos_transaction.dart';
import '../../models/station.dart';
import '../../models/user_profile.dart';
import '../config/supabase_config.dart';
import '../storage/evidence_reference.dart';
import '../notifications/forecourt_notification.dart';

class SupabaseRepository {
  static final SupabaseRepository instance = SupabaseRepository._internal();
  SupabaseRepository._internal();
  @visibleForTesting
  factory SupabaseRepository.forTesting(SupabaseClient client,
      {required String endpoint, required String publishableKey}) {
    if (kReleaseMode) throw StateError('Test repositories are disabled');
    return SupabaseRepository._internal()
      .._client = client
      .._isConnected = true
      .._baseUrl = endpoint
      .._publicKey = publishableKey;
  }
  String _baseUrl = SupabaseConfig.url;
  String _publicKey = SupabaseConfig.anonKey;

  SupabaseClient? _client;
  bool _isConnected = false;

  String? configurationError;
  bool get isConnected => _isConnected;
  SupabaseClient get client => _client ?? Supabase.instance.client;
  String? _snapshotAuthUserId;
  String? get authUserId =>
      _snapshotAuthUserId ?? _client?.auth.currentUser?.id;
  Stream<String?> get authIdentityChanges =>
      client.auth.onAuthStateChange.map((event) => event.session?.user.id);

  /// Freeze the JWT for one replay batch; switching users cannot change its actor.
  SupabaseRepository? snapshotForAuthenticatedSession() {
    final session = _client?.auth.currentSession;
    if (!_isConnected || session == null || session.isExpired) return null;
    final snapshot = SupabaseRepository._internal();
    snapshot._client = SupabaseClient(_baseUrl, _publicKey,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    snapshot._isConnected = true;
    snapshot._snapshotAuthUserId = session.user.id;
    return snapshot;
  }

  Future<void> closeSessionSnapshot() async => _client?.dispose();

  static final RegExp _uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Client-side RFC-4122 v4 id so offline-created rows carry an id the
  /// uuid/text primary keys of every write table accept (and so queue
  /// retries stay idempotent).
  String generateUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Resolve a station code (or an existing UUID) to its uuid (ids pass through).
  Future<String?> _resolveStationUuid(String idOrCode) async {
    if (_uuidRe.hasMatch(idOrCode)) return idOrCode;
    try {
      final st = await client
          .from('stations')
          .select('id')
          .eq('code', idOrCode)
          .maybeSingle();
      return st?['id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Drop nulls (columns may predate a field) so queued payloads never
  /// reference columns the table lacks with explicit nulls.
  Map<String, dynamic> _cleanPayload(Map<String, dynamic> p) {
    final row = Map<String, dynamic>.from(p);
    row.removeWhere((_, v) => v == null);
    return row;
  }

  /// '2026-10-08T14:03:11+00:00' -> '08 Oct 2026'
  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return 'Unknown';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  /// Initialize Supabase connection
  Future<bool> initialize() async {
    configurationError = SupabaseConfig.configurationError;
    if (configurationError != null) return false;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      _client = Supabase.instance.client;
      _isConnected = true;
      return true;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // STATIONS & BRANCHES (§1, §2.1)
  // ---------------------------------------------------------------------------

  Future<OperationsPolicy?> fetchOperationsPolicy() async {
    if (!_isConnected) return null;
    try {
      final row = await client
          .from('operational_policy')
          .select()
          .eq('id', 'company')
          .maybeSingle();
      return row == null
          ? null
          : OperationsPolicy.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<OperationsPolicy?> configureOperationsPolicy({
    required double cashierLimit,
    required double managerLimit,
    required List<String> categories,
    required int expectedRevision,
  }) async {
    final snapshot = snapshotForAuthenticatedSession();
    if (snapshot == null) return null;
    try {
      final row =
          await snapshot.client.rpc('configure_operational_policy', params: {
        'p_cashier_limit': cashierLimit,
        'p_manager_limit': managerLimit,
        'p_categories': categories,
        'p_expected_revision': expectedRevision,
      });
      return OperationsPolicy.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    } finally {
      await snapshot.closeSessionSnapshot();
    }
  }

  /// Fetch all active stations from Supabase
  Future<List<Station>> fetchAllStations() async {
    if (!_isConnected) return [];

    try {
      final data = await client
          .from('stations')
          .select('*')
          .eq('is_active', true)
          .order('name', ascending: true);

      return (data as List)
          .map((row) => Station.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Director / Admin: Register a new branch station (§1)
  Future<Station?> createStation({
    required String code,
    required String name,
    String? address,
    String? phone,
    String? managerName,
    bool hasInterlockedTanks = false,
  }) async {
    final snapshot = snapshotForAuthenticatedSession();
    if (snapshot == null) return null;
    try {
      final res =
          await snapshot.client.rpc('register_company_station', params: {
        'p_station': {
          'code': code.toUpperCase().trim(),
          'name': name.trim(),
          'address': address?.trim(),
          'phone': phone?.trim(),
          'manager_name': managerName?.trim(),
          'has_interlocked_tanks': hasInterlockedTanks,
          'is_active': true,
        },
      });
      return Station.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      return null;
    } finally {
      await snapshot.closeSessionSnapshot();
    }
  }

  // ---------------------------------------------------------------------------
  // AUTHENTICATION & PROFILES (§2.1–§2.4)
  // ---------------------------------------------------------------------------

  /// Only existing, administrator-invited accounts can request a code.
  Future<void> requestManagementCode(String email) async {
    if (!_isConnected) throw StateError('Connect to request a sign-in code.');
    await client.auth.signInWithOtp(
        email: email.trim().toLowerCase(), shouldCreateUser: false);
  }

  /// Kiosk unlock never replaces the attendant's shared-client token.
  SupabaseRepository managementVerifier() {
    if (!_isConnected) throw StateError('Authentication unavailable.');
    return SupabaseRepository._internal()
      .._baseUrl = _baseUrl
      .._publicKey = _publicKey
      .._client = SupabaseClient(_baseUrl, _publicKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false))
      .._isConnected = true;
  }

  Future<Map<String, dynamic>> companyOnboardingStatus() async {
    final snapshot = snapshotForAuthenticatedSession();
    if (snapshot == null) throw StateError('Verified session required.');
    try {
      return Map<String, dynamic>.from(
          await snapshot.client.rpc('company_onboarding_status') as Map);
    } finally {
      await snapshot.closeSessionSnapshot();
    }
  }

  Future<void> configureCompanyWorkspace(String name, String webUrl) async {
    final snapshot = snapshotForAuthenticatedSession();
    if (snapshot == null) throw StateError('Verified session required.');
    try {
      await snapshot.client.rpc('configure_company_workspace', params: {
        'p_name': name.trim(),
        'p_web_url': webUrl.trim().isEmpty ? null : webUrl.trim(),
      });
    } finally {
      await snapshot.closeSessionSnapshot();
    }
  }

  Future<UserProfile> verifyManagementCode(String email, String code) async {
    if (!_isConnected) throw StateError('Connect to verify your sign-in code.');
    try {
      final response = await client.auth.verifyOTP(
          email: email.trim().toLowerCase(),
          token: code.trim(),
          type: OtpType.email);
      if (response.session == null || response.user?.emailConfirmedAt == null) {
        throw StateError('Email verification required.');
      }
      // Server-owned mapping, never role/email supplied by the login form.
      final raw = await client.rpc('current_staff_profile');
      final row = Map<String, dynamic>.from(raw as Map);
      final role = row['role'];
      if (row['is_active'] != true ||
          (role != 'manager' && role != 'director') ||
          row['auth_user_id'] != response.user!.id) {
        throw StateError('No active management account is linked.');
      }
      return UserProfile(
        id: row['id'] as String,
        displayName: row['display_name'] as String,
        fullName: row['full_name'] as String,
        role: role == 'director' ? UserRole.director : UserRole.manager,
        stationName: row['station_name'] as String? ?? '',
        stationId: row['station_id'] as String?,
        isActive: true,
      );
    } catch (_) {
      await endAuthenticatedSession();
      rethrow;
    }
  }

  Future<void> endAuthenticatedSession() async {
    if (_client == null) return;
    await client.auth.signOut(scope: SignOutScope.local);
  }

  Future<Map<String, dynamic>> verifyAttendantPin({
    required String stationId,
    required String profileId,
    required String pin,
  }) async {
    if (!_isConnected) {
      return {
        'success': false,
        'message': 'Authentication service unavailable — terminal is offline'
      };
    }

    try {
      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      String effectiveStationId = stationId;

      if (!uuidRegex.hasMatch(effectiveStationId)) {
        final resolved = await _resolveStationUuid(stationId);
        if (resolved == null) {
          return {
            'success': false,
            'message': 'Station could not be resolved. Check station setup.'
          };
        }
        effectiveStationId = resolved;
      }

      // 1. Try PostgreSQL RPC attendant_pin_login if profileId is a UUID
      if (uuidRegex.hasMatch(profileId) &&
          uuidRegex.hasMatch(effectiveStationId)) {
        try {
          final res = await client.rpc('attendant_pin_login', params: {
            'p_station_id': effectiveStationId,
            'p_profile_id': profileId,
            'p_pin': pin,
          });
          final map = Map<String, dynamic>.from(res as Map);
          if (map['success'] == true) {
            // A boolean PIN match is not an authenticated staff session.
            // Never inherit a manager's token or admit an anonymous client.
            if (authUserId == null) {
              return {
                'success': false,
                'message': 'Enrolled staff authentication unavailable'
              };
            }
            final raw = await client.rpc('current_staff_profile');
            final actor = Map<String, dynamic>.from(raw as Map);
            if (actor['id'] != profileId ||
                actor['auth_user_id'] != authUserId ||
                actor['station_id'] != effectiveStationId ||
                actor['is_active'] != true ||
                !['attendant', 'cashier'].contains(actor['role'])) {
              return {
                'success': false,
                'message': 'Enrolled staff authentication unavailable'
              };
            }
            return {'success': true};
          }
        } catch (_) {
          return {
            'success': false,
            'message': 'Authentication service unavailable'
          };
        }
      }

      return {'success': false, 'message': 'Invalid PIN'};
    } catch (_) {
      return {
        'success': false,
        'message': 'Authentication service unavailable'
      };
    }
  }

  Future<List<UserProfile>> fetchStationStaff([String? stationCode]) async {
    if (!_isConnected) return [];

    try {
      final data = await client
          .from('profiles')
          .select(
              'id,display_name,full_name,role,station_id,phone,address,surety_name,surety_phone,surety_address,base_salary,is_active,stations(name,code)')
          .order('created_at', ascending: true);

      return (data as List).map((row) {
        final roleStr = row['role'] as String;
        UserRole role;
        switch (roleStr) {
          case 'manager':
            role = UserRole.manager;
            break;
          case 'cashier':
            role = UserRole.cashier;
            break;
          case 'director':
          case 'admin':
            role = UserRole.director;
            break;
          default:
            role = UserRole.attendant;
        }

        final stationMap = row['stations'] as Map?;
        final stationName = stationMap?['name'] ??
            (role == UserRole.director ? 'HQ · Corporate' : 'Station');

        return UserProfile(
          id: row['id'] as String,
          displayName: row['display_name'] as String,
          fullName: row['full_name'] as String,
          role: role,
          stationName: stationName,
          stationId: row['station_id'],
          phone: row['phone'],
          address: row['address'],
          suretyName: row['surety_name'],
          suretyPhone: row['surety_phone'],
          suretyAddress: row['surety_address'],
          baseSalary: (row['base_salary'] as num?)?.toDouble() ?? 0.0,
          isActive: row['is_active'] ?? true,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Onboard a new pump attendant, cashier, or manager (§2.2)
  Future<UserProfile?> createStaffProfile({
    required String fullName,
    required String displayName,
    required UserRole role,
    required String pin,
    required String stationCode,
    String? phone,
    String? address,
    String? suretyName,
    String? suretyPhone,
    String? suretyAddress,
    double baseSalary = 0.0,
  }) async {
    if (!_isConnected) {
      return UserProfile(
        id: 'staff-${DateTime.now().millisecondsSinceEpoch}',
        displayName: displayName,
        fullName: fullName,
        role: role,
        stationName: stationCode,
        phone: phone,
        address: address,
        suretyName: suretyName,
        suretyPhone: suretyPhone,
        suretyAddress: suretyAddress,
        baseSalary: baseSalary,
        isActive: true,
      );
    }

    try {
      String? stationId;
      String stationName = 'Station';
      if (role != UserRole.director) {
        final st = await client
            .from('stations')
            .select('id, name')
            .eq('code', stationCode)
            .maybeSingle();
        stationId = st?['id'];
        stationName = st?['name'] ?? stationCode;
      } else {
        stationName = 'HQ · Corporate';
      }

      final roleStr = role.name;

      final res = await client
          .from('profiles')
          .insert({
            'full_name': fullName,
            'display_name': displayName,
            'role': roleStr,
            'pin_hash': pin,
            'phone': phone,
            'address': address,
            'surety_name': suretyName,
            'surety_phone': suretyPhone,
            'surety_address': suretyAddress,
            'station_id': stationId,
            'base_salary': baseSalary,
            'is_active': true,
          })
          .select()
          .single();

      return UserProfile(
        id: res['id'] as String,
        displayName: res['display_name'] as String,
        fullName: res['full_name'] as String,
        role: role,
        stationName: stationName,
        stationId: stationId,
        phone: phone,
        address: address,
        suretyName: suretyName,
        suretyPhone: suretyPhone,
        suretyAddress: suretyAddress,
        baseSalary: (res['base_salary'] as num?)?.toDouble() ?? baseSalary,
        isActive: true,
      );
    } catch (e) {
      return null;
    }
  }

  /// Director only: Update monthly base salary (§4.7, Executive Payroll)
  Future<bool> updateStaffSalary(
      {required String profileId, required double baseSalary}) async {
    if (!_isConnected) return false;
    try {
      await client
          .from('profiles')
          .update({'base_salary': baseSalary}).eq('id', profileId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reset attendant login PIN (§2.3)
  Future<bool> resetStaffPin(
      {required String profileId, required String newPin}) async {
    if (!_isConnected) return false;
    try {
      await client
          .from('profiles')
          .update({'pin_hash': newPin}).eq('id', profileId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle active / inactive status (dismissal or leave)
  Future<bool> toggleStaffStatus(
      {required String profileId, required bool isActive}) async {
    if (!_isConnected) return false;
    try {
      await client
          .from('profiles')
          .update({'is_active': isActive}).eq('id', profileId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SHIFTS, READINGS & REMITTANCES (§2.5–§2.10, §4.1–§4.7)
  // ---------------------------------------------------------------------------

  Future<String?> createShift({
    required String stationId,
    required String shiftType,
    required String openedBy,
  }) async {
    if (!_isConnected) return 'SHIFT-LOCAL-01';

    try {
      final res = await client
          .from('shifts')
          .insert({
            'station_id': stationId,
            'shift_type': shiftType,
            'opened_by': openedBy,
            'status': 'open',
          })
          .select('id')
          .single();

      return res['id'] as String;
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveClosingReadings({
    required String shiftId,
    required List<NozzleItem> nozzles,
  }) async {
    if (!_isConnected) return false;

    try {
      for (final n in nozzles) {
        if (n.closingReading != null) {
          if (!_uuidRe.hasMatch(n.id)) return false;
          final actor = await client.rpc('current_staff_profile');
          if (actor is! Map || actor['is_active'] != true) return false;
          await client.from('shift_nozzle_assignments').upsert(
            {
              'shift_id': shiftId,
              'nozzle_id': n.id,
              'attendant_id': actor['id'],
              'opening_reading': n.openingReading,
              'closing_reading': n.closingReading,
              'price_per_litre': n.pricePerLitre,
              'submitted_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'shift_id,nozzle_id',
          );
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitRemittanceRecord({
    required String shiftId,
    required String attendantId,
    required double expectedSales,
    required double cash,
    required double posCard,
    required double posTransfer,
    required double bankTransfer,
    required double credit,
    required List<String> proofUrls,
  }) async {
    if (!_isConnected) return false;

    try {
      final res = await client
          .from('remittances')
          .insert({
            'shift_id': shiftId,
            'attendant_id': attendantId,
            'expected_sales_value': expectedSales,
            'cash_declared': cash,
            'pos_card_declared': posCard,
            'pos_transfer_declared': posTransfer,
            'bank_transfer_declared': bankTransfer,
            'credit_sales_declared': credit,
            'status': 'submitted',
          })
          .select('id')
          .single();

      final remittanceId = res['id'] as String;

      for (var url in proofUrls) {
        await client.from('remittance_evidence').insert({
          'remittance_id': remittanceId,
          'payment_channel': 'pos_slip',
          'storage_path': url,
          'amount': posCard,
        });
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // INTRA-SHIFT CASH DROPS & IN-BETWEEN POS TRANSACTIONS (§2.6, §4.1, §4.4)
  // ---------------------------------------------------------------------------

  /// Fetch today's interim cash drops for the station
  Future<List<InterimCashDrop>> fetchInterimCashDrops(
      [String? stationCode]) async {
    if (!_isConnected) return [];
    try {
      final res = await client
          .from('interim_cash_drops')
          .select('*, profiles(full_name, display_name)')
          .order('created_at', ascending: false);

      return (res as List)
          .map(
              (row) => InterimCashDrop.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Attendant submits an intra-shift cash drop to Cashier
  Future<InterimCashDrop?> createInterimCashDrop({
    required String stationCode,
    required String attendantId,
    required String attendantName,
    required double amount,
    String? notes,
    String? shiftId,
  }) async {
    if (!_isConnected) {
      return InterimCashDrop(
        id: generateUuid(),
        shiftId: shiftId,
        stationId: stationCode,
        attendantId: attendantId,
        attendantName: attendantName,
        amount: amount,
        notes: notes,
        status: 'pending',
        createdAt: DateTime.now(),
      );
    }

    try {
      final res = await client
          .from('interim_cash_drops')
          .insert({
            'station_id': stationCode,
            'attendant_id': attendantId,
            'amount': amount,
            'notes': notes,
            'status': 'pending',
            'shift_id': shiftId,
          })
          .select()
          .single();

      return InterimCashDrop.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      return null;
    }
  }

  /// Cashier acknowledges and accepts the interim cash drop into drawer
  Future<bool> acknowledgeInterimCashDrop({
    required String dropId,
    required String cashierId,
  }) async {
    if (!_isConnected) return false;
    try {
      await client.from('interim_cash_drops').update({
        'status': 'acknowledged',
        'acknowledged_by': cashierId,
        'acknowledged_at': DateTime.now().toIso8601String(),
      }).eq('id', dropId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch in-between POS & bank transfer transactions
  Future<List<PosTransaction>> fetchShiftPosTransactions(
      [String? stationCode]) async {
    if (!_isConnected) return [];
    try {
      final res = await client
          .from('shift_pos_transactions')
          .select('*, profiles(full_name, display_name)')
          .order('created_at', ascending: false);

      return (res as List)
          .map((row) => PosTransaction.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Attendant logs in-between POS card or transfer sale
  Future<PosTransaction?> recordShiftPosTransaction({
    required String stationCode,
    required String attendantId,
    required String attendantName,
    required String paymentChannel,
    required double amount,
    String? terminalName,
    String? referenceNumber,
    String? storagePath,
    String? customerVehicle,
    String? shiftId,
  }) async {
    if (!_isConnected) {
      return PosTransaction(
        id: generateUuid(),
        shiftId: shiftId,
        stationId: stationCode,
        attendantId: attendantId,
        attendantName: attendantName,
        paymentChannel: paymentChannel,
        amount: amount,
        terminalName: terminalName,
        referenceNumber: referenceNumber,
        storagePath: storagePath,
        customerVehicle: customerVehicle,
        createdAt: DateTime.now(),
      );
    }

    try {
      final res = await client
          .from('shift_pos_transactions')
          .insert({
            'station_id': stationCode,
            'attendant_id': attendantId,
            'payment_channel': paymentChannel,
            'amount': amount,
            'terminal_name': terminalName,
            'reference_number': referenceNumber,
            'storage_path': storagePath,
            'customer_vehicle': customerVehicle,
            'shift_id': shiftId,
          })
          .select()
          .single();

      return PosTransaction.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CASHIER VERIFICATION & SAFE NOTE COUNT (§5.3–§5.5)
  // ---------------------------------------------------------------------------

  Future<bool> verifyShift({
    required String remittanceId,
    required String cashierId,
    required String comment,
  }) async {
    if (!_isConnected) return false;

    try {
      await client.from('remittances').update({
        'status': 'verified',
        'verified_by': cashierId,
        'verified_at': DateTime.now().toIso8601String(),
        'cashier_notes': comment,
      }).eq('id', remittanceId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Persist a physical cash count audit row (§5.3).
  /// [payload] keys: station_id (code or uuid), cashier_id, opening_cash,
  /// cash_receipts, cash_expenses, handed_over_for_deposit,
  /// expected_closing_cash, physical_total_counted, count_*, deposit_status.
  Future<bool> recordDailyCashAuditPayload(Map<String, dynamic> payload) async {
    if (!_isConnected) return false;

    try {
      final row = _cleanPayload(payload);
      final sid = row['station_id']?.toString();
      if (sid == null) return false;
      final stationUuid = await _resolveStationUuid(sid);
      if (stationUuid == null) return false;
      row['station_id'] = stationUuid;

      await client.from('daily_cash_counts').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // BANK DEPOSITS & DUAL-CUSTODY AUDIT TRAIL (§4.3, §5.4, §5.5)
  // ---------------------------------------------------------------------------

  Future<List<BankDepositRecord>> fetchBankDeposits(String stationCode) async {
    if (!_isConnected) return [];

    try {
      final stRes = await client
          .from('stations')
          .select('id, name')
          .eq('code', stationCode)
          .maybeSingle();
      final stationId = stRes?['id'];
      final stationName = stRes?['name'] ?? stationCode;

      if (stationId == null) return [];
      var query = client.from('bank_deposits').select('*');
      if (stationId != null) {
        query = query.eq('station_id', stationId);
      }
      final data = await query.order('created_at', ascending: false);

      return (data as List).map((row) {
        final map = Map<String, dynamic>.from(row);
        map['stations'] = {'name': stationName};
        return BankDepositRecord.fromJson(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<BankDepositRecord?> recordBankDeposit({
    required String stationCode,
    required String stationName,
    required double amount,
    required String bankName,
    required String bearerName,
    String? tellerNumber,
    String? slipUrl,
    String? notes,
  }) async {
    if (stationCode.trim().isEmpty) return null;
    if (!_isConnected) {
      return BankDepositRecord(
        id: generateUuid(),
        stationId: stationCode,
        stationName: stationName,
        amount: amount,
        cashierName: bearerName,
        bankName: bankName,
        tellerNumber: tellerNumber,
        slipUrl: slipUrl,
        notes: notes,
        handedOverAt: DateTime.now(),
        status: 'awaiting_bank',
      );
    }

    try {
      final stRes = await client
          .from('stations')
          .select('id, name')
          .eq('code', stationCode)
          .maybeSingle();
      final stationId = stRes?['id'];
      final stationName = stRes?['name'] ?? stationCode;

      if (stationId == null) return null;
      final res = await client
          .from('bank_deposits')
          .insert({
            if (stationId != null) 'station_id': stationId,
            'amount': amount,
            'bank_name': bankName,
            'bearer_name': bearerName,
            'teller_number': tellerNumber,
            'slip_url': slipUrl,
            'notes': notes,
            'status': 'awaiting_bank',
          })
          .select()
          .single();

      final map = Map<String, dynamic>.from(res);
      map['stations'] = {'name': stationName};
      return BankDepositRecord.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  Future<bool> confirmBankDeposit({
    required String depositId,
    required String directorId,
    String? directorNotes,
  }) async {
    if (!_isConnected) return false;

    try {
      await client.from('bank_deposits').update({
        'status': 'confirmed',
        'is_confirmed': true,
        'confirmed_by': directorId,
        'confirmed_at': DateTime.now().toIso8601String(),
        'director_notes': directorNotes,
      }).eq('id', depositId);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> flagBankDepositDiscrepancy({
    required String depositId,
    required String directorId,
    required String discrepancyNotes,
  }) async {
    if (!_isConnected) return false;

    try {
      await client.from('bank_deposits').update({
        'status': 'discrepancy',
        'confirmed_by': directorId,
        'confirmed_at': DateTime.now().toIso8601String(),
        'director_notes': discrepancyNotes,
      }).eq('id', depositId);

      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // CREDIT & INVENTORY LEDGERS (§4.8–§4.10, §3.2–§3.9)
  // ---------------------------------------------------------------------------

  Future<List<CreditCustomer>> fetchCreditLedger(String stationId) async {
    if (!_isConnected) return <CreditCustomer>[];

    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client.from('credit_customers').select();

      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }

      final data = await query.order('company_name');
      return (data as List).map((row) {
        final lastPayment = row['last_payment_at'] as String?;
        return CreditCustomer(
          id: row['id'] as String,
          name: row['company_name'] as String,
          outstanding: (row['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
          lastRepayment: lastPayment != null
              ? _formatDate(lastPayment)
              : 'No repayment yet',
          dueDate: '${row['payment_terms_days'] ?? 0} days',
          status: row['status'] == 'overdue'
              ? CustomerCreditStatus.overdue
              : CustomerCreditStatus.current,
        );
      }).toList();
    } catch (e) {
      return <CreditCustomer>[];
    }
  }

  Future<Map<String, double>> fetchLivePrices(String stationId) async {
    if (!_isConnected) return {};
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      final data = await client
          .from('fuel_prices')
          .select('product_id, price_per_litre, fuel_products(code)')
          .eq('station_id', stationUuid ?? stationId)
          .order('effective_from', ascending: false);

      final Map<String, double> prices = {};
      for (final row in (data as List)) {
        final productMap = row['fuel_products'] as Map?;
        final code = productMap?['code'] as String?;
        if (code != null && !prices.containsKey(code)) {
          prices[code] = (row['price_per_litre'] as num).toDouble();
        }
      }
      return prices;
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>?> fetchStationInfo(String stationCode) async {
    if (!_isConnected) return null;
    try {
      final res = await client
          .from('stations')
          .select('id, code, name, has_interlocked_tanks')
          .eq('code', stationCode)
          .maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveTanks(String stationId) async {
    if (!_isConnected) return [];
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client.from('tanks').select(
          'id, code, capacity_litres, current_dip_litres, calculated_stock_litres, is_interlocked, fuel_products(code)');

      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }

      final data = await query.order('code');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveNozzles(String stationId) async {
    if (!_isConnected) return [];
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      if (stationUuid == null) return [];
      final data = await client
          .from('nozzles')
          .select(
              '*, pumps!inner(station_id), tanks(id,code), fuel_products(code)')
          .eq('pumps.station_id', stationUuid)
          .eq('is_active', true)
          .order('nozzle_number');
      final rows = List<Map<String, dynamic>>.from(data as List);
      // Old duplicated numeric keys cannot safely populate legacy local forms.
      if (rows.map((r) => r['nozzle_number']).toSet().length != rows.length)
        return [];
      return rows;
    } catch (_) {
      return [];
    }
  }

  /// New payloads use UUIDs. Resolve old numeric outbox keys only within a station.
  Future<String?> _resolvePumpId(String stationRef,
      {String? id, int? legacyNumber}) async {
    final stationId = await _resolveStationUuid(stationRef);
    if (stationId == null || (id?.isNotEmpty != true && legacyNumber == null))
      return null;
    var query = client
        .from('nozzles')
        .select('id,pumps!inner(station_id)')
        .eq('pumps.station_id', stationId);
    if (id?.isNotEmpty == true) {
      if (!_uuidRe.hasMatch(id!)) return null;
      query = query.eq('id', id);
    } else {
      query = query.eq('nozzle_number', legacyNumber!);
    }
    final rows = await query.limit(2);
    return rows.length == 1 ? rows.single['id'] as String : null;
  }

  /// Director / Admin: Update station interlock capability
  Future<bool> updateStationInterlockStatus(
      String stationCode, bool hasInterlockedTanks) async {
    if (!_isConnected) return false;
    try {
      await client
          .from('stations')
          .update({'has_interlocked_tanks': hasInterlockedTanks}).eq(
              'code', stationCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Director / Admin: Update tank manifold twin flag
  Future<bool> updateTankInterlock(String tankCode, bool isInterlocked) async {
    if (!_isConnected) return false;
    try {
      await client
          .from('tanks')
          .update({'is_interlocked': isInterlocked}).eq('code', tankCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update nozzle supplying tank (used for plumbing mapping and manifold switches)
  Future<bool> updateNozzleSupplyingTank(
      String pumpId, String targetTankCode, String stationCode) async {
    final snapshot = snapshotForAuthenticatedSession();
    if (snapshot == null) return false;
    try {
      final id = await snapshot._resolvePumpId(stationCode, id: pumpId);
      final station = await snapshot._resolveStationUuid(stationCode);
      if (id == null || station == null) return false;
      final tank = await snapshot.client
          .from('tanks')
          .select('id')
          .eq('station_id', station)
          .eq('code', targetTankCode)
          .eq('is_active', true)
          .single();
      await snapshot.client
          .from('nozzles')
          .update({'supplying_tank_id': tank['id']}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    } finally {
      await snapshot.closeSessionSnapshot();
    }
  }

  /// Record full manifold changeover audit event (§3.1, §7)
  Future<bool> recordTankChangeover({
    required String stationCode,
    required String productCode,
    required String fromTankCode,
    required String toTankCode,
    required Map<String, double> switchReadings,
    double? fromTankDip,
    double? toTankDip,
    String? notes,
    String? switchedBy,
  }) async {
    if (!_isConnected) return false;
    try {
      // 1. Get station ID
      final station = await client
          .from('stations')
          .select('id')
          .eq('code', stationCode)
          .single();
      final stationId = station['id'];

      // 2. Insert audit log
      await client.from('tank_changeovers').insert({
        'station_id': stationId,
        'product_code': productCode,
        'from_tank_code': fromTankCode,
        'to_tank_code': toTankCode,
        'switch_readings': switchReadings,
        'from_tank_dip_litres': fromTankDip,
        'to_tank_dip_litres': toTankDip,
        'notes': notes,
        'switched_by': switchedBy,
      });

      // 3. Update active nozzle supplying_tank_id
      final targetTank = await client
          .from('tanks')
          .select('id')
          .eq('code', toTankCode)
          .eq('station_id', stationId)
          .single();
      final targetTankId = targetTank['id'];

      for (final pumpId in switchReadings.keys) {
        final id = await _resolvePumpId(stationCode, id: pumpId);
        if (id == null) return false;
        await client.from('nozzles').update({
          'supplying_tank_id': targetTankId,
          'latest_meter_reading': switchReadings[pumpId],
        }).eq('id', id);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveExpenses(String stationId) async {
    if (!_isConnected) return [];
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client.from('branch_expenses').select();

      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }

      final data = await query.order('created_at', ascending: false).limit(30);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLiveSalaryAdjustments(
      String stationId) async {
    if (!_isConnected) return [];
    try {
      final stationUuid = await _resolveStationUuid(stationId);
      var query = client.from('attendant_salary_adjustments').select();

      if (stationUuid != null) {
        query = query.eq('station_id', stationUuid);
      }

      final data = await query.order('created_at', ascending: false).limit(30);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // OFFLINE QUEUE PAYLOAD DISPATCH DISPATCHERS (PHASE 2)
  // ---------------------------------------------------------------------------

  Future<bool> syncClosingReadingsPayload(Map<String, dynamic> p) async {
    if (!_isConnected)
      return false; // Keep queued until the service is available
    try {
      final shiftId = p['shiftId'] as String;
      final readings = p['readings'] as List;
      final stationCode = p['stationCode']?.toString() ?? '';
      final stationUuid = await _resolveStationUuid(stationCode);
      if (stationUuid == null) return false;
      for (final r in readings) {
        final pumpId = await _resolvePumpId(stationCode,
            id: r['pumpId'] as String?,
            legacyNumber: (r['nozzleNumber'] as num?)?.toInt());
        if (pumpId == null) return false;
        await client.from('shift_nozzle_assignments').upsert(
          {
            'shift_id': shiftId,
            'nozzle_id': pumpId,
            'attendant_id': p['attendantId'],
            'opening_reading': r['openingReading'],
            'closing_reading': r['closingReading'],
            'price_per_litre': r['pricePerLitre'],
            'submitted_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'shift_id,nozzle_id',
        );

        // Roll the closing meter forward so the NEXT session's opening
        // reading starts where this one ended (otherwise every shift
        // re-opens at stale numbers and litres-sold is wrong).
        final closing = (r['closingReading'] as num?)?.toDouble();
        if (closing != null) {
          await client
              .from('nozzles')
              .update({'latest_meter_reading': closing}).eq('id', pumpId);
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncRemittancePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      // Client-generated uuid keeps retries idempotent and lets the state
      // layer reference this submission before/after sync.
      final remittanceId = p['id']?.toString() ?? generateUuid();
      try {
        await client.from('remittances').insert({
          'id': remittanceId,
          'shift_id': p['shiftId'] ?? 'SHIFT-01',
          'attendant_id': p['attendantId'] ?? 'ATT-01',
          'expected_sales_value': p['expectedSalesValue'] ?? 0.0,
          if (p.containsKey('approvedPumpExpenses'))
            'approved_pump_expenses': p['approvedPumpExpenses'],
          if (p.containsKey('approvedNonSaleFuel'))
            'approved_non_sale_fuel': p['approvedNonSaleFuel'],
          if (p.containsKey('meteredStock')) 'metered_stock': p['meteredStock'],
          'cash_declared': p['cashDeclared'] ?? 0.0,
          'pos_card_declared': p['posCardDeclared'] ?? 0.0,
          'pos_transfer_declared': p['posTransferDeclared'] ?? 0.0,
          'bank_transfer_declared': p['bankTransferDeclared'] ?? 0.0,
          'credit_sales_declared': p['creditSalesDeclared'] ?? 0.0,
          'status': 'submitted',
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // already persisted on a retry
      }

      // Persist the attendant's evidence photos against this remittance so
      // the cashier on ANY device can open them during verification.
      final photos = p['evidencePhotos'];
      if (photos is List) {
        for (final url in photos.whereType<String>()) {
          try {
            await client.from('remittance_evidence').insert({
              'remittance_id': remittanceId,
              'storage_path': url,
              'payment_channel': 'pos_slip',
              'created_at': DateTime.now().toIso8601String(),
            });
          } on PostgrestException catch (e) {
            if (e.code != '23505') rethrow;
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cashier verification result for a remittance (status is plain text
  /// after the migration, so 'verified' / 'flagged_unresolved' are free-form).
  Future<bool> syncRemittanceVerificationPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      final id = p['id']?.toString();
      if (id == null) return false;
      await client.from('remittances').update({
        'status': p['status'],
        'cashier_notes': p['cashierNotes'],
        'verified_by': p['verifiedBy'],
        'verified_at': p['verifiedAt'] ?? DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncCreditSalePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      final saleId = p['id']?.toString();
      final pumpId = await _resolvePumpId(p['stationCode'] as String? ?? '',
          id: p['pumpId'] as String?,
          legacyNumber: (p['nozzleNumber'] as num?)?.toInt());
      if (pumpId == null || p['shiftId'] == null || saleId == null)
        return false;
      final photos = p['evidencePhotos'] as List? ?? [];
      final row = {
        'id': saleId,
        'shift_id': p['shiftId'],
        'customer_id': p['customerId'],
        'driver_name': p['driverName'],
        'vehicle_number': p['vehicleReg'],
        'litres': p['litres'],
        'amount': p['totalAmount'],
        'nozzle_id': pumpId,
        'attendant_id': p['attendantId'],
        if (photos.isNotEmpty) 'signed_requisition_path': photos.first,
      };
      var inserted = false;
      try {
        await client.from('credit_sales').insert(row);
        inserted = true;
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }

      // The ledger balance lives in credit_customers - bump it so every
      // device (and every restart) sees the same outstanding amount.
      final customerId = p['customerId']?.toString();
      final amount = (p['totalAmount'] as num?)?.toDouble() ?? 0.0;
      if (inserted && customerId != null && amount != 0) {
        try {
          await client.rpc('app_add_credit_outstanding', params: {
            'p_customer_id': customerId,
            'p_delta': amount,
          });
        } catch (_) {
          // Best effort: the sale row above is the source of truth for audit.
        }
      }

      // Requisition proof is attached through the schema's signed_requisition_path.
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncShiftAdjustmentPayload(Map<String, dynamic> p) async {
    if (!_isConnected || authUserId == null) return false;
    try {
      await client.rpc('submit_shift_adjustment', params: {'p_entry': p});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<ShiftAdjustment>?> fetchShiftAdjustments(
      String stationCode) async {
    if (!_isConnected || authUserId == null) return null;
    try {
      final rows = await client
          .from('shift_adjustments')
          .select()
          .eq('station_code', stationCode)
          .order('created_at');
      return rows.map((row) => ShiftAdjustment.fromJson(row)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<ShiftAdjustment?> reviewShiftAdjustment(
      String id, bool approved, String notes) async {
    if (!_isConnected || authUserId == null) return null;
    final snapshot = snapshotForAuthenticatedSession();
    if (snapshot == null) return null;
    try {
      final row = await snapshot.client.rpc('review_shift_adjustment', params: {
        'p_id': id,
        'p_approved': approved,
        'p_notes': notes,
      });
      return ShiftAdjustment.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (_) {
      return null;
    } finally {
      await snapshot.closeSessionSnapshot();
    }
  }

  Future<bool> syncFuelReturnPayload(Map<String, dynamic> p) async {
    // Old outbox entries lack shift/type/approval metadata. Do not silently
    // publish them as verified returns; re-enter through the new ledger.
    return false;
  }

  Future<bool> syncDailyCashAuditPayload(Map<String, dynamic> p) async {
    return await recordDailyCashAuditPayload(p);
  }

  Future<bool> syncBranchExpensePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      // Upsert: create payloads carry full rows, approve/waive payloads are
      // {id, status, ...} updates — a plain insert would conflict on the PK.
      await client.from('branch_expenses').upsert(p, onConflict: 'id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncTankDipPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      await client.from('tank_dips').insert(p);

      // Mirror the dip into the tanks read-model so every device's gauge
      // shows the fresh physical/book numbers after a restart.
      final tankCode = p['tank_id'] ?? p['tankCode'];
      if (tankCode != null) {
        await client.from('tanks').update({
          if (p['physical_dip_litres'] != null)
            'current_dip_litres': p['physical_dip_litres'],
          if (p['book_stock_litres'] != null)
            'calculated_stock_litres': p['book_stock_litres'],
        }).eq('code', tankCode);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncFuelDeliveryPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      try {
        await client.from('tank_deliveries').insert(p);
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
      // Tank book-stock is persisted separately as an absolute value via
      // SyncActionType.tankStock (state enqueues it after every mutation).
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncPriceChangePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      await client.from('fuel_prices').insert(p);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncSalaryAdjustmentPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      // Upsert: settlement creation inserts a full row; approve/waive queue
      // {id, status, ...} updates that must not conflict on the PK.
      await client.from('attendant_shortages').upsert(p, onConflict: 'id');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Per-shift shortage/excess adjustments live in the salary ledger table
  /// (attendant_salary_adjustments) - the table the ledger screen reads.
  Future<bool> syncShortageAdjustmentPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      await client
          .from('attendant_salary_adjustments')
          .upsert(_cleanPayload(p), onConflict: 'id');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Monthly payroll settlements (history + double-settlement guard).
  Future<List<MonthlyPayrollSettlement>> fetchPayrollSettlements() async {
    if (!_isConnected) return [];
    try {
      final data = await client
          .from('attendant_shortages')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      return (data as List)
          .map((row) => MonthlyPayrollSettlement.fromJson(
              Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Remittances read back for the cashier verification queue: each row is
  /// returned raw (plus embedded profile name and evidence photos) so the
  /// state layer can map it onto ShiftSubmission.
  Future<List<Map<String, dynamic>>> fetchRemittanceRecords(
      {int limit = 30}) async {
    if (!_isConnected) return [];
    try {
      final data = await client
          .from('remittances')
          .select(
              '*, profiles!remittances_attendant_id_fkey(full_name, display_name), remittance_evidence(storage_path, payment_channel)')
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Credit repayment: decrements the customer's outstanding balance
  /// atomically (floors at zero, stamps last_payment_at).
  Future<bool> syncCreditRepaymentPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      final customerId = p['customerId']?.toString();
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      if (customerId == null || amount <= 0) return false;
      await client.rpc('app_add_credit_outstanding', params: {
        'p_customer_id': customerId,
        'p_delta': -amount,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncCreditCustomerCreatePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      final row = _cleanPayload(p);
      final stationCode = row.remove('station_code')?.toString();
      if (stationCode != null) {
        final uuid = await _resolveStationUuid(stationCode);
        if (uuid != null) row['station_id'] = uuid;
      }
      row.removeWhere((k, _) => k == 'product_code' || k == 'tank_code');
      await client.from('credit_customers').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Onboard a credit customer directly (online path).
  Future<bool> createCreditCustomer({
    required String id,
    required String companyName,
    required String contactPerson,
    required int paymentTermsDays,
    required String stationCode,
  }) async {
    if (!_isConnected) return false;
    try {
      final stationUuid = await _resolveStationUuid(stationCode);
      await client.from('credit_customers').insert({
        'id': id,
        'company_name': companyName,
        'contact_person': contactPerson,
        'payment_terms_days': paymentTermsDays,
        'outstanding_balance': 0,
        'status': 'current',
        if (stationUuid != null) 'station_id': stationUuid,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncTankCreatePayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      final row = _cleanPayload(p);
      final productCode = row.remove('product_code')?.toString();
      final stationCode = row.remove('station_code')?.toString();
      if (productCode != null) {
        final product = await client
            .from('fuel_products')
            .select('id')
            .ilike('code', productCode)
            .limit(1)
            .maybeSingle();
        if (product != null) row['fuel_product_id'] = product['id'];
      }
      if (stationCode != null) {
        final uuid = await _resolveStationUuid(stationCode);
        if (uuid != null) row['station_id'] = uuid;
      }
      await client.from('tanks').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Add a tank from Station Setup (online path).
  Future<bool> createTank({
    required String id,
    required String code,
    required String productCode,
    required double capacityLitres,
    required double initialStockLitres,
    required String stationCode,
  }) async {
    if (!_isConnected) return false;
    try {
      final product = await client
          .from('fuel_products')
          .select('id')
          .ilike('code', productCode)
          .limit(1)
          .maybeSingle();
      final stationUuid = await _resolveStationUuid(stationCode);
      await client.from('tanks').insert({
        'id': id,
        'code': code,
        'name': '$productCode Tank $code',
        'capacity_litres': capacityLitres,
        'current_dip_litres': initialStockLitres,
        'calculated_stock_litres': initialStockLitres,
        'is_interlocked': false,
        if (product != null) 'fuel_product_id': product['id'],
        if (stationUuid != null) 'station_id': stationUuid,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncNozzleCreatePayload(Map<String, dynamic> p) async {
    // Recover identifiable legacy queued creations without renumbering them.
    final number = (p['nozzle_number'] as num?)?.toInt();
    if (number == null || p['id'] == null || p['station_code'] == null)
      return false;
    return await createNozzle(
            id: p['id'] as String,
            displayName: p['display_name'] as String? ?? 'Pump$number',
            productCode: p['product_code'] as String? ?? '',
            tankCode: p['tank_code'] as String? ?? '',
            latestMeterReading:
                (p['latest_meter_reading'] as num?)?.toDouble() ?? double.nan,
            stationCode: p['station_code'] as String,
            legacyNumber: number) !=
        null;
  }

  Future<Map<String, dynamic>?> createNozzle({
    required String id,
    required String displayName,
    required String productCode,
    required String tankCode,
    required double latestMeterReading,
    required String stationCode,
    int? legacyNumber,
  }) async {
    final snapshot = snapshotForAuthenticatedSession();
    if (snapshot == null) return null;
    try {
      final row = await snapshot.client.rpc('register_named_pump', params: {
        'p_station_code': stationCode,
        'p_id': id,
        'p_name': NozzleItem.validateName(displayName),
        'p_product_code': productCode,
        'p_tank_code': tankCode,
        'p_opening': latestMeterReading,
        'p_legacy_number': legacyNumber,
      });
      return Map<String, dynamic>.from(row as Map);
    } catch (_) {
      return null;
    } finally {
      await snapshot.closeSessionSnapshot();
    }
  }

  Future<String?> renameNozzle(
      String id, String stationCode, String name) async {
    final snapshot = snapshotForAuthenticatedSession();
    if (snapshot == null) return null;
    try {
      final row = await snapshot.client.rpc('rename_named_pump', params: {
        'p_id': id,
        'p_station_code': stationCode,
        'p_name': NozzleItem.validateName(name),
      });
      return (row as Map)['display_name'] as String;
    } catch (_) {
      return null;
    } finally {
      await snapshot.closeSessionSnapshot();
    }
  }

  /// Absolute tank book-stock/physical-dip sync (state enqueues after every
  /// stock mutation so all devices converge on the same numbers).
  Future<bool> syncTankStockPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      final tankCode = p['tankCode']?.toString();
      if (tankCode == null) return false;
      await client.from('tanks').update({
        if (p['bookStock'] != null)
          'calculated_stock_litres': (p['bookStock'] as num).toDouble(),
        if (p['physicalDip'] != null)
          'current_dip_litres': (p['physicalDip'] as num).toDouble(),
      }).eq('code', tankCode);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncNotificationPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      try {
        await client.from('app_notifications').insert(_cleanPayload(p));
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Operational notifications read back after a restart.
  Future<List<ForecourtNotification>> fetchNotifications(
      {int limit = 50}) async {
    if (!_isConnected) return [];
    try {
      final data = await client
          .from('app_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((row) {
        final m = Map<String, dynamic>.from(row as Map);
        return ForecourtNotification(
          id: (m['id'] as String?) ?? generateUuid(),
          title: (m['title'] as String?) ?? '',
          message: (m['message'] as String?) ?? '',
          type: notificationTypeFromString(m['type'] as String?),
          timestamp: DateTime.tryParse(m['created_at'] as String? ?? '') ??
              DateTime.now(),
          targetRole: m['target_role'] != null
              ? _roleFromString(m['target_role'] as String)
              : null,
          actionRouteName: m['action_route'] as String?,
          isRead: m['is_read'] == true,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static NotificationType notificationTypeFromString(String? raw) {
    switch (raw) {
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'critical':
        return NotificationType.critical;
      default:
        return NotificationType.info;
    }
  }

  static UserRole? _roleFromString(String raw) {
    switch (raw) {
      case 'attendant':
        return UserRole.attendant;
      case 'cashier':
        return UserRole.cashier;
      case 'manager':
        return UserRole.manager;
      case 'director':
        return UserRole.director;
      default:
        return null;
    }
  }

  /// Persist the shift session row (the shared shift id every payload uses).
  Future<bool> syncShiftSessionPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      // Match the verified production schema: opened_by, and lowercase enum.
      // Normalize older queued rows without changing their shift identifiers.
      final row = _cleanPayload(p);
      final attendant = row.remove('attendant_id');
      if (attendant != null) row.putIfAbsent('opened_by', () => attendant);
      final shiftType = row['shift_type']?.toString().toLowerCase();
      if (shiftType == 'morning') row['shift_type'] = 'morning';
      if (shiftType == 'evening') row['shift_type'] = 'afternoon_evening';
      // shifts.station_id is text after the migration (station code).
      try {
        await client.from('shifts').insert(row);
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // same shift already opened
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncBankDepositRecordPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      final row = _cleanPayload(p);
      final sid = row['station_id']?.toString();
      if (sid == null) return false;
      // bank_deposits.station_id stays a uuid FK — resolve the code first.
      final stationUuid = await _resolveStationUuid(sid);
      if (stationUuid == null) return false;
      row['station_id'] = stationUuid;

      await client.from('bank_deposits').insert(row);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncInterimCashDropPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      // station_id / shift_id are text (station code, 'SHIFT-...' ids).
      await client.from('interim_cash_drops').insert(_cleanPayload(p));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncPosTransactionPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      // station_id / shift_id are text (station code, 'SHIFT-...' ids).
      await client.from('shift_pos_transactions').insert(_cleanPayload(p));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncBankDepositPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      await client.from('bank_deposits').update({
        'is_confirmed': true,
        'confirmed_at': p['confirmed_at'] ?? DateTime.now().toIso8601String(),
        if (p['director_notes'] != null) 'director_notes': p['director_notes'],
      }).eq('id', p['id']);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> syncEvidencePhotoPayload(Map<String, dynamic> p) async {
    if (!_isConnected) return false;
    try {
      String? storagePath = p['path']?.toString();
      final bucket = p['bucket']?.toString() ?? 'remittance-evidence';
      final b64 = p['imageBase64']?.toString();

      // Real upload of the queued image bytes — no metadata-only records
      if (b64 == null || b64.isEmpty || storagePath == null) return false;
      final uploadedUrl = await uploadStorageFile(
        bucket: bucket,
        path: storagePath,
        fileBytes: base64Decode(b64),
      );
      if (uploadedUrl == null) return false; // keep queued, retry later
      // The business record already owns the durable reference. Do not create
      // an orphan remittance row for an expense, delivery or teller upload.
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SUPABASE STORAGE UPLOADS (PHASE 3)
  // ---------------------------------------------------------------------------

  Future<String?> resolveEvidenceUrl(String? reference) async {
    if (!_isConnected || authUserId == null) return null;
    final object =
        EvidenceReference.parse(reference, endpoint: SupabaseConfig.url);
    if (object == null) return null;
    try {
      return await client.storage
          .from(object.bucket)
          .createSignedUrl(object.path, 300);
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadStorageFile({
    required String bucket,
    required String path,
    required Uint8List fileBytes,
  }) async {
    if (!_isConnected ||
        authUserId == null ||
        EvidenceReference.parse(EvidenceReference(bucket, path).value) == null)
      return null;

    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );

      return EvidenceReference(bucket, path).value;
    } catch (e) {
      return null;
    }
  }
}
