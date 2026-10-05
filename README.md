# Ajadico Filling Station Management System

Cross-platform Flutter application and Supabase / PostgreSQL production schema for retail fuel station operations and multi-branch management. Built strictly to **BRD Version 3 (1 October 2026)**.

---

## 📱 Complete Screen & Workflow Matrix (17 Screens)

The codebase implements all operational workflows from pump island to central boardroom:

| Screen # | Operational Workflow | Flutter Implementation | User Role | BRD Clause |
| :---: | :--- | :--- | :--- | :--- |
| **01** | **Shared Tablet PIN Login** | [`lib/features/auth/login_screen.dart`](lib/features/auth/login_screen.dart) | Attendant / Cashier | §2.1 – §2.4 |
| **02** | **Attendant Shift Home** | [`lib/features/attendant/attendant_home_screen.dart`](lib/features/attendant/attendant_home_screen.dart) | Attendant | §2.2, §2.6 |
| **04** | **Closing Meter Readings** | [`lib/features/attendant/closing_readings_screen.dart`](lib/features/attendant/closing_readings_screen.dart) | Attendant | §2.5, §2.10 |
| **05** | **Shift Remittance & Proof** | [`lib/features/attendant/remittance_screen.dart`](lib/features/attendant/remittance_screen.dart) | Attendant | §4.1 – §4.7 |
| **06** | **Pump Credit Sale Entry** | [`lib/features/attendant/credit_sale_screen.dart`](lib/features/attendant/credit_sale_screen.dart) | Attendant | §4.8 – §4.10 |
| **07** | **Calibration & Fuel Returns** | [`lib/features/attendant/fuel_return_screen.dart`](lib/features/attendant/fuel_return_screen.dart) | Attendant / Manager | §3.4, §3.5 |
| **09** | **Cashier Verification Queue**| [`lib/features/cashier/verify_submission_screen.dart`](lib/features/cashier/verify_submission_screen.dart) | Cashier / Manager | §4.2 – §4.4 |
| **10** | **Daily Physical Cash Count** | [`lib/features/cashier/daily_cash_count_screen.dart`](lib/features/cashier/daily_cash_count_screen.dart) | Cashier | §5.3 – §5.5 |
| **11** | **Record Branch Expense** | [`lib/features/manager/expense_entry_screen.dart`](lib/features/manager/expense_entry_screen.dart) | Cashier / Manager | §5.1, §5.2 |
| **12** | **Daily Tank Dip Audit** | [`lib/features/manager/tank_dip_screen.dart`](lib/features/manager/tank_dip_screen.dart) | Branch Manager | §3.2, §3.3 |
| **13** | **Fuel Delivery Reception** | [`lib/features/manager/fuel_delivery_screen.dart`](lib/features/manager/fuel_delivery_screen.dart) | Branch Manager | §3.7 – §3.9 |
| **17** | **Branch Manager Dashboard** | [`lib/features/manager/manager_dashboard_screen.dart`](lib/features/manager/manager_dashboard_screen.dart) | Branch Manager | §6.1, §6.2 |
| **18** | **Price Authorization & Snapshot** | [`lib/features/admin/price_change_screen.dart`](lib/features/admin/price_change_screen.dart) | Senior (Central) | §2.8, §2.9 |
| **19** | **Attendant Salary Deductions** | [`lib/features/admin/attendant_salary_ledger_screen.dart`](lib/features/admin/attendant_salary_ledger_screen.dart) | Senior (Central) | §4.6, §4.7 |
| **20** | **Bank Deposit Approvals** | [`lib/features/admin/bank_deposit_verification_screen.dart`](lib/features/admin/bank_deposit_verification_screen.dart) | Senior (Central) | §4.3, §5.5 |
| **21** | **Credit Customer Ledger** | [`lib/features/credit/credit_customers_screen.dart`](lib/features/credit/credit_customers_screen.dart) | Manager / Senior | §4.8 – §4.10 |
| **22** | **Company Consolidated P&L** | [`lib/features/admin/company_reports_screen.dart`](lib/features/admin/company_reports_screen.dart) | Senior & Directors | §6.1, §6.4 |

---

## 🗄️ Supabase / PostgreSQL Database Schema

The complete backend database schema, constraints, indexes, RPCs, and seed test data are located in:  
📁 [`supabase/schema.sql`](supabase/schema.sql)

---

## 💻 Running the Flutter Application

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run in Web / Desktop / Mobile:**
   ```bash
   flutter run -d chrome
   ```

3. **Interactive Screen Switcher:**
   Tap the floating **"View: [Screen]"** button at the bottom right to open the interactive sheet and navigate between any of the 17 screens across all roles.
