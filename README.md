# Ajadico Filling Station Management System

Flutter application and Supabase / PostgreSQL backend for retail fuel station operations and multi-branch management, based on **BRD Version 3 (1 October 2026)**. Production deployment still requires the checks in [release readiness](docs/PRODUCTION_CLEANUP.md).

---

## 📱 Current Screen & Workflow Matrix (19 Screens)

The current Dart screens cover the operational workflows below. See [UX redesign and validation notes](docs/UX_REDESIGN.md) and [one-APK login experience](docs/LOGIN_EXPERIENCE.md) for the workspace changes and remaining release checks.

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
| **23** | **Tank & Nozzle Configuration** | [`lib/features/admin/station_setup_screen.dart`](lib/features/admin/station_setup_screen.dart) | Director | Station infrastructure |
| **24** | **Staff Profiles & Access** | [`lib/features/admin/staff_management_screen.dart`](lib/features/admin/staff_management_screen.dart) | Manager / Director | Staff administration |

---

## 🗄️ Supabase / PostgreSQL Database Schema

The backend database schema, constraints, indexes and RPCs are located in:
📁 [`supabase/schema.sql`](supabase/schema.sql)

---

## 💻 Running the Flutter Application

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run on a configured device:**
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR-PUBLISHABLE-KEY
   ```

   See [production configuration and release gates](docs/PRODUCTION_CONFIGURATION.md) for migrations and build secrets, and [web hosting preparation](docs/WEB_DEPLOYMENT.md) for the added Flutter web target and Vercel configuration. Public release remains gated on backend authentication and permission migration.

3. **Operational workspace:**
   Sign in to open your role's workspace. Use the grouped sidebar on large screens or the navigation drawer on smaller devices. The header provides station context, notifications, queue status and appearance controls. Unsubmitted work is checked before changing pages or stations.
