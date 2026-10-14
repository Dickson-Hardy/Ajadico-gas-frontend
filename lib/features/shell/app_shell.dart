import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/supabase_repository.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/notifications/forecourt_notification.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/offline/offline_sync_service.dart';
import '../../core/security/kiosk_security_manager.dart';
import '../../core/widgets/kiosk_security_guard.dart';
import '../../core/widgets/notification_bell.dart';
import '../../core/widgets/operations_workspace.dart';
import '../../core/widgets/page_transition_switcher.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';
import '../admin/attendant_salary_ledger_screen.dart';
import '../admin/bank_deposit_verification_screen.dart';
import '../admin/company_reports_screen.dart';
import '../admin/price_change_screen.dart';
import '../admin/staff_management_screen.dart';
import '../admin/station_setup_screen.dart';
import '../attendant/attendant_home_screen.dart';
import '../attendant/closing_readings_screen.dart';
import '../attendant/credit_sale_screen.dart';
import '../attendant/fuel_return_screen.dart';
import '../attendant/pump_expense_screen.dart';
import '../attendant/remittance_screen.dart';
import '../auth/login_screen.dart';
import '../onboarding/company_setup_screen.dart';
import '../cashier/daily_cash_count_screen.dart';
import '../cashier/verify_submission_screen.dart';
import '../credit/credit_customers_screen.dart';
import '../manager/expense_entry_screen.dart';
import '../manager/fuel_delivery_screen.dart';
import '../manager/manager_dashboard_screen.dart';
import '../manager/tank_dip_screen.dart';

enum AppView {
  login,
  attendantHome,
  closingReadings,
  remittance,
  creditSale,
  fuelReturn,
  verifySubmission,
  dailyCashCount,
  expenseEntry,
  tankDip,
  fuelDelivery,
  managerDashboard,
  priceChange,
  salaryLedger,
  bankDeposits,
  creditCustomers,
  companyReports,
  stationSetup,
  staffManagement,
  companySetup,
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final state = StationAppState.instance;
  final syncService = OfflineSyncService.instance;
  final securityManager = KioskSecurityManager.instance;
  final notifService = NotificationService.instance;
  AppView _currentView = AppView.login;
  bool _closingSession = false;
  bool _closeSessionFailed = false;
  StreamSubscription<String?>? _authSubscription;
  String? _sessionAuthId;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
    notifService.addListener(_onStateChanged);
    // Initialize Forecourt 60-second inactivity watchdog
    securityManager.initialize(onAutoLogout: _logout);
    final repo = SupabaseRepository.instance;
    if (repo.isConnected) {
      _authSubscription = repo.authIdentityChanges.listen((authId) {
        if (mounted &&
            state.currentUser.isActive &&
            (authId == null || authId != _sessionAuthId)) _logout();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    state.removeListener(_onStateChanged);
    notifService.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onLogin(UserProfile user) {
    _sessionAuthId = SupabaseRepository.instance.authUserId;
    securityManager.useManagementIdlePolicy(
        user.role == UserRole.manager || user.role == UserRole.director);
    state.setCurrentUser(user);
    state.refreshAuthenticatedPolicy();
    securityManager.resetInactivityTimer();
    securityManager.setSessionContext(
      stationId: state.currentStationCode,
      actorId: user.id,
    );
    setState(() {
      if (user.role == UserRole.attendant) {
        state.resetShiftProgress();
        _currentView = AppView.attendantHome;
      } else if (user.role == UserRole.cashier) {
        _currentView = AppView.verifySubmission;
      } else if (user.role == UserRole.manager) {
        _currentView = AppView.managerDashboard;
      } else {
        _currentView = AppView.companySetup;
      }
    });
  }

  void _logout() async {
    if (_closingSession) return;
    setState(() {
      _closingSession = true;
      _closeSessionFailed = false;
    });
    state.clearSession();
    // Close setup editors immediately when their authenticated session ends.
    Navigator.of(context).popUntil((route) => route.isFirst);
    _sessionAuthId = null;
    securityManager.setSessionContext(stationId: '', actorId: '');
    securityManager.useManagementIdlePolicy(false);
    // Keep the workspace closed until the previous JWT is removed.
    try {
      await SupabaseRepository.instance.endAuthenticatedSession();
    } catch (_) {
      // State/outbox remain signed out even if local auth cleanup fails.
      if (mounted)
        setState(() {
          _closingSession = false;
          _closeSessionFailed = true;
        });
      return;
    }
    if (!mounted) return;
    setState(() {
      _closingSession = false;
      _currentView = AppView.login;
    });
  }

  /// Screens each role is allowed to open (shared-tablet role gating).
  List<AppView> _allowedViews() {
    switch (state.currentUser.role) {
      case UserRole.attendant:
        return [
          AppView.attendantHome,
          AppView.closingReadings,
          AppView.remittance,
          AppView.creditSale,
          AppView.fuelReturn,
        ];
      case UserRole.cashier:
        return [
          AppView.verifySubmission,
          AppView.dailyCashCount,
          AppView.expenseEntry,
          AppView.creditCustomers,
        ];
      case UserRole.manager:
        return [
          AppView.managerDashboard,
          AppView.verifySubmission,
          AppView.dailyCashCount,
          AppView.expenseEntry,
          AppView.tankDip,
          AppView.fuelDelivery,
          AppView.creditCustomers,
          AppView.staffManagement,
        ];
      case UserRole.director:
        return [
          AppView.companyReports,
          AppView.managerDashboard,
          AppView.verifySubmission,
          AppView.dailyCashCount,
          AppView.expenseEntry,
          AppView.tankDip,
          AppView.fuelDelivery,
          AppView.priceChange,
          AppView.salaryLedger,
          AppView.bankDeposits,
          AppView.creditCustomers,
          AppView.stationSetup,
          AppView.staffManagement,
          AppView.companySetup,
        ];
    }
  }

  void _navigateTo(AppView view) {
    if (!_allowedViews().contains(view)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_viewName(view)} is not available to ${state.currentUser.role.name} accounts.'),
          backgroundColor: AppColors.bad,
        ),
      );
      return;
    }
    if (view == _currentView) return;
    _afterDiscardCheck(() => setState(() => _currentView = view));
  }

