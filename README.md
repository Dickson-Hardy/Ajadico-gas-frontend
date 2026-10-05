# Ajadico Filling Station Management System (Frontend & Supabase Schema)

Cross-platform Flutter application for retail fuel station operations and multi-branch management. Built in accordance with **BRD Version 3 (1 October 2026)**.

---

## 🚀 Key Modules & Screen Mapping

| Screen ID | Operational Workflow | Flutter Implementation | BRD Ref |
| :--- | :--- | :--- | :--- |
| **01** | **Shared Tablet PIN Login** | [`lib/features/auth/login_screen.dart`](lib/features/auth/login_screen.dart) | §2.1 – §2.4 |
| **02** | **Attendant Shift Home** | [`lib/features/attendant/attendant_home_screen.dart`](lib/features/attendant/attendant_home_screen.dart) | §2.2, §2.6 |
| **04** | **Closing Meter Readings** | [`lib/features/attendant/closing_readings_screen.dart`](lib/features/attendant/closing_readings_screen.dart) | §2.5, §2.10 |
| **05** | **Shift Remittance & Proof** | [`lib/features/attendant/remittance_screen.dart`](lib/features/attendant/remittance_screen.dart) | §4.1 – §4.7 |
| **09** | **Cashier Verification Queue**| [`lib/features/cashier/verify_submission_screen.dart`](lib/features/cashier/verify_submission_screen.dart) | §4.2 – §4.4 |
| **10** | **Daily Physical Cash Count** | [`lib/features/cashier/daily_cash_count_screen.dart`](lib/features/cashier/daily_cash_count_screen.dart) | §5.3 – §5.5 |
| **17** | **Branch Manager Dashboard** | [`lib/features/manager/manager_dashboard_screen.dart`](lib/features/manager/manager_dashboard_screen.dart) | §6.1, §6.2 |
| **21** | **Credit Customer Ledger** | [`lib/features/credit/credit_customers_screen.dart`](lib/features/credit/credit_customers_screen.dart) | §4.8 – §4.10 |

---

## 🗄️ Supabase / PostgreSQL Database Schema

The complete backend database schema, constraints, indexes, RPCs, and seed test data are located in:  
📁 [`supabase/schema.sql`](supabase/schema.sql)

### Core Schema Highlights:
- **`stations`**: Multi-branch support with interlocked tank flags.
- **`fuel_products` & `fuel_prices`**: Versioned pricing per branch authorized by Senior.
- **`tanks`, `pumps`, `nozzles`**: Strict physical mappings with automated carry-forward meter readings.
- **`shifts` & `shift_nozzle_assignments`**: Automated stored calculation of $\text{Litres Sold}$ and $\text{Expected Sales Value}$.
- **`remittances`**: 4-way split (Cash, POS Card, POS Transfer, Bank Transfer) + Credit tracking with strict variance attribution.
- **`daily_cash_counts`**: Note breakdown (₦1000 to ₦10) and cash-at-hand formula with pending bank confirmation flags.
- **`attendant_salary_adjustments`**: Discrepancy audit log feeding payroll deductions.
- **`attendant_pin_login(...)`**: PostgreSQL RPC function verifying 6-digit PIN on shared tablets.

---

## 💻 Running the Flutter Application

1. **Get dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run in Chrome (Web Preview):**
   ```bash
   flutter run -d chrome
   ```

3. **Run on Android Tablet / Device:**
   ```bash
   flutter run -d android
   ```

4. **Interactive Screen Switcher:**
   Tap the floating **"View: [Screen]"** button at the bottom-right of the screen to quickly navigate between all prototype screens and test role workflows.
