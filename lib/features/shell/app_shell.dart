import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
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
  AppView _currentView = AppView.login;

  @override
  void initState() {
    super.initState();
    state.addListener(_onStateChanged);
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

    return Scaffold(
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
        return '18 Price Authorization';
      case AppView.salaryLedger:
        return '19 Attendant Salary Ledger';
      case AppView.bankDeposits:
        return '20 Bank Deposit Approvals';
      case AppView.creditCustomers:
        return '21 Credit Customers';
      case AppView.companyReports:
        return '22 Company P&L Reports';
    }
  }

  void _showScreenSwitcherDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Prototype Screen Explorer',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.ok.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Real-Time Connected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ok)),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text('Data flows across all roles in memory and to Supabase.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
                  const Divider(color: AppColors.line),
                  ...AppView.values.map((v) {
                    final isSelected = v == _currentView;
                    return ListTile(
                      dense: true,
                      title: Text(
                        _viewName(v),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.ok : AppColors.ink,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.ok, size: 20) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _currentView = v);
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
