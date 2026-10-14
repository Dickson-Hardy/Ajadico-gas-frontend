# Remaining UX review — 13 October 2026

Follow-up: local changes now address confirmation feedback, shared evidence viewing, delivery/deposit draft protection, audited phone overflows, dark-mode forms/gauge colours, previous-versus-fresh dip input, empty-delivery status and credit-creation role affordances. The original audit evidence is retained below. Backend authorization, private storage and real-device acceptance are not verified; see `PRODUCTION_CONFIGURATION.md` for current gates.

## Verdict

The current application has a stronger foundation than the old demo, but the remaining experience is not yet at the same standard as the new login. The admin workspace and list structure are more coherent; operational forms still mix older screen framing, colours, long instructions and crowded fixed action bars.

The next pass should prioritise trust and usability before cosmetic restyling: readable dark mode, responsive primary actions, correct queued/confirmed feedback, actual evidence viewing and draft protection. No application code was changed during this review.

## Scope and evidence limits

Fresh native Flutter renders of the 18 non-login screens were captured at 1024×900 and 390×844, including form bottoms. Selected screens were also captured in dark mode and at 130% text size. The real manager shell and drawer were navigated locally, and deposit confirmation plus receipt viewing were exercised using test-only records.

No Supabase connection was initialized. Fixtures exist only in the audit process; no live records, approvals or messages were changed. These are local UI/state results, not deployed-device acceptance. Existing Windows shader restrictions were left unchanged; the supported asset-independent Flutter test renderer was used, not a browser or installed Android app.

Some labels without an explicit font family fall back to the test renderer's Ahem font and appear as blocks. Those glyph artifacts are excluded from the findings. Main body/controls use Flutter's bundled Roboto fonts. The test root's debug banner was disabled for accepted captures.

Staff profile editing with a populated directory, physical camera capture, real storage retrieval, payroll settlement, live network recovery and manifold changeover completion were not end-to-end tested. Screenshots do not certify contrast ratios, TalkBack support or WCAG compliance.

## Numbered screen/workflow review

| Step | Surface | Health and highest-value next change | Fresh evidence |
| --- | --- | --- | --- |
| 1 | Role workspace/navigation | Clear grouped drawer; duplicated page/shell headers and many icons consume phone space. Make the shell own navigation and page identity. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/09-manager-navigation-phone.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/08-manager-shell-phone.png) |
| 2 | Attendant home | Operational shortcuts exist, but dense cards and narrow bottom actions split words. Keep one clear next-shift action and a compact summary. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-attendant-390-top.png) |
| 3 | Closing readings | Logical meter → litres → expected sales flow. Improve summary-label width, unit consistency and shared header treatment. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-readings-390-top.png) |
| 4 | Remittance | Payment categories are explicit; long vertical layout and dark contrast need work. Add a clear review of declared totals/difference and proof requirements. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-remittance-390-top.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/dark-remittance-phone.png) |
| 5 | Pump credit sale | Useful customer/nozzle/vehicle context and required-proof gating. Standardise form sections and queued-versus-uploaded evidence. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-credit-sale-390-top.png) |
| 6 | Fuel return/non-sale | Purpose and proof are reasonably clear; long option labels truncate. Improve selection labels and shared form styling. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-fuel-return-390-top.png) |
| 7 | Cashier verification | Structured checks are useful, but the fixed flag action breaks into tiny fragments on phones and overflows with larger text. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-verification-390-bottom.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/large-text-verification-phone-middle.png) |
| 8 | Daily cash count | Denomination entry, expected cash and variance are understandable. Essential reconciliation is far below the first view; dark headings/totals become unreadable. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-cash-390-bottom.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/dark-cash-phone.png) |
| 9 | Bank handover dialog | Required real bank/reference/photo input is better than seeded accounts. The narrow long modal cramps its submit label; close/dismiss does not protect the draft. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/dialog-deposit-phone-bottom.png) |
| 10 | Deposit approvals | Clear filters/register, but large summary blocks dominate mobile. More importantly, failed offline confirmation produces a confirmed record. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-deposits-390-top.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/probe-deposit-offline-confirmed-record.png) |
| 11 | Manager dashboard | The summary is useful on a tablet; duplicated metrics, overloaded header and broken footer weaken phone use. Prioritise pending tasks and exceptions. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-manager-1024-top.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/08-manager-shell-phone.png) |
| 12 | Tank dip audit | Measured-versus-book stock is visible. Existing readings are prefilled as new audit input; show previous values separately and require an explicit fresh measurement/reuse decision. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-dip-390-top.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/dark-dip-phone.png) |
| 13 | Fuel delivery | Required supplier, waybill, dips and purchase cost are present. Drafts are unprotected; an untouched form declares an exact match; evidence linkage is incomplete. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-delivery-390-bottom.png) |
| 14 | Expense entry/review | Category, payment source and approval rules are exposed. Actual receipt review is missing and attachment references need correction. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-expense-390-top.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/probe-manager-receipt-placeholder.png) |
| 15 | Customer credit ledger | Search/outstanding total are useful; horizontal phone tables hide repayment controls. Add-customer availability contradicts the director-only note. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-customers-390-top.png) |
| 16 | Financial overview | Honest unavailable-profit state and source tables are strengths. Reduce phone summary height and keep branch/loaded-record scope unmistakable. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-overview-390-top.png) |
| 17 | Salary/differences ledger | Clear differences/payroll split. Empty-state text overstates that all shifts balanced when it only knows no loaded adjustments. Populated payroll still needs acceptance. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-payroll-390-top.png) |
| 18 | Station setup | Tanks/nozzles are grouped sensibly. Larger-text rows overflow, dark surfaces clash and copy still claims fixed branch counts. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/large-text-configuration-phone-middle.png) / [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/dark-configuration-phone.png) |
| 19 | Staff directory | One of the more consistent surfaces: search, role/station filters and add action. Only the empty-directory state was rendered; populated profile/PIN/salary actions were not accepted end-to-end. | [capture](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/screen-staff-390-top.png) |

