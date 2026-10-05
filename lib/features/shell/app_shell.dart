import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/offline/offline_sync_service.dart';
import '../../core/security/kiosk_security_manager.dart';
import '../../core/widgets/kiosk_security_guard.dart';
import '../../models/user_profile.dart';
import '../../state/station_app_state.dart';
import '../admin/attendant_salary_ledger_screen.dart';
import '../admin/bank_deposit_verification_screen.dart';
import '../admin/company_reports_screen.dart';
import '../admin/price_change_screen.dart';
import '../attendant/attendant_home_screen.dart';
import '../attendant/closing_readings_screen.dart';
import '../attendant/credit_sale_screen.dart';
import '../attendant/fuel_return_screen.dart';
import '../attendant/remittance_screen.dart';
import '../auth/login_screen.dart';
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
  AppView _currentView = AppView.login;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
    // Initialize Forecourt 60-second inactivity watchdog
    securityManager.initialize(onAutoLogout: _logout);
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onLogin(UserProfile user) {
    state.setCurrentUser(user);
    securityManager.resetInactivityTimer();
    setState(() {
      if (user.role == UserRole.attendant) {
        _currentView = AppView.attendantHome;
      } else if (user.role == UserRole.cashier) {
        _currentView = AppView.verifySubmission;
      } else if (user.role == UserRole.manager) {
        _currentView = AppView.managerDashboard;
      } else {
        _currentView = AppView.companyReports;
      }
    });
  }

  void _logout() {
    setState(() {
      _currentView = AppView.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingAudits = state.submissions.where((s) => s.status == 'Pending Verification').length;

    return KioskSecurityGuard(
      onLockedOutLogout: _logout,
      child: Scaffold(
        body: _buildCurrentScreen(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showScreenSwitcherDialog,
          backgroundColor: AppColors.ink,
          icon: Badge(
            isLabelVisible: pendingAudits > 0,
            label: Text('$pendingAudits'),
            child: const Icon(Icons.layers, color: Colors.white, size: 20),
          ),
          label: Text(
            'View: ${_viewName(_currentView)}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentView) {
      case AppView.login:
        return LoginScreen(onLoginSuccess: _onLogin);

      case AppView.attendantHome:
        return AttendantHomeScreen(
          user: state.currentUser,
          onLogout: _logout,
          onOpenClosingReadings: () => setState(() => _currentView = AppView.closingReadings),
          onOpenRemittance: () => setState(() => _currentView = AppView.remittance),
        );

      case AppView.closingReadings:
        return ClosingReadingsScreen(
          onBack: () => setState(() => _currentView = AppView.attendantHome),
          onSubmitSuccess: () => setState(() => _currentView = AppView.remittance),
        );

      case AppView.remittance:
        return RemittanceScreen(
          onBack: () => setState(() => _currentView = AppView.attendantHome),
          onSubmitSuccess: () => setState(() => _currentView = AppView.attendantHome),
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
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onVerified: () => setState(() => _currentView = AppView.dailyCashCount),
        );

      case AppView.dailyCashCount:
        return DailyCashCountScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.expenseEntry:
        return ExpenseEntryScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onSuccess: () => setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.tankDip:
        return TankDipScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onSuccess: () => setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.fuelDelivery:
        return FuelDeliveryScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onSuccess: () => setState(() => _currentView = AppView.managerDashboard),
        );

      case AppView.managerDashboard:
        return ManagerDashboardScreen(
          onOpenVerificationQueue: () => setState(() => _currentView = AppView.verifySubmission),
          onOpenCashCount: () => setState(() => _currentView = AppView.dailyCashCount),
          onOpenCreditCustomers: () => setState(() => _currentView = AppView.creditCustomers),
          onLogout: _logout,
        );

      case AppView.priceChange:
        return PriceChangeScreen(
          onBack: () => setState(() => _currentView = AppView.managerDashboard),
          onSuccess: () => setState(() => _currentView = AppView.managerDashboard),
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
    }
  }

  void _showScreenSwitcherDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ajadico Forecourt Navigator',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Offline Simulation Control
                  AnimatedBuilder(
                    animation: syncService,
                    builder: (context, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: syncService.isOnline ? AppColors.lightEmerald : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: syncService.isOnline ? AppColors.emerald : AppColors.amber,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  syncService.isOnline ? Icons.wifi : Icons.wifi_off,
                                  size: 18,
                                  color: syncService.isOnline ? AppColors.emerald : AppColors.amber,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  syncService.isOnline ? 'Online Forecourt Network' : 'Simulated Offline Mode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: syncService.isOnline ? AppColors.emerald : const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: syncService.isOnline,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                syncService.setSimulatedConnectivity(val);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Jump to any production screen or role workflow:',
                    style: TextStyle(fontSize: 13, color: AppColors.slate),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: AppView.values.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final view = AppView.values[index];
                        final isSelected = view == _currentView;

                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: AppColors.primary.withOpacity(0.08),
                          leading: Icon(
                            _viewIcon(view),
                            color: isSelected ? AppColors.primary : AppColors.slate,
                            size: 20,
                          ),
                          title: Text(
                            _viewName(view),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primary : AppColors.ink,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: AppColors.primary, size: 18)
                              : null,
                          onTap: () {
                            setState(() => _currentView = view);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
    }
  }
}
