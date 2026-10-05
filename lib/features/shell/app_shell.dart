import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_profile.dart';
import '../attendant/attendant_home_screen.dart';
import '../attendant/closing_readings_screen.dart';
import '../attendant/remittance_screen.dart';
import '../auth/login_screen.dart';
import '../cashier/daily_cash_count_screen.dart';
import '../cashier/verify_submission_screen.dart';
import '../credit/credit_customers_screen.dart';
import '../manager/manager_dashboard_screen.dart';

enum AppView {
  login,
  attendantHome,
  closingReadings,
  remittance,
  verifySubmission,
  dailyCashCount,
  managerDashboard,
  creditCustomers,
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppView _currentView = AppView.login;
  UserProfile _currentUser = UserProfile.demoStaff[0]; // Amaka O.
  double _lastExpectedSales = 1250000.0;

  void _onLogin(UserProfile user) {
    setState(() {
      _currentUser = user;
      if (user.role == UserRole.attendant) {
        _currentView = AppView.attendantHome;
      } else if (user.role == UserRole.cashier) {
        _currentView = AppView.verifySubmission;
      } else if (user.role == UserRole.manager) {
        _currentView = AppView.managerDashboard;
      } else {
        _currentView = AppView.creditCustomers;
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
    return Scaffold(
      body: _buildCurrentScreen(),
      // Quick Prototype Screen Switcher for interactive review
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScreenSwitcherDialog,
        backgroundColor: AppColors.ink,
        icon: const Icon(Icons.layers, color: Colors.white, size: 20),
        label: Text(
          'View: ${_viewName(_currentView)}',
          style: const TextStyle(color: Colors.white, fontSize: 13),
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
          user: _currentUser,
          onLogout: _logout,
          onOpenClosingReadings: () => setState(() => _currentView = AppView.closingReadings),
          onOpenRemittance: () => setState(() => _currentView = AppView.remittance),
        );

      case AppView.closingReadings:
        return ClosingReadingsScreen(
          onBack: () => setState(() => _currentView = AppView.attendantHome),
          onSubmitSuccess: (totalSales) {
            setState(() {
              _lastExpectedSales = totalSales > 0 ? totalSales : 1250000.0;
              _currentView = AppView.remittance;
            });
          },
        );

      case AppView.remittance:
        return RemittanceScreen(
          expectedSalesValue: _lastExpectedSales,
          onBack: () => setState(() => _currentView = AppView.attendantHome),
          onSubmitSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.ok,
                content: Text('Remittance submitted to cashier verification queue.'),
              ),
            );
            setState(() => _currentView = AppView.attendantHome);
          },
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

      case AppView.managerDashboard:
        return ManagerDashboardScreen(
          onOpenVerificationQueue: () => setState(() => _currentView = AppView.verifySubmission),
          onOpenCashCount: () => setState(() => _currentView = AppView.dailyCashCount),
          onOpenCreditCustomers: () => setState(() => _currentView = AppView.creditCustomers),
          onLogout: _logout,
        );

      case AppView.creditCustomers:
        return CreditCustomersScreen(
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
      case AppView.verifySubmission:
        return '09 Verify Submission';
      case AppView.dailyCashCount:
        return '10 Cash Count';
      case AppView.managerDashboard:
        return '17 Manager Dashboard';
      case AppView.creditCustomers:
        return '21 Credit Customers';
    }
  }

  void _showScreenSwitcherDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Switch Screen (Prototype Explorer)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
              ),
              const Divider(color: AppColors.line),
              ...AppView.values.map((v) {
                final isSelected = v == _currentView;
                return ListTile(
                  title: Text(
                    _viewName(v),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.ok : AppColors.ink,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: AppColors.ok) : null,
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
  }
}