### 1. Phone action bars are not production-ready — high priority

Manager buttons split “Verify queue” and “Bank deposit” into fragments even at default text size. Verification's flag button becomes almost one letter wide. On personal phones, the global header plus page toolbar makes the manager title nearly disappear.

At 130% text, the audit reproduced manager dashboard horizontal overflow of 74px, verification footer bottom overflow of 8px and station setup horizontal overflow of 6.5px. The pending-expense fixture exposed two more manager rows overflowing by approximately 1.3px and 8.2px.

Recommendation: one primary action in each phone footer, secondary actions in a readable overflow menu or wrapping/full-width layout. Remove duplicate shell/page chrome; make title/status rows wrap or flex rather than clipping the business context.

Sources: [manager summary row](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/manager_dashboard_screen.dart:387), [manager action bar](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/manager_dashboard_screen.dart:820).

![Manager dashboard at larger text: clipped heading and fragmented actions](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/large-text-manager-phone-middle.png)

### 2. Dark mode needs a complete semantic-colour pass — high priority

Cash audit, remittance, delivery, dip audit and setup use dark text on dark surfaces. Delivery also has white input backgrounds with nearly invisible selected values. This is not just styling preference: financial totals, labels and required fields become hard to read.

Recommendation: replace page-level hardcoded light colours with shared surface/on-surface/error/outline tokens across headings, inputs, tables, dialogs and footers. Verify populated and disabled states, not only the background.

![Cash-count dark mode: headings and financial values lose contrast](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/dark-cash-phone.png)

### 3. Confirmation feedback contradicts the record — high priority

Reproduced locally: confirm an awaiting deposit while the repository is disconnected. The UI says “Failed to confirm deposit. Please retry.”, but the record moves to Confirmed and the confirmed amount increases. The state method mutates confirmation fields and posts a success notification regardless of the repository result.

Recommendation: distinguish server-confirmed, accepted locally/pending sync and failed. Do not present one operation as both failed and complete. Retrying must not create an ambiguous second business action.

Sources: [confirmation state mutation](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/state/station_app_state.dart:1662), [failed action feedback](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/admin/bank_deposit_verification_screen.dart:116).

![Offline confirmation: Confirmed record and a failure message at the same time](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/probe-deposit-offline-confirmed-record.png)

### 4. Evidence review is incomplete — high priority

The manager's “View Receipt Proof” always shows a static box saying “Receipt Photo Attached”; it never renders the receipt. Expense/deposit submission passes the image filename rather than its remote storage URL, while the deposit viewer uses Image.network. Fuel-delivery submission does not pass the selected waybill photos into its record method.

Recommendation: use a stable evidence reference tied to the business record, display actual local/remote images, and show queued/uploading/uploaded/unavailable states. Preserve queued references through sync instead of pretending a filename is a retrievable URL. The actual upload/linking pipeline needs service/device acceptance.

Sources: [receipt placeholder](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/manager_dashboard_screen.dart:107), [expense attachment](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/expense_entry_screen.dart:120), [deposit attachment](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/cashier/bank_deposit_dialog.dart:129), [deposit image loader](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/admin/bank_deposit_verification_screen.dart:173), [delivery submission](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/fuel_delivery_screen.dart:153).

