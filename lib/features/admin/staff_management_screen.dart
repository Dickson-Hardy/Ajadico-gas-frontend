import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/shell_back_guard.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/station.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';

/// Staff & Attendant Management Screen (BRD v3 §2.1, §2.2, §2.3, §4.7)
///
/// Features:
/// - Zero Demo Data: strictly binds to live database records or genuine empty states.
/// - Full Onboarding Fields: Name, Display Name, Role, Station, Phone,
///   Residential Address, Shortee / Guarantor Name, Shortee Phone & Address, and 4-digit PIN.
/// - Role Boundaries:
///   * Branch Manager & Director: Can onboard staff, reset tablet login PINs, and toggle active status.
///   * Director / Admin ONLY: Can view and set monthly base salary (`base_salary`).
///     Branch Managers see "Confidential (Corporate HQ)" with a padlock icon.
class StaffManagementScreen extends StatefulWidget {
  final VoidCallback onBack;

  const StaffManagementScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> with UnsavedWorkAware {
  final state = StationAppState.instance;

  String _searchQuery = '';
  UserRole? _filterRole;
  String _filterStation = 'All';
  bool _isProcessing = false;
  bool _onboardDirty = false;

  @override
  bool get hasUnsavedWork => _onboardDirty || _isProcessing;

  List<Station> get _activeStations {
    if (state.stations.isNotEmpty) {
      return state.stations;
    }
    return [
      Station(
        id: 'current',
        code: state.currentStationCode,
        name: state.currentStationName,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    ShellBackGuard.register(this);
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    ShellBackGuard.unregister(this);
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  bool get _isDirector => state.currentUser.role == UserRole.director;

  List<UserProfile> get _filteredStaff {
    return state.staff.where((s) {
      if (_filterRole != null && s.role != _filterRole) return false;
      if (_filterStation != 'All' && !s.stationName.contains(_filterStation)) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = s.fullName.toLowerCase().contains(query);
        final matchesDisplay = s.displayName.toLowerCase().contains(query);
        final matchesPhone = s.phone?.toLowerCase().contains(query) ?? false;
        final matchesAddress = s.address?.toLowerCase().contains(query) ?? false;
        final matchesSurety = s.suretyName?.toLowerCase().contains(query) ?? false;
        final matchesSuretyPhone = s.suretyPhone?.toLowerCase().contains(query) ?? false;
        if (!matchesName && !matchesDisplay && !matchesPhone && !matchesAddress && !matchesSurety && !matchesSuretyPhone) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final staffList = _filteredStaff;
    final totalAttendants = state.staff.where((s) => s.role == UserRole.attendant).length;
    final totalCashiers = state.staff.where((s) => s.role == UserRole.cashier).length;
    final totalManagers = state.staff.where((s) => s.role == UserRole.manager).length;
    final totalActive = state.staff.where((s) => s.isActive).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff & Attendant Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _isDirector
                  ? 'Executive Director · Full Access & Payroll (§2.1, §4.7)'
                  : 'Branch Manager · Staff Onboarding & Forecourt PINs (§2.1–§2.3)',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _openOnboardStaffDialog,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add, size: 18),
                label: Text(_isProcessing ? 'Processing...' : 'Onboard New Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // KPI Summary Strip
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricChip('Total Registered Staff', '${state.staff.length}', AppColors.ink, Icons.badge),
                    _buildMetricChip('Pump Attendants', '$totalAttendants', AppColors.primary, Icons.local_gas_station),
                    _buildMetricChip('Cashiers', '$totalCashiers', AppColors.pos, Icons.point_of_sale),
                    _buildMetricChip('Branch Managers', '$totalManagers', AppColors.amber, Icons.manage_accounts),
                    _buildMetricChip('Active On Duty', '$totalActive', AppColors.ok, Icons.check_circle_outline),
                  ],
                ),
                const SizedBox(height: 20),

                // Search & Filter Toolbar
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                                  hintText: 'Search by name, phone, address, or shortee (guarantor)...',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: AppColors.border),
                                  ),
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_isDirector) ...[
                              Builder(
                                builder: (context) {
                                  final stationOptions = ['All', ..._activeStations.map((s) => s.name)];
                                  final currentVal = stationOptions.contains(_filterStation) ? _filterStation : 'All';
                                  return DropdownButton<String>(
                                    value: currentVal,
                                    underline: const SizedBox(),
                                    items: stationOptions.map((name) {
                                      return DropdownMenuItem(
                                        value: name,
                                        child: Text(name == 'All' ? 'All Stations' : name),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _filterStation = val);
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Role Filter Tabs
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildRoleFilterChip(null, 'All Roles (${state.staff.length})'),
                              const SizedBox(width: 8),
                              _buildRoleFilterChip(UserRole.attendant, 'Attendants ($totalAttendants)'),
                              const SizedBox(width: 8),
                              _buildRoleFilterChip(UserRole.cashier, 'Cashiers ($totalCashiers)'),
                              const SizedBox(width: 8),
                              _buildRoleFilterChip(UserRole.manager, 'Managers ($totalManagers)'),
                              const SizedBox(width: 8),
                              _buildRoleFilterChip(
                                UserRole.director,
                                'HQ Directors (${state.staff.where((s) => s.role == UserRole.director).length})',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // List of Staff Cards or Zero State
                if (staffList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.people_outline, size: 56, color: AppColors.muted),
                        const SizedBox(height: 12),
                        Text(
                          state.staff.isEmpty
                              ? 'Zero Registered Staff'
                              : 'No staff profiles match this filter',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.staff.isEmpty
                              ? 'No staff members have been onboarded yet. Onboard attendants and cashiers with their residential address, shortee (guarantor), and PIN.'
                              : 'Try clearing your search query or role filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.muted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openOnboardStaffDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Onboard New Staff'),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: staffList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final staff = staffList[index];
                      return _buildStaffCard(staff);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(UserRole? role, String label) {
    final isSelected = _filterRole == role;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() => _filterRole = val ? role : null);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.ink,
      ),
    );
  }

  Widget _buildStaffCard(UserProfile staff) {
    final roleColor = _getRoleColor(staff.role);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: staff.isActive ? AppColors.border : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;

            final infoSection = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Role Indicator
                CircleAvatar(
                  radius: 26,
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  child: Text(
                    _getInitials(staff.fullName),
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              staff.fullName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: staff.isActive ? AppColors.ink : AppColors.muted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '(${staff.displayName})',
                              style: const TextStyle(fontSize: 13, color: AppColors.muted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: staff.isActive ? 'Active' : 'Inactive',
                            type: staff.isActive ? ChipType.ok : ChipType.draft,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              staff.role.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text(staff.stationName, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                          if (staff.phone != null && staff.phone!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_outlined, size: 14, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Text(staff.phone!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                        ],
                      ),

                      // Staff Residential Address
                      if (staff.address != null && staff.address!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.home_outlined, size: 14, color: AppColors.slate),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Address: ${staff.address}',
                                style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Guarantor / Shortee Section
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, size: 15, color: AppColors.slate),
                            const SizedBox(width: 6),
                            Text(
                              'Shortee (Guarantor): ',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                            if (staff.suretyName != null && staff.suretyName!.isNotEmpty) ...[
                              Flexible(
                                child: Text(
                                  '${staff.suretyName} (${staff.suretyPhone ?? "No phone"})',
                                  style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (staff.suretyAddress != null && staff.suretyAddress!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '· ${staff.suretyAddress}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ] else ...[
                              const Text(
                                'Not recorded',
                                style: TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // BASE SALARY ROW (Director vs Manager Strict Separation §4.7)
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isDirector ? AppColors.okSurface : AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _isDirector ? const Color(0xFFBBF7D0) : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isDirector ? Icons.payments_outlined : Icons.lock_outline,
                              size: 15,
                              color: _isDirector ? AppColors.ok : AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Base Salary: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isDirector ? AppColors.ink : AppColors.muted,
                              ),
                            ),
                            if (_isDirector) ...[
                              Text(
                                '${CurrencyFormatter.formatNaira(staff.baseSalary)} / month',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ok,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => _openEditSalaryDialog(staff),
                                icon: const Icon(Icons.edit, size: 14, color: AppColors.primary),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  visualDensity: VisualDensity.standard,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Confidential (Corporate HQ)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final actionsSection = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reset PIN Button
                OutlinedButton.icon(
                  onPressed: () => _openResetPinDialog(staff),
                  icon: const Icon(Icons.pin, size: 16),
                  label: const Text('Reset PIN'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                // Toggle Active Button
                OutlinedButton(
                  onPressed: () => _toggleStaffStatus(staff),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: staff.isActive ? AppColors.cherry : AppColors.ok,
                    side: BorderSide(
                      color: staff.isActive ? AppColors.cherry : AppColors.ok,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: Text(staff.isActive ? 'Deactivate' : 'Activate'),
                ),
              ],
            );

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoSection,
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actionsSection),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: infoSection),
                const SizedBox(width: 16),
                actionsSection,
              ],
            );
          },
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.attendant:
        return AppColors.accent;
      case UserRole.cashier:
        return AppColors.pos;
      case UserRole.manager:
        return AppColors.amber;
      case UserRole.director:
        return AppColors.ok;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'ST';
  }

  // ---------------------------------------------------------------------------
  // DIALOGS & ACTIONS
  // ---------------------------------------------------------------------------

  void _openOnboardStaffDialog() {
    final fullNameCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final suretyNameCtrl = TextEditingController();
    final suretyPhoneCtrl = TextEditingController();
    final suretyAddressCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();

    UserRole selectedRole = UserRole.attendant;
    String selectedStationCode = _activeStations.any((s) => s.code == state.currentStationCode)
        ? state.currentStationCode
        : _activeStations.first.code;
    bool obscurePin = true;

    final controllers = [
      fullNameCtrl,
      displayNameCtrl,
      phoneCtrl,
      addressCtrl,
      suretyNameCtrl,
      suretyPhoneCtrl,
      suretyAddressCtrl,
      pinCtrl,
      salaryCtrl,
    ];
    void markDirty() {
      if (!_onboardDirty && mounted) {
        setState(() => _onboardDirty = true);
      }
    }

    for (final c in controllers) {
      c.addListener(markDirty);
    }
    _onboardDirty = false;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.person_add, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text('Onboard New Staff Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Register a new forecourt staff profile with role credentials, address, shortee (guarantor), and kiosk PIN (§2.2).',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),

                      // Full Name
                      TextField(
                        controller: fullNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Legal Name *',
                          hintText: 'e.g. Babatunde Lawal',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          // Auto-suggest Display Name (e.g. Babatunde L.)
                          final parts = val.trim().split(' ');
                          if (parts.length >= 2 && displayNameCtrl.text.isEmpty) {
                            setDialogState(() {
                              displayNameCtrl.text = '${parts[0]} ${parts[1][0]}.';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Display Name & Role in Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: displayNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Display Name *',
                                hintText: 'e.g. Baba L.',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<UserRole>(
                              initialValue: selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Assigned Role *',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: UserRole.attendant,
                                  child: Text('Pump Attendant'),
                                ),
                                const DropdownMenuItem(
                                  value: UserRole.cashier,
                                  child: Text('Cashier'),
                                ),
                                const DropdownMenuItem(
                                  value: UserRole.manager,
                                  child: Text('Branch Manager'),
                                ),
                                if (_isDirector)
                                  const DropdownMenuItem(
                                    value: UserRole.director,
                                    child: Text('Director / HQ Admin'),
                                  ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  markDirty();
                                  setDialogState(() => selectedRole = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Station & Phone in Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedStationCode,
                              decoration: const InputDecoration(
                                labelText: 'Assigned Station *',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _activeStations.map((st) {
                                return DropdownMenuItem(
                                  value: st.code,
                                  child: Text(st.name, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  markDirty();
                                  setDialogState(() => selectedStationCode = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Staff Phone Number *',
                                hintText: '08012345678',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                final v = (val ?? '').trim();
                                if (v.isEmpty) return 'Phone number is required.';
                                if (RegExp(r'^\d{7,15}$').hasMatch(v)) return null;
                                return 'Enter a valid phone number.';
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Staff Residential Home Address
                      TextField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Staff Residential Address *',
                          hintText: 'e.g. 14 Adeleke Street, Lekki Phase 1, Lagos',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // SHORTEE / GUARANTOR SECTION (§2.2)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user_outlined, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text(
                                  'Shortee / Guarantor Information (§2.2)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'The guarantor legally stands for pump shortages, cash discrepancies, or absconding.',
                              style: TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: suretyNameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Shortee Full Name *',
                                      hintText: 'e.g. Chief Emeka Okafor',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: suretyPhoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Shortee Phone Number *',
                                      hintText: '08031234567',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: suretyAddressCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Shortee Residential / Office Address',
                                hintText: 'e.g. 22 Broad Street, Lagos Island',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 4-Digit Tablet PIN
                      TextField(
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: obscurePin,
                        decoration: InputDecoration(
                          labelText: '4-Digit Tablet Login PIN *',
                          hintText: '####',
                          isDense: true,
                          counterText: '',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePin ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setDialogState(() => obscurePin = !obscurePin),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // BASE SALARY SECTION (Role Sensitive)
                      if (_isDirector) ...[
                        TextFormField(
                          controller: salaryCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Monthly Base Salary (₦) [Director Only] *',
                            hintText: 'e.g. 75000',
                            isDense: true,
                            prefixText: '₦ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            final v = (val ?? '').trim();
                            if (v.isEmpty) return 'Monthly base salary is required.';
                            final parsed = double.tryParse(v);
                            if (parsed == null || parsed <= 0) {
                              return 'Enter an amount greater than ₦0.';
                            }
                            return null;
                          },
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 20, color: AppColors.muted),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Base salary is strictly authorized by Corporate HQ (Managing Director). New staff profile will start with ₦0.00 until approved by Director.',
                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (_onboardDirty) {
                      final discard = await showDialog<bool>(
                        context: context,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Discard onboarding form?'),
                          content: const Text('This staff profile has unsaved entries. Closing now discards them.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dctx, false),
                              child: const Text('Keep Editing'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.bad,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Discard'),
                            ),
                          ],
                        ),
                      );
                      if (discard != true) return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() != true) return;

                          final fullName = fullNameCtrl.text.trim();
                          final displayName = displayNameCtrl.text.trim();
                          final pin = pinCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          final address = addressCtrl.text.trim();
                          final suretyName = suretyNameCtrl.text.trim();
                          final suretyPhone = suretyPhoneCtrl.text.trim();
                          final suretyAddress = suretyAddressCtrl.text.trim();
                          final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;

                          if (fullName.isEmpty || displayName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please provide full legal name and display name.')),
                            );
                            return;
                          }
                          if (pin.length != 4 || int.tryParse(pin) == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tablet login PIN must be exactly 4 digits.')),
                            );
                            return;
                          }
                          if (address.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter staff residential address.')),
                            );
                            return;
                          }
                          if (suretyName.isEmpty || suretyPhone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter shortee (guarantor) name and phone number.')),
                            );
                            return;
                          }

                          if (!mounted) return;
                          setState(() => _isProcessing = true);
                          setDialogState(() {});

                          try {
                            final created = await state.onboardStaff(
                              fullName: fullName,
                              displayName: displayName,
                              role: selectedRole,
                              pin: pin,
                              stationCode: selectedStationCode,
                              phone: phone.isNotEmpty ? phone : null,
                              address: address,
                              suretyName: suretyName,
                              suretyPhone: suretyPhone,
                              suretyAddress: suretyAddress.isNotEmpty ? suretyAddress : null,
                              baseSalary: salary,
                            );

                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _onboardDirty = false;
                              });
                            }
                            if (ctx.mounted) Navigator.pop(ctx);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: created != null ? AppColors.ok : AppColors.cherry,
                                  content: Text(
                                    created != null
                                        ? 'Staff profile onboarded successfully for ${created.fullName}.'
                                        : 'Failed to create staff profile. Please try again.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isProcessing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.cherry,
                                  content: Text('Onboarding failed: $e'),
                                ),
                              );
                            }
                          }
                        },
                  child: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save & Register'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      for (final c in controllers) {
        c.removeListener(markDirty);
      }
      if (mounted && _onboardDirty) {
        setState(() => _onboardDirty = false);
      }
    });
  }

  void _openEditSalaryDialog(UserProfile staff) {
    if (!_isDirector) return;

    final salaryCtrl = TextEditingController(text: staff.baseSalary.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.ok),
              const SizedBox(width: 8),
              const Text('Update Monthly Base Salary'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff: ${staff.fullName} (${staff.role.name.toUpperCase()})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Station: ${staff.stationName}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: salaryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'New Monthly Base Salary (₦) *',
                  prefixText: '₦ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newSalary = double.tryParse(salaryCtrl.text.trim());
                if (newSalary == null || newSalary < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid salary amount.')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final ok = await state.updateStaffSalary(profileId: staff.id, baseSalary: newSalary);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: ok ? AppColors.ok : AppColors.cherry,
                      content: Text(
                        ok
                            ? 'Base salary updated to ${CurrencyFormatter.formatNaira(newSalary)} for ${staff.displayName}.'
                            : 'Failed to update salary.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Update Salary'),
            ),
          ],
        );
      },
    );
  }

  void _openResetPinDialog(UserProfile staff) {
    final pinCtrl = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.pin, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Reset Tablet PIN'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resetting shared tablet PIN for ${staff.fullName} (${staff.displayName})',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'New 4-Digit PIN *',
                      counterText: '',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pin = pinCtrl.text.trim();
                    if (pin.length != 4 || int.tryParse(pin) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN must be exactly 4 digits.')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    final ok = await state.resetStaffPin(profileId: staff.id, newPin: pin);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: ok ? AppColors.ok : AppColors.cherry,
                          content: Text(
                            ok
                                ? 'PIN reset successfully for ${staff.displayName}.'
                                : 'Failed to reset PIN.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Set New PIN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleStaffStatus(UserProfile staff) async {
    final nextStatus = !staff.isActive;
    final actionLabel = nextStatus ? 'Reactivate' : 'Deactivate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel Staff Member?'),
        content: Text(
          'Are you sure you want to $actionLabel ${staff.fullName} (${staff.displayName})? '
          '${nextStatus ? "They will regain access to tablet logins." : "They will be blocked from logging into station tablets."}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: nextStatus ? AppColors.ok : AppColors.cherry,
              foregroundColor: Colors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await state.toggleStaffStatus(profileId: staff.id, isActive: nextStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? AppColors.ok : AppColors.cherry,
            content: Text(
              ok
                  ? '${staff.displayName} status changed to ${nextStatus ? "Active" : "Inactive"}.'
                  : 'Failed to update staff status.',
            ),
          ),
        );
      }
    }
  }
}
