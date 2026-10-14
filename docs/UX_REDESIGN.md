# Dart operations workspace

This pass upgrades the existing Flutter interface while retaining its operational state methods, repository calls and role workflows. It does not replace the app with HTML prototypes or seed demonstration data into the application.

## What changed

- Persistent, role-specific navigation grouped into overview, daily operations, accounts, fuel/stock and administration. Large screens use a sidebar; smaller screens use a drawer. The numbered screen switcher and simulated-connectivity control are no longer in the operational navigation.
- Station context, notification access, queue status/retry, appearance control and sign-out are visible in the workspace. Navigation and station changes check unsubmitted work before leaving.
- Shared light/dark component styling, compact buttons, quieter status labels, readable tables and financial figures. Light mode is the default; appearance can still be changed. Standard platform fonts replace runtime font fetching in the shared typography and logo.
- Financial overview uses real loaded submissions/expenses, date filtering, source-record tables, expense review and a stock-reconciliation table. Profit is unavailable until actual inventory costing is implemented; no assumed margin is used.
- Staff management uses a search/filter toolbar and compact directory, with responsive mobile rows and an expandable profile. Existing onboarding, PIN reset, salary and access actions remain available.
- Deposit review uses status filters, search, a register and confirm/flag/slip actions. Awaiting and flagged deposits are separated in the visible summaries.
- Manager sales/reconciliation presentation and sign-in were redesigned. Other Dart screens inherit the common styling and clearer copy; phone overflow fixes cover retail-price controls and customer accounts.

## Validation

`flutter analyze --no-pub` checks the full project.

`flutter test --no-pub --no-test-assets test/workspace_ux_test.dart` checks all 19 screen layouts at tablet (1024 × 900) and phone (390 × 844) sizes, including scrolling to form actions. It also checks desktop/mobile navigation, staff-search clearing, deposit filters, sign-out callbacks, larger text on financial overview, dark rendering and the real shell's keep/discard-unsaved-work flow.

The local Windows Application Control policy blocks Flutter's shader compiler during test-asset generation. The supported `--no-test-assets` option allows these asset-independent widget tests to run without invoking that executable. The tests load Flutter's bundled fonts, use in-process fixtures and mocked preferences, and never initialize a Supabase connection.

Optional Dart-rendered PNG captures can be generated with:

```powershell
flutter test --no-pub --no-test-assets --dart-define=UX_CAPTURE_DIR=C:/absolute/output/directory test/workspace_ux_test.dart
```

Those captures contain test fixtures, not deployed station data. There is no authentication bypass or fixture initialization in the application entry point.

## Remaining release work

The baseline's previously documented accounting, stock movement, branch/shift isolation and persistence gaps remain. Device camera, real authentication, deployed Supabase reads/writes and APK installation still need end-to-end acceptance testing before a production release. This UX pass does not certify the existing backend or financial calculations.