![Receipt-review action displays a placeholder, not the receipt](C:/Users/NEWUSER/.codex/visualizations/2026/10/13/01a132f9-666e-7490-bc18-095d2c66e98f/remaining-ux-review/probe-manager-receipt-placeholder.png)

### 5. Draft protection is inconsistent — high priority

Typed fuel-delivery fields do not register with ShellBackGuard; the local probe returned false for a non-empty supplier draft. Back actions call onBack directly. Bank handover can close/dismiss after typed input without confirmation. Expense draft detection counts amount/description but not an attachment-only draft.

Recommendation: use one shared draft contract covering text, selectors and evidence, including system back, navigation, sign-out and modal dismissal. Either persist a draft or explain what will be discarded.

Sources: [delivery state](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/fuel_delivery_screen.dart:24), [delivery back](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/fuel_delivery_screen.dart:217), [deposit close](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/cashier/bank_deposit_dialog.dart:231), [expense draft detection](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/expense_entry_screen.dart:49).

### 6. Input/status messaging sometimes implies a completed business check — medium priority

An empty delivery form displays “Matched” / “Exact match with waybill” because both empty measurements evaluate to zero. Tank dip fields begin with the previously stored physical dip. Missing retail prices appear as ₦0 rather than “Not configured”. The price-reason message starts red before the user has attempted submission. Empty payroll text says all shifts balanced rather than no differences recorded in the loaded scope.

Recommendation: represent not-entered, not-configured, loading/unavailable and verified/matched as separate states. Show previous observations with timestamps, not as a silently fresh physical measurement.

Sources: [delivery matched label](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/fuel_delivery_screen.dart:620), [dip prefill](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/tank_dip_screen.dart:76), [price instruction feedback](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/admin/price_change_screen.dart:367).

### 7. Credit accounts need a phone workflow and coherent permissions — medium priority

The table requires horizontal scrolling to reach status/repayment actions without making that path obvious. A manager sees an enabled Add customer button while the page states that only directors authorize new credit customers; the state creation method does not check that role.

Recommendation: phone rows with visible outstanding/status/repayment actions, and a consistent create/request/authorize flow. The UI must reflect the real policy, which also needs server enforcement—not just a hidden button.

Sources: [customer table](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/credit/credit_customers_screen.dart:416), [add customer](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/credit/credit_customers_screen.dart:357), [director-only note](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/credit/credit_customers_screen.dart:490), [creation method](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/state/station_app_state.dart:1978).

### 8. Finish the product language and reporting affordances — medium priority

Manager logout still calls a personal phone a kiosk/shared tablet. Station setup still says “2 of 5 Ajadico branches” and “3 branches”. Several titles are unnecessarily long and disappear behind icon-heavy toolbars. Print/export entry points lead to a dialog whose actions only copy text/CSV to the clipboard; they do not print or save a file.

Recommendation: shared short titles and action vocabulary, real configuration-based copy, and an honest Copy summary action or a genuine download/share/print workflow. Keep financial report scope explicit; a loaded branch subset is not the same as consolidated company reporting.

Sources: [manager logout copy](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/manager/manager_dashboard_screen.dart:63), [fixed branch counts](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/admin/station_setup_screen.dart:613), [clipboard-only report actions](C:/Users/NEWUSER/Documents/antigravity/intelligent-bose/lib/features/reports/shift_summary_export_dialog.dart:561).

## Strengths to preserve

- Role-grouped navigation and station context are substantially clearer than a numbered screen switcher.
- The financial overview does not invent profit or purchase-cost margins.
- Many form pages have working validation, proof gating and clear task sections.
- The core cash-count save flow already distinguishes saved, queued and failed outcomes; reuse that pattern.
- Staff directory and deposit register use search/filter structures suitable for daily operations.
- There is a working draft guard on several important forms; extend it rather than creating another mechanism.

## Recommended sequence

1. Reliability/accessibility: dark tokens, phone action bars, queued/confirmed outcomes, actual evidence viewing and draft guards.
2. Mobile task design: manager exception queue, cashier review steps, shorter forms/review summaries, visible customer repayment actions.
3. Consistency/polish: one page-header/form/footer system, stock visualisations, compact admin summaries, permission-aligned actions, honest empty/configuration states and reporting/share affordances.

Review only: no fixes have been applied. The local audit harness intentionally records known layout failures so it can finish capturing evidence; successful capture completion is not a clean UX test result.