  void _afterDiscardCheck(VoidCallback action) {
    if (!ShellBackGuard.hasUnsavedWork) {
      action();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this page?'),
        content: const Text(
            'Your unsubmitted entries will be discarded. Submit them first or continue to the other page.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep editing')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                action();
              },
              child: const Text('Discard and continue')),
        ],
      ),
    );
  }

  String _workspaceLabel(AppView view) => switch (view) {
        AppView.login => 'Sign in',
        AppView.attendantHome => 'My shift',
        AppView.closingReadings => 'Meter readings',
        AppView.remittance => 'Shift remittance',
        AppView.creditSale => 'Credit sale',
        AppView.fuelReturn => 'Non-sale fuel',
        AppView.verifySubmission => 'Shift verification',
        AppView.dailyCashCount => 'Cash reconciliation',
        AppView.expenseEntry => 'Record expense',
        AppView.tankDip => 'Tank readings',
        AppView.fuelDelivery => 'Receive delivery',
        AppView.managerDashboard => 'Station overview',
        AppView.priceChange => 'Fuel prices',
        AppView.salaryLedger => 'Payroll & differences',
        AppView.bankDeposits => 'Deposit approvals',
        AppView.creditCustomers => 'Customer accounts',
        AppView.companyReports => 'Financial overview',
        AppView.stationSetup => 'Station configuration',
        AppView.staffManagement => 'People & access',
        AppView.companySetup => 'Company onboarding',
      };

  String _workspaceGroup(AppView view) => switch (view) {
        AppView.companyReports || AppView.managerDashboard => 'Overview',
        AppView.attendantHome ||
        AppView.closingReadings ||
        AppView.remittance ||
        AppView.verifySubmission ||
        AppView.dailyCashCount =>
          'Daily operations',
        AppView.creditSale ||
        AppView.creditCustomers ||
        AppView.expenseEntry ||
        AppView.salaryLedger ||
        AppView.bankDeposits =>
          'Accounts',
        AppView.tankDip ||
        AppView.fuelDelivery ||
        AppView.fuelReturn ||
        AppView.priceChange =>
          'Fuel & stock',
        _ => 'Administration',
      };

  Widget _buildWorkspace() {
    final views = _allowedViews()
        .where((view) =>
            state.currentUser.role != UserRole.attendant ||
            view == AppView.attendantHome)
        .toList()
      ..sort((a, b) {
        const groups = [
          'Overview',
          'Daily operations',
          'Accounts',
          'Fuel & stock',
          'Administration'
        ];
        final groupOrder = groups
            .indexOf(_workspaceGroup(a))
            .compareTo(groups.indexOf(_workspaceGroup(b)));
        return groupOrder == 0 ? a.index.compareTo(b.index) : groupOrder;
      });
    final role = switch (state.currentUser.role) {
      UserRole.attendant => 'Pump attendant',
      UserRole.cashier => 'Cashier',
      UserRole.manager => 'Branch manager',
      UserRole.director => 'Director',
    };
    return OperationsWorkspace(
      selectedId: _currentView.name,
      destinations: views
          .map((v) => WorkspaceDestination(
                id: v.name,
                label: _workspaceLabel(v),
                icon: _viewIcon(v),
                group: _workspaceGroup(v),
                count: v == AppView.verifySubmission
                    ? state.submissions
                        .where((s) => s.status == 'Pending Verification')
                        .length
                    : v == AppView.bankDeposits
                        ? state.deposits.where((d) => !d.isConfirmed).length
                        : 0,
              ))
          .toList(),
      onSelect: (id) => _navigateTo(AppView.values.byName(id)),
      userName: state.currentUser.displayName,
      roleLabel: role,
      stationName: state.currentStationName,
      onSignOut: _confirmSignOut,
      onToggleTheme: state.toggleTheme,
      stationPicker: state.currentUser.role == UserRole.director &&
              state.stations.isNotEmpty
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
              isExpanded: true,
              value:
                  state.stations.any((s) => s.code == state.currentStationCode)
                      ? state.currentStationCode
                      : null,
              hint: const Text('Select station'),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              items: state.stations
                  .map((s) => DropdownMenuItem(
                      value: s.code,
                      child: Text(s.name, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (code) {
                if (code == null || code == state.currentStationCode) return;
                _afterDiscardCheck(() => state.switchStation(
                    state.stations.firstWhere((s) => s.code == code)));
              },
            ))
          : null,
      notifications: NotificationBell(
          currentRole: state.currentUser.role,
          onNavigateToScreen: _navigateToNamedRoute),
      status: AnimatedBuilder(
        animation: syncService,
        builder: (context, _) {
          final queued = syncService.pendingCount;
          final failed = syncService.failedCount;
          final label = syncService.isSyncing
              ? 'Syncing records'
              : failed > 0
                  ? '$failed need retry'
                  : queued > 0
                      ? '$queued queued'
                      : syncService.isOnline
                          ? 'No queued records'
                          : 'Offline';
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                syncService.isSyncing
                    ? Icons.sync
                    : failed > 0
                        ? Icons.sync_problem
                        : syncService.isOnline
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                size: 16,
                color: failed > 0 ? AppColors.warn : AppColors.muted),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11)),
            if (failed > 0)
              TextButton(
                  onPressed: syncService.retryFailedItems,
                  child: const Text('Retry')),
          ]);
        },
      ),
      child: PageTransitionSwitcher(
          child: KeyedSubtree(
              key: ValueKey(_currentView), child: _buildCurrentScreen())),
    );
  }

  AppView? _resolveRoute(String routeName) {
    final key = routeName.trim().toLowerCase();
    const aliases = <String, AppView>{
      '19 salary ledger': AppView.salaryLedger,
      '16 cashier verification': AppView.verifySubmission,
      'attendant home': AppView.attendantHome,
      'cashier verification': AppView.verifySubmission,
      'credit ledgers': AppView.creditCustomers,
      'credit customers': AppView.creditCustomers,
    };
    final alias = aliases[key];
    if (alias != null) return alias;
    for (final v in AppView.values) {
      if (_viewName(v).toLowerCase() == key) return v;
    }
    return null;
  }

  void _navigateToNamedRoute(String routeName) {
    final view = _resolveRoute(routeName);
    if (view == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'This alert does not map to an openable screen ($routeName).'),
          backgroundColor: AppColors.warn,
        ),
      );
      return;
    }
    _navigateTo(view);
  }

  @override
  Widget build(BuildContext context) {
    if (_closingSession || _closeSessionFailed) {
      return Scaffold(
          body: Center(
              child: _closeSessionFailed
                  ? FilledButton(
                      onPressed: _logout,
                      child: const Text('Retry secure sign-out'))
                  : const CircularProgressIndicator()));
    }
    final headsUp = notifService.latestHeadsUp;

    return KioskSecurityGuard(
      onLockedOutLogout: _logout,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleSystemBack();
        },
        child: Stack(
          children: [
            Scaffold(
              body: _currentView == AppView.login ||
                      _currentView == AppView.companySetup
                  ? _buildCurrentScreen()
                  : _buildWorkspace(),
            ),

            // In-App Heads-Up Alert Popup Toast
            if (headsUp != null)
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: headsUp.type == NotificationType.critical
                          ? AppColors.badSurface
                          : (headsUp.type == NotificationType.warning
                              ? AppColors.warnSurface
                              : AppColors.okSurface),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: headsUp.type == NotificationType.critical
                            ? AppColors.bad
                            : (headsUp.type == NotificationType.warning
                                ? AppColors.warn
                                : AppColors.ok),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          headsUp.type == NotificationType.critical
                              ? Icons.error_outline
                              : (headsUp.type == NotificationType.warning
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline),
                          color: headsUp.type == NotificationType.critical
                              ? AppColors.bad
                              : (headsUp.type == NotificationType.warning
                                  ? AppColors.warnInk
                                  : AppColors.ok),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headsUp.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.ink),
                              ),
                              Text(
                                headsUp.message,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.slate),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (headsUp.actionRouteName != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final route = headsUp.actionRouteName!;
                              notifService.dismissHeadsUp();
                              _navigateToNamedRoute(route);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(64, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            child: const Text('View',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: AppColors.slate),
                          onPressed: () => notifService.dismissHeadsUp(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  AppView _homeViewForRole() {
    switch (state.currentUser.role) {
      case UserRole.attendant:
        return AppView.attendantHome;
      case UserRole.cashier:
        return AppView.verifySubmission;
      case UserRole.manager:
        return AppView.managerDashboard;
      case UserRole.director:
        return AppView.companyReports;
    }
  }

  void _handleSystemBack() {
    if (_currentView == AppView.login) {
      SystemNavigator.pop();
      return;
    }
    if (ShellBackGuard.hasUnsavedWork) {
      _confirmDiscardWork();
      return;
    }
    final home = _homeViewForRole();
    if (_currentView == home) {
      _confirmSignOut();
      return;
    }
    _navigateTo(home);
  }

  void _confirmDiscardWork() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'This screen still has entries that have not been submitted. Leaving now discards them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateTo(_homeViewForRole());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bad,
              foregroundColor: Colors.white,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End shift session?'),
        content: const Text('Sign out of this shared forecourt tablet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _openShiftEntry(Widget Function(VoidCallback close) page) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (entryContext) {
        void close() => Navigator.of(entryContext).pop();
        return Dialog.fullscreen(
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _afterDiscardCheck(close);
            },
            child: page(close),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentView) {
      case AppView.companySetup:
        return CompanySetupScreen(
            onSignOut: _logout,
            onContinue: () =>
                setState(() => _currentView = AppView.companyReports));
      case AppView.login:
        return LoginScreen(onLoginSuccess: _onLogin);

      case AppView.attendantHome:
        return AttendantHomeScreen(
          user: state.currentUser,
          onLogout: _logout,
          onOpenClosingReadings: () => _openShiftEntry((close) =>
              ClosingReadingsScreen(onBack: close, onSubmitSuccess: close)),
          onOpenRemittance: () => _openShiftEntry((close) =>
              RemittanceScreen(onBack: close, onSubmitSuccess: close)),
          onOpenCreditSale: () => _openShiftEntry(
              (close) => CreditSaleScreen(onBack: close, onSuccess: close)),
          onOpenFuelReturn: () => _openShiftEntry(
              (close) => FuelReturnScreen(onBack: close, onSuccess: close)),
          onOpenPumpExpense: () => _openShiftEntry(
              (close) => PumpExpenseScreen(onBack: close, onSuccess: close)),
        );

      case AppView.closingReadings:
        return ClosingReadingsScreen(
          onBack: () => setState(() => _currentView = AppView.attendantHome),
          onSubmitSuccess: () =>
              setState(() => _currentView = AppView.remittance),
        );

      case AppView.remittance:
        return RemittanceScreen(
          onBack: () => setState(() => _currentView = AppView.attendantHome),
          onSubmitSuccess: () =>
              setState(() => _currentView = AppView.attendantHome),
        );

      case AppView.creditSale:
        return CreditSaleScreen(
          onBack: () => setState(() => _currentView = AppView.attendantHome),
          onSuccess: () => setState(() => _currentView = AppView.attendantHome),
        );

      case AppView.fuelReturn:
        return FuelReturnScreen(
          onBack: () => setState(() => _currentView = AppView.attendantHome),
          onSuccess: () => setState(() => _currentView = AppView.attendantHome),
        );

      case AppView.verifySubmission:
        return VerifySubmissionScreen(
          onBack: () => setState(() {
            _currentView = state.currentUser.role == UserRole.cashier
                ? AppView.dailyCashCount
                : AppView.managerDashboard;
          }),
          onVerified: () =>
              setState(() => _currentView = AppView.dailyCashCount),
          onOpenExpenseEntry: () =>
              setState(() => _currentView = AppView.expenseEntry),
        );

      case AppView.dailyCashCount:
        return DailyCashCountScreen(
          onBack: () => setState(() {
            _currentView = state.currentUser.role == UserRole.cashier
                ? AppView.verifySubmission
                : AppView.managerDashboard;
          }),
          onOpenExpenseEntry: () =>
              setState(() => _currentView = AppView.expenseEntry),
        );

      case AppView.expenseEntry:
        return ExpenseEntryScreen(
          onBack: () => setState(() {
            _currentView = state.currentUser.role == UserRole.cashier
                ? AppView.dailyCashCount
                : (state.currentUser.role == UserRole.director
                    ? AppView.companyReports
                    : AppView.managerDashboard);
          }),
          onSuccess: () => setState(() {
            _currentView = state.currentUser.role == UserRole.cashier
                ? AppView.dailyCashCount
                : (state.currentUser.role == UserRole.director
                    ? AppView.companyReports
                    : AppView.managerDashboard);
          }),
        );

      case AppView.tankDip:
        return TankDipScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onSuccess: () =>
              setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.fuelDelivery:
        return FuelDeliveryScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onSuccess: () =>
              setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.managerDashboard:
        return ManagerDashboardScreen(
          onOpenVerificationQueue: () =>
              setState(() => _currentView = AppView.verifySubmission),
          onOpenCashCount: () =>
              setState(() => _currentView = AppView.dailyCashCount),
          onOpenCreditCustomers: () =>
              setState(() => _currentView = AppView.creditCustomers),
          onOpenTankDip: () => setState(() => _currentView = AppView.tankDip),
          onOpenFuelDelivery: () =>
              setState(() => _currentView = AppView.fuelDelivery),
          onOpenStaffManagement: () =>
              setState(() => _currentView = AppView.staffManagement),
          onOpenExpenseEntry: () =>
              setState(() => _currentView = AppView.expenseEntry),
          onLogout: _logout,
        );

      case AppView.priceChange:
        return PriceChangeScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onSuccess: () =>
              setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.salaryLedger:
        return AttendantSalaryLedgerScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.bankDeposits:
        return BankDepositVerificationScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.creditCustomers:
        return CreditCustomersScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.companyReports:
        return CompanyReportsScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onOpenStationSetup: () =>
              setState(() => _currentView = AppView.stationSetup),
          onOpenStaffManagement: () =>
              setState(() => _currentView = AppView.staffManagement),
          onOpenExpenseEntry: () =>
              setState(() => _currentView = AppView.expenseEntry),
        );

      case AppView.stationSetup:
        return StationSetupScreen(
          onBack: () => setState(() => _currentView = AppView.companyReports),
        );

      case AppView.staffManagement:
        return StaffManagementScreen(
          onBack: () => setState(() {
            _currentView = state.currentUser.role == UserRole.director
                ? AppView.companyReports
                : AppView.managerDashboard;
          }),
        );
    }
  }

  String _viewName(AppView view) {
    switch (view) {
      case AppView.login:
        return '01 Login';
      case AppView.attendantHome:
        return '02 Attendant Home';
      case AppView.closingReadings:
        return '04 Closing Readings';
      case AppView.remittance:
        return '05 Remittance';
      case AppView.creditSale:
        return '06 Credit Sale (Pump)';
      case AppView.fuelReturn:
        return '07 Fuel Return / Calibration';
      case AppView.verifySubmission:
        return '09 Verify Submission';
      case AppView.dailyCashCount:
        return '10 Cash Count';
      case AppView.expenseEntry:
        return '11 Record Expense';
      case AppView.tankDip:
        return '12 Tank Dip Audit';
      case AppView.fuelDelivery:
        return '13 Fuel Delivery (Waybill)';
      case AppView.managerDashboard:
        return '17 Manager Dashboard';
      case AppView.priceChange:
        return '18 Retail Fuel Prices';
      case AppView.salaryLedger:
        return '19 Salary Deductions';
      case AppView.bankDeposits:
        return '20 Bank Deposits';
      case AppView.creditCustomers:
        return '21 Credit Ledgers';
      case AppView.companyReports:
        return '22 Consolidated P&L';
      case AppView.stationSetup:
        return '23 Forecourt & Station Setup';
      case AppView.staffManagement:
        return '24 Staff & Attendants';
      case AppView.companySetup:
        return 'Company onboarding';
    }
  }

  IconData _viewIcon(AppView view) {
    switch (view) {
      case AppView.login:
        return Icons.pin_drop;
      case AppView.attendantHome:
        return Icons.local_gas_station;
      case AppView.closingReadings:
        return Icons.speed;
      case AppView.remittance:
        return Icons.receipt_long;
      case AppView.creditSale:
        return Icons.credit_card;
      case AppView.fuelReturn:
        return Icons.replay;
      case AppView.verifySubmission:
        return Icons.fact_check;
      case AppView.dailyCashCount:
        return Icons.point_of_sale;
      case AppView.expenseEntry:
        return Icons.money_off;
      case AppView.tankDip:
        return Icons.straighten;
      case AppView.fuelDelivery:
        return Icons.local_shipping;
      case AppView.managerDashboard:
        return Icons.dashboard;
      case AppView.priceChange:
        return Icons.price_change;
      case AppView.salaryLedger:
        return Icons.badge;
      case AppView.bankDeposits:
        return Icons.account_balance;
      case AppView.creditCustomers:
        return Icons.groups;
      case AppView.companyReports:
        return Icons.insert_chart;
      case AppView.stationSetup:
        return Icons.settings_suggest;
      case AppView.staffManagement:
        return Icons.badge_outlined;
      case AppView.companySetup:
        return Icons.domain_add_outlined;
    }
  }
}
