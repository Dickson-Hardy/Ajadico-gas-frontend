# AJADICO — Operations, implementation status and release readiness

Date: 14 October 2026  
Company requested by the owner: AJADICO NIGERIA LIMITED  
Product: Flutter filling-station operations app with Supabase/PostgreSQL backend  
Assessment type: source inspection and previously recorded deployment/test evidence; not a fresh security audit or real-device acceptance test.

## 1. Executive answer: where we stand

**Current tracked delivery-evidence score: 50% — 48 of 96 checkpoints evidenced.**

This is the explicit overall tracking number for the 24 capability groups in section 3. It is not a claim that half the code remains, a probability that the software works, a time-to-finish estimate, or permission to begin live trading.

| Measure | Explicit result | Meaning |
| --- | --- | --- |
| UI/application-code presence | 87.5% — 21/24 capability groups | Substantial screens or application logic exist. This does not mean each workflow is correct or complete. |
| Persistence-path presence | 87.5% — 21/24 | Repository/outbox/RPC paths exist in source. Legacy paths can still be unsafe or incomplete. |
| Targeted production-backend evidence | 25% — 6/24 | Applicable new objects were deployed and narrowly checked. This is not authorized-user workflow acceptance. |
| Full current workflow acceptance | 0% — 0/24 credited | No capability is credited with a complete current-build, real-account, real-device acceptance run. This is an evidence gap, not proof every workflow fails. |
| Combined delivery evidence | **50% — 48/96** | Equal-weight total of those four checkpoints. |
| Mandatory release gates | **10% — 1/10 closed** | The migration gate is closed; nine other gates are open or unverified. |
| Go-live decision | **NO-GO for unrestricted production operations** | Critical authentication, financial correctness, authorization and release-verification work remains. |

The product is substantially beyond a screen-only demo: it has linked workflows, persistence paths, offline ownership rules and deployed operational migrations. It is **not yet a production-certified station system**.

A migration deployment and an APK release are different deliverables. The new database work is deployed; a fresh backend-configured APK has not been built or installed in this work.

## 2. Scope, evidence and limits

This report uses the current Dart source, SQL migrations, rollout documents and recorded checks. It makes no new production writes.

Confirmed deployment target: Supabase project gasstation, main PRODUCTION, project reference haeakygzrnrjwphmhlkp.

Latest recorded database verification, earlier on 14 October:

- 3 dispensing points and 4 staff profiles were retained.
- No missing parent-station links or duplicate legacy pump numbers were found.
- 0 staff profiles were linked to Supabase Auth.
- 2 active management profiles were unlinked.
- Company/onboarding and named-pump migrations were committed atomically.
- Existing-field comparisons passed for pumps, profiles, credit sales, shift adjustments and shift meter assignments.
- Anonymous create/rename execution was denied; no-session create/rename calls rejected.
- New company and pump-history tables had RLS enabled.
- No company details, approval policy values, sample pumps or financial transactions were seeded by those deployments.

These are dated observations, not a fresh database inventory. Existing records have not been certified as real operational data just because they were preserved.

Evidence precedence: current source and deployment records take priority over older README wording, prepared-only SQL comments, earlier screenshots and historical UX findings. Some older documents still say no migration was deployed; that statement is superseded by the production deployment records.

### What “backend stuff in the APK” actually means

The APK can carry the HTTPS backend endpoint and publishable/anon client key. The remote database, server functions, RLS policies, Auth service and storage remain hosted on Supabase. A local APK does not contain a self-hosted production backend.

A service-role key, database password, private signing key or backend admin credential must never be bundled. No deployed web URL is required for APK-first onboarding and entered-email-code sign-in.

## 3. Percentage method and capability matrix

Each group has four binary evidence checkpoints:

- **C — Client:** substantial UI/application logic is present in the current source.
- **P — Persistence:** a corresponding repository, outbox or RPC path exists in source.
- **D — Deployment evidence:** relevant new production objects and narrow checks are recorded. Existing table availability alone is not enough.
- **A — Acceptance:** the current complete workflow has passed documented authorized-user/device acceptance.

1 = evidenced; 0 = absent, incomplete or not evidenced. A zero does not distinguish those cases; the workflow notes below do.

These checkpoints measure evidence coverage, not equally valuable business outcomes. C/P credit is deliberately narrow: it does **not** certify security, transaction atomicity, accounting correctness or server permission coverage. A deployed function that rejects unsigned callers is not evidence of a successful director sign-in.

| # | Capability | C | P | D | A | Score |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Company onboarding | 1 | 1 | 1 | 0 | 3/4 — 75% |
| 2 | Management email authentication | 1 | 1 | 1 | 0 | 3/4 — 75% |
| 3 | Enrolled-tablet staff authentication | 0 | 0 | 0 | 0 | 0/4 — 0% |
| 4 | Station registration | 1 | 1 | 1 | 0 | 3/4 — 75% |
| 5 | Tank configuration | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 6 | Named pumps and permanent identity | 1 | 1 | 1 | 0 | 3/4 — 75% |
| 7 | Staff administration | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 8 | Durable open-shift recovery | 0 | 0 | 0 | 0 | 0/4 — 0% |
| 9 | Opening/closing meter readings | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 10 | Interim cash submissions | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 11 | POS and bank-transfer recording | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 12 | Credit sales and repayments | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 13 | Pump expenses and non-sale fuel | 1 | 1 | 1 | 0 | 3/4 — 75% |
| 14 | Final remittance and stock snapshot | 1 | 1 | 1 | 0 | 3/4 — 75% |
| 15 | Cashier verification | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 16 | Physical cash counting | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 17 | Branch/cash-drawer expenses | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 18 | Dips, deliveries and changeovers | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 19 | Price authorization | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 20 | Bank deposit workflow | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 21 | Shortages and payroll ledger | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 22 | Management reports and export | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 23 | Offline queue and evidence | 1 | 1 | 0 | 0 | 2/4 — 50% |
| 24 | Current configured APK/device delivery | 0 | 0 | 0 | 0 | 0/4 — 0% |
| | **Totals** | **21/24** | **21/24** | **6/24** | **0/24** | **48/96 = 50%** |

The 24 groups are an explicit working checklist, not an exhaustive contractual BRD traceability audit. Multiple-company SaaS isolation, billing and native PDF printing are outside the currently demonstrated feature baseline; they must be added to scope before calculating a percentage for those products.

## 4. Product structure and access

One APK is intended to serve both device modes:

1. Personal-device management mode: managers/directors use verified email accounts.
2. Shared station tablet mode: attendants/cashiers use PIN access backed by trusted enrollment and real Auth sessions.

The device-mode preference is presentation state, not proof of enrollment.

| Role | Intended daily responsibilities | Current navigation/code position |
| --- | --- | --- |
| Attendant | Meter readings, cash submissions, POS/transfer, credit, pump expenses, non-sale fuel, final handover | My Shift hub plus linked entry screens exist. |
| Cashier | Confirm cash received, verify submissions, count physical cash, branch expenses, customer credit access | Screens and state/repository paths exist; complete secure staff login remains blocked. |
| Manager | Station dashboard, review exceptions, tank dips, deliveries, cashier oversight, staff records | Station-oriented navigation exists; actual Auth account linking remains pending. |
| Director | Company oversight, setup, prices, approval policy, deposits, salary ledger and staff governance | Director UI and new protected configuration RPCs exist. |
| Trusted backend administrator | Initial account provisioning/linking, device/session infrastructure and deployment | Still required; these tasks are not replaced by the onboarding wizard. |

Client-side hidden buttons and role menus are not server authorization. Every protected read/write still needs server-side role/station enforcement.

## 5. Company onboarding: full walkthrough

### Step 0 — Trusted activation before first successful use

An administrator must identify the approved existing director profile, provision the intended Auth account if needed, and explicitly link its Auth UUID without changing the existing profile UUID. The director must verify the email through the real sign-in flow.

Current position: mapping schema and verified-profile resolution are deployed; account activation is not complete. No universal director account or fallback PIN should be used.

### Step 1 — Company details

The director enters the registered company name. A company web URL is optional and can remain blank. Saving uses the company-workspace RPC.

Current position: screen, validation, persistence and deployed server function exist. The migration did not automatically save AJADICO NIGERIA LIMITED as a company record.

### Step 2 — Approval policy

The director sets cashier/manager approval ceilings and real expense categories. Policy changes have revision/audit handling.

The owner previously suggested ₦10,000 for cashiers and ₦50,000 for managers, then requested these come from Setup. Treat those as values to confirm and save, **not hardcoded or migration-seeded live policy**.

Current position: policy UI/RPC/table deployed. Operational policy configuration still needs confirmation through a verified director account.

### Step 3 — Stations

Register each actual station with its code, name and relevant contact/location details. The database assigns a permanent station UUID; station code and display name are separate identifiers.

Existing stations must be reviewed and reused rather than blindly recreated.

Current position: station registration UI and director RPC exist and were deployed. Full authorized create/retry/duplicate tests remain pending.

### Step 4 — Tanks, pumps, prices and opening values

For each station:

1. Create the actual tanks with their products and capacities.
2. Independently establish book stock and physical dip.
3. Create dispensing points with custom names.
4. Choose each point’s product and supplying tank.
5. Enter the real opening cumulative meter reading.
6. Configure current selling prices.
7. Review interlocked-tank/manifold arrangements where applicable.

Pump examples such as Pump1a, Pump1b and Diesel Left are names, not code-defined equipment. Each point has a permanent UUID. Renaming preserves that UUID and linked records. Case-insensitive name uniqueness is station-specific.

Current position: named-pump creation/rename RPCs, immutable identity validation, unique index and name audit are deployed. Creation/rename require server confirmation; offline input must not fabricate saved equipment.

Remaining: authorized director create/rename, concurrent creation, duplicate rejection, Unicode/long names, cross-station restrictions and retry recovery must be exercised.

Caution: tank creation currently uses its initial stock value for both local book stock and local physical dip. That is not an independent measured dip or a completed opening-stock audit.

### Step 5 — People and account access

Managers/directors can maintain staff records according to the UI’s role restrictions. Each person needs the intended role and station assignment; salary/surety fields are separate business data.

**Creating a profile is not activating login.** The profile must be securely provisioned and linked to Auth, and a staff PIN must be handled by a trusted service.

Current position: staff forms and legacy persistence exist. The legacy create/reset paths still write PIN input directly into a field named pin_hash; this is not secure password hashing. Trusted provisioning and server permission protection are release blockers.

### Step 6 — Station tablets

Enroll an authorized station device, bind it to a station, issue/revoke trusted device credentials, and establish a real staff Auth session after PIN verification.

Current position: **not complete**. The onboarding capability intentionally reports tablet authentication unavailable. A local “station tablet” selection is not enrollment.

### Step 7 — Readiness review

Check opening balances, prices, staff access, physical stock, policy, evidence, device enrollment and shift acceptance. Saved configuration does not automatically authorize live operations.

Current position: guide/resume UI exists. Final readiness is intentionally not inferred as complete from record counts. Directors can reach management while setup remains pending; that is not go-live approval.

## 6. Pump attendant: one shift in one place

The My Shift screen follows the notebook model requested by the owner:

### 6.1 Readings and sales

Show configured pumps, opening readings, opening confirmation and closing readings. The related closing-reading form records cumulative meter values.

For each pump:

- Litres dispensed = closing cumulative reading − opening cumulative reading.
- Gross metered value = litres dispensed × the applicable price snapshot.

Current position: calculations, configured names, UUID-backed persistence changes and UI exist. Durable shift recovery, equipment assignment and authorized real-device readings need acceptance.

### 6.2 Cash submissions during the shift

Each interim hand-in is recorded separately, with amount, time and notes/recipient context as supported by the form. The hub lists each submission and distinguishes awaiting cashier confirmation from acknowledged cash.

These are instalments already handed over, not the final cash remaining.

Current position: entry, acknowledgement models and persistence exist. Confirm no duplicate cash receipt after retries, shift verification, app restart or second-device acknowledgement.

### 6.3 POS, terminal transfers and bank transfers

Record channel, amount, reference and terminal/bank details required by the selected option. Keep cash and electronic payments separate.

Current position: forms/models/repository paths exist. This is **recording**, not demonstrated payment-gateway settlement, bank reconciliation or automatic confirmation that a transfer arrived.

### 6.4 Credit sales

Select an authorized customer, the relevant pump, litres/value, vehicle/driver details and signed requisition evidence.

Credit counts toward explaining the shift’s sales but is not cash handed to the cashier.

Current position: entry and customer ledger paths exist; new payloads carry station, shift and permanent pump IDs. Credit records can snapshot the pump name.

Blocker: saving a credit sale and increasing the customer balance are currently separate operations, with the balance increase treated as best-effort. A saved sale can therefore outlive a failed balance update. Atomic posting/reconciliation needs implementation and testing before relying on balances.

### 6.5 Pump expenses

Enter cash actually spent from that attendant’s sales: configured category, reason, amount and evidence. Entries start pending and require review.

Only approved expenses affect shift accounting. These are not automatically a second withdrawal from the cashier’s safe.

Current position: entry, approval ledger and protected server rules are implemented/deployed. Authorized approval/limit escalation and expense-versus-safe treatment need acceptance.

### 6.6 Non-sale fuel

Record the actual type separately:

- Calibration return: metered fuel returned to stock under review rules.
- Generator fuel: internal consumption; AGO restriction applies.
- Company-vehicle fuel: internal use, not customer cash sales.

Capture litres, pump/tank context, reason and evidence. Approved value reduces collectible sales. Calibration returns alone restore tank book stock through the reviewed path; estimated transactions must never invent physical dip readings.

Current position: UI, adjustment rules and migration exist. Authorized approvals, duplicate review protection and stock math need live verification.

### 6.7 Final cash handover

Enter only the remaining physical cash handed to the cashier at shift end. Do not re-enter earlier cash submissions.

The screen requires closing readings and blocks finalization while earlier submissions or adjustments remain unresolved under current UI rules.

Current position: the hub and final-remittance path exist. Receipt/acknowledgement on the cashier’s separate device and durable server state still need testing.

### 6.8 Shift reconciliation

Business equation:

    Collectible sales = gross metered value − approved non-sale-fuel value

    Accounted value = acknowledged earlier cash submissions
                    + final cash handed over
                    + electronic payments
                    + credit sales
                    + approved pump expenses

    Variance = accounted value − collectible sales

Negative variance indicates an amount still unexplained/short; positive variance is an excess requiring review. Do not confuse a cash shortage with stock variance or customer credit.

Illustrative arithmetic only — not seeded app data:

- 1,000 litres × ₦1,200 = ₦1,200,000 gross.
- Earlier submissions ₦100,000 + ₦500,000 + ₦300,000 + ₦200,000 + ₦90,000 = ₦1,190,000.
- Final handover ₦10,000 gives ₦1,200,000 accounted, assuming no other payments/adjustments.

The photo’s cumulative meter labels/order must be independently checked. The example does not authorize reversing opening/closing values.

## 7. Cashier operations

### 7.1 Receive interim cash

Confirm actual cash received, not just the attendant’s declaration. Keep acknowledgement state attached to the original shift and actor.

Remaining: concurrent acknowledgements, unauthorized access and retry-safe accounting must be tested.

### 7.2 Verify final submissions

Review meters, expected sales, payment breakdown, credit, approved expenses/non-sale fuel, evidence and final handover. Record review notes; verify or flag unresolved according to available actions.

Remaining: server-enforced reviewer authority, transaction consistency and multi-device state transitions need acceptance. A local “Verified” label is not sufficient evidence.

### 7.3 Count physical cash

Enter actual denomination counts. Compare counted cash against opening cash plus recognized receipts, less eligible cash expenses and bank handovers.

Remaining: establish the opening safe balance from a trusted close/open process. Test daily/date/shift scope and pending-expense policy. Current cash-expense totals include non-rejected cash expenses, including pending entries; the company must approve that rule.

### 7.4 Record bank handover

Capture amount, bank/teller/reference context, proof and handover details. Keep “handed for deposit” distinct from “confirmed by bank/director”.

Current position: deposit recording and confirmation/discrepancy UI exist; some confirmation paths await persistence before local success.

Remaining: finance authorization, receipt access, duplicate prevention and final safe/bank reconciliation.

## 8. Manager operations

### 8.1 Station overview

See the selected station’s sales/cash/stock context, pending reviews and operational alerts. Use role-grouped navigation rather than numbered demo-screen switching.

Remaining: make sure loaded data scope, date range and server authorization match every aggregate.

### 8.2 Tank dip audit

Enter a genuinely new physical dip observation, operator/time and applicable context. Compare it with book stock.

Book stock is calculated inventory; physical dip is a measured observation. Their difference is a variance to investigate, not a reason to silently overwrite one with the other.

### 8.3 Fuel reception

Record supplier, product/tank, waybill, measured delivered quantity and real purchase-cost information. Keep discrepancies/evidence explicit.

Remaining: delivery-evidence schema rollout must be verified; the standalone delivery-evidence migration is not credited as deployed here. Test atomic stock posting, capacity limits and duplicate deliveries.

### 8.4 Tank changeover

Capture source/destination, switching readings, optional dips and notes. Pump IDs now identify switch readings.

Remaining: the repository inserts an audit event and then updates pump routing through multiple calls. Partial failure can leave an audit or only some points updated. Move the complete changeover to an atomic reviewed server operation.

### 8.5 Branch expenses and review

Record the expense’s source of funds; distinguish safe/branch expenditure from the attendant’s pump expense ledger. Use evidence and the configured authorization policy.

Remaining: legacy branch-expense paths are not automatically secured by the newer shift-adjustment RPC migration.

### 8.6 Staff oversight

Maintain permitted station staff details and status. A manager should not gain director scope, reassign themselves or change protected salary/access fields through a direct API.

Current position: forms exist; trusted provisioning and complete server-side role/station protection remain required.

## 9. Director and central operations

### 9.1 Company/station setup

Configure actual company, branches, infrastructure and approval policy. Pump names are database records, not in-code enumerations.

### 9.2 Price authorization

Capture the new price and reason, preserving the price applicable to recorded shift sales.

Remaining: test effective-time handling, an in-progress shift, offline retries, unauthorized calls and repeated submissions. Current source paths do not establish complete pricing acceptance.

### 9.3 Credit customers and repayments

Authorize customers, inspect outstanding balances, record repayments and maintain customer status/limits as supported.

Remaining: balances must reconcile atomically to sales/repayment records. Credit approval and repayment are not bank settlement integrations.

### 9.4 Bank deposit approval

Review bank proof and handover details. Confirm receipt or flag discrepancy only after persistence.

Remaining: cross-station access, duplicate confirmations, evidence policy and safe/bank totals.

### 9.5 Shortages, salary adjustments and payroll

Review recorded shortages; apply the available approve/waive actions and salary ledger/monthly settlement workflow.

Remaining: prevent duplicate payroll deductions, unauthorized edits and race conditions. This is an internal ledger workflow, not a demonstrated bank-payroll disbursement system or statutory payroll engine.

### 9.6 Company performance

View loaded financial/stock records and expense reviews.

Current UI correctly warns that profit is unavailable until delivery costs and remaining inventory are reconciled. Loaded/date-filtered totals are not a complete consolidated accounting statement.

Remaining: authoritative all-station aggregation, costing method, reconciliation, report boundaries and company naming consistency. Do not advertise a certified P&L.

## 10. Reports, evidence and exports

| Output | Available position | Remaining validation |
| --- | --- | --- |
| My Shift ledger | Readings, cash submissions, other payments/credit, expenses/non-sale fuel, final handover | Restart continuity and second-device agreement |
| Pump/meter sales | Calculated litres/value; configured name and UUID | Immutable assignment and price snapshots |
| Cashier verification | Submission list, breakdown and review actions | Authoritative server transitions |
| Safe cash report | Opening/receipts/expenses/deposits/count/variance calculations | Correct IDs, scope and no double-counting |
| Tank reconciliation | Capacity, dip, book stock, variance and ullage | Independent observations and atomic postings |
| Customer credit | Sales/repayments/outstanding model | Atomic balance reconciliation |
| Salary ledger | Shortage/adjustment/settlement views | Approval, retry and payroll acceptance |
| Company overview | Loaded-record financial and tank views | Complete consolidation and costing |
| Shift audit summary | Text and CSV generation with pump UUID/name | Scope, branding and full export acceptance |

Current export actions copy formatted text or CSV to the clipboard. They are **not** demonstrated native PDF generation, file download, OS share or physical printing.

Pump-name CSV cells are quoted and formula-escaped by the current helper. That is not a complete audit of every exported field.

Evidence references use durable storage references and authorized temporary URLs where implemented. Viewing UI exists. Private storage policies, role/station ownership, expiry, uploads, second-device access and offline recovery still require acceptance.

Notifications have application/source paths, but end-to-end FCM delivery and operational alerting are not credited as complete.

## 11. Offline, session and recovery behaviour

Implemented source protections include:

- Outbox items carry profile, Auth principal and station ownership.
- Replay requires the current session to match the original owner.
- In-flight requests use a frozen session snapshot.
- Session/station changes prevent further dispatch under the wrong owner.
- Failed writes remain queued rather than silently becoming successful.
- Ownerless legacy records are held rather than assigned to a new user.
- New structural pump configuration requires online server confirmation.
- Unresolved legacy payloads are held when identity is ambiguous.

Important limits:

1. The outbox uses SharedPreferences; encrypted sensitive local storage and recovery controls are not established.
2. Having a queue does not prove every write is idempotent or atomic.
3. Durable server-backed open-shift resume is incomplete. A new login must not accidentally create a new shift instead of restoring the legitimate one.
4. Shift type is still derived in code from the device clock before/after 14:00; configurable station shift schedules and cross-midnight handling are not demonstrated.
5. Offline cash/stock accounting and concurrent devices require deliberate reconciliation tests.
6. Evidence upload failure must not leave a financial item looking fully supported/verified.
7. Never delete held legacy queues to make the sync indicator green.

## 12. Concrete code findings requiring follow-up

These are source observations and risks, not a completed exploit/security audit. No fixes were applied while writing this report.

| Priority | Observation | Business consequence | Required follow-up |
| --- | --- | --- | --- |
| P0 | Profile create/reset writes raw PIN input to pin_hash | PIN confidentiality and trusted credential provisioning are not solved | Replace with trusted salted-hash provisioning/verification, rate limits and Auth session issuance |
| P0 | Management profiles remain unlinked at last recorded check | Verified users cannot complete the intended authorized setup | Identify approved profiles and explicitly provision/link accounts |
| P0 | Trusted tablet enrollment/session service is unavailable | Staff PIN mode cannot meet the approved security boundary | Implement enrollment, revocation, station binding and secure session lifecycle |
| P0 | Existing broad legacy APIs/storage are not covered by new migrations | Client menus cannot protect business records | Review and enforce role/station policies and private evidence ownership |
| P1 | Credit sale insert and balance increment are separate; increment failure is swallowed | Customer outstanding can disagree with sales | Atomic transaction or authoritative derived ledger plus reconciliation |
| P1 | Changeover audit and pump updates are multiple calls | Partial route changes can diverge from audit | Single validated transaction/RPC |
| P1 | totalUnverifiedInterimDrops builds its verified set from submission id, then compares drop.shiftId | Different identities appear to be compared; possible cash double-counting | Confirm with regression case and use the canonical shift identity consistently |
| P1 | createShift has a fixed offline SHIFT-LOCAL-01 return | Legacy path can provide a non-unique placeholder identity | Trace active callers; remove/reconcile before release, never treat it as a real server shift |
| P1 | createStaffProfile returns a constructed profile when disconnected | A caller can mistake an unsaved profile for persisted onboarding | Return an explicit pending/failure result or trusted queued workflow |
| P1 | Tank creation locally assigns initial book stock as physical dip | Measurement and calculated stock become indistinguishable | Capture/verify independent opening observations |
| P1 | Safe-expense aggregation includes pending, non-rejected cash expenses | The company’s “paid versus approved” rule can alter expected safe cash | Define the approved policy and test all transitions |
| P2 | Shift timing is hardcoded to the device hour threshold | Wrong shift grouping near time/date boundaries | Station-configured schedule and server-consistent timestamps |
| P2 | Report header still contains AJADICO ENERGY LIMITED | Does not consistently use requested registered-company identity | Load approved workspace branding/name |
| P2 | Legacy numeric point keys remain in local forms | UUID migration is not the removal of all numeric compatibility paths | Preserve explicit station scoping and test all old payloads |
| P2 | Older docs and snapshots overstate or predate current state | Users can confuse an old design or build with latest deployment | Keep release records and superseded notes clear |

The fixed offline shift placeholder and residual brand strings mean “all in-code demo/placeholder data has been removed” is too strong. Startup collections are neutral and there is no intended hardcoded pump catalog, but cleanup is not universally complete.

## 13. APK and web delivery status

### Android

- Current source supports an APK with runtime backend services hosted remotely.
- Public backend settings must be supplied at build time.
- Release signing is guarded against a silent debug-certificate fallback.
- Signing variables were absent in the latest local environment check.
- The previously configured temporary Flutter/Android paths are incomplete.
- Another Flutter installation was found at C:/Users/NEWUSER/AppData/Local/flutter; its doctor output identified Flutter 3.47.7. Android toolchain discovery/build was not completed before the task was interrupted.
- A separate ADB/platform-tools directory exists; ADB alone is not an Android compiler/build SDK.
- No new APK was built, installed or accepted in the interrupted local-build attempt.

Existing artifacts observed locally:

| Artifact | Last-write date | Interpretation |
| --- | --- | --- |
| AjadicoEnergy-v1.0.0-demo-removed.apk | 7 October 2026 | Historical artifact, not this implementation |
| AjadicoEnergy-v1.0.0-release.apk | 7 October 2026 | Historical artifact, not this implementation |
| build/app/outputs/flutter-apk/app-release.apk | 10 October 2026 | Predates the 14 October onboarding/named-pump changes |

Never relabel these older APKs as the newest release. A local testing APK and a production-signed release must be clearly distinguished. Installing on an existing device also requires checking signing identity, update compatibility and data preservation.

### Web

Flutter web code and Vercel build configuration exist. A prior release web compilation passed, but without production backend defines it was a compilation check, not a configured production deployment. No public deployed application URL has been confirmed.

The screenshot gallery on localhost is an image viewer, not the live operational app or its backend.

## 14. Test and evidence ledger

| Evidence | Recorded result | What it does not prove |
| --- | --- | --- |
| Dart analysis from the implementation pass | No issues found | Correct finance/security or all-device behaviour |
| Named-pump pure checks | 22 passed | Live authorized pump creation/rename |
| Shift-adjustment math checks | 8 passed | Full transaction/review/stock acceptance |
| Flutter web release build | Passed | Configured Android APK or live login |
| Browser pump preview | List/form rendered, including phone layout | Further interactions timed out; no successful live save credited |
| Native Flutter widget tests | Added; runner blocked by Windows Application Control in that pass | A written test is not a passing test |
| Migration rollback rehearsal | Passed on production within a transaction | Separate staging or successful authorized-user operation |
| Migration preservation assertions | Passed | Correctness of all subsequent transactions |
| Post-commit SQL checks | New objects, RLS and narrow deny checks confirmed | Every legacy table/API secured |
| Screenshot archive | 198 captures, 150 byte-unique | 198 test passes or 150 current screen implementations |

No platform security policy was disabled to run tests. This report does not rerun the entire suite or invent a coverage percentage.

## 15. Ten mandatory release gates

A gate is closed only when its acceptance evidence is available. Unknown/unverified counts as open.

| # | Gate | Current result |
| --- | --- | --- |
| 1 | Required onboarding, policy, shift-adjustment and named-pump migrations deployed with narrow verification | **CLOSED** for those four migrations; delivery-evidence compatibility still belongs to workflow validation |
| 2 | Verified director and manager accounts linked; OTP delivery/session/revocation accepted | OPEN |
| 3 | Trusted enrolled-tablet staff PIN-to-Auth service accepted | OPEN |
| 4 | Real company policy, infrastructure, prices and opening balances approved | OPEN / not confirmed complete |
| 5 | All legacy financial/profile APIs and evidence storage enforce roles/stations | OPEN |
| 6 | Complete financial/stock shift cycle, concurrency, retry and reconciliation accepted | OPEN |
| 7 | Offline restart, ownership, evidence recovery and local-data protection accepted | OPEN |
| 8 | Current Android/device UX, accessibility and populated-workflow acceptance passed | OPEN |
| 9 | Fresh backend-configured, correctly signed APK built, inspected and installed | OPEN |
| 10 | Backup/restore, monitoring, support and release rollback procedures tested | OPEN |

**Gate closure: 1/10 = 10%.** This is a stricter release measure than the 50% delivery-evidence score. Critical gates cannot be averaged away by having attractive screens.

## 16. Single-company deployment versus full SaaS

Current implementation targets **one company per Supabase deployment**, with multiple stations in that company.

It does not demonstrate:

- Secure isolation of unrelated customer companies in a shared database.
- A tenant ID propagated through all business records and policies.
- Self-service organization signup and company ownership verification.
- Subscription billing, plans, seat limits or usage enforcement.
- Tenant provisioning, tenant-specific backups or tenant deletion/export.
- Platform support/admin separation and audited cross-tenant support access.

A dedicated AJADICO deployment can be a valid first product. It must not be sold as a proven shared multi-company SaaS without additional architecture, implementation and tests. Multi-station management is not the same as multi-tenant SaaS.

No completion percentage is assigned to those extra SaaS features because they are not included in the 24-group baseline. Adding them would change the denominator and reduce the overall delivery percentage.

## 17. Completion sequence

### Phase A — Access and safe activation

1. Identify the intended existing director profile and approve the Auth mapping.
2. Provision/link the authorized director; verify OTP delivery and successful/denied sign-ins.
3. Configure real company details and setup-driven approval limits/categories.
4. Implement secure staff provisioning and enrolled-tablet authentication.
5. Replace legacy profile/PIN writes and enforce server-side role/station access.
6. Keep the service-role key strictly server-side.

Exit: each role enters only its authorized workspace; wrong station, inactive, banned and unlinked accounts are denied.

### Phase B — Financial and shift correctness

1. Implement durable open-shift recovery and stable equipment assignments.
2. Resolve the interim-drop versus submission/shift identity comparison.
3. Make credit sales/repayments and balances atomic/reconcilable.
4. Make changeovers and relevant inventory postings atomic.
5. Verify evidence/delivery compatibility and opening-stock measurement separation.
6. Validate all receipts, expenses, deposits and payroll rules with the owner.

Exit: two devices and retries produce one agreed financial/stock result.

### Phase C — Acceptance and release

1. Run automated tests in an approved environment.
2. Complete a controlled real-account shift: opening, readings, drops, POS, credit, expense, internal fuel, final cash, verification, safe count and deposit.
3. Repeat with offline interruption, restart, account switch and concurrent review.
4. Verify reports against hand-calculated control totals and correct company naming.
5. Restore the Android toolchain and use the intended signing identity.
6. Build a fresh configured APK; inspect client settings and absence of server secrets.
7. Install on authorized test devices and complete acceptance.
8. Verify backup/restore, monitoring, update and rollback procedures.
9. Approve the controlled pilot before public rollout.

A pilot has to be explicitly approved with known limitations; it is not a workaround for missing authentication or unsafe financial posting.

## 18. Source and deployment references

Relative links below resolve from this Markdown document.

- [Onboarding screen](../lib/features/onboarding/company_setup_screen.dart)
- [App role navigation](../lib/features/shell/app_shell.dart)
- [Attendant My Shift](../lib/features/attendant/attendant_home_screen.dart)
- [Pump editor](../lib/core/widgets/pump_editor_dialog.dart)
- [Shared state, calculations and shift lifecycle](../lib/state/station_app_state.dart)
- [Repository, PIN writes, credit posting and changeovers](../lib/core/network/supabase_repository.dart)
- [Offline queue](../lib/core/offline/offline_sync_service.dart)
- [Shift adjustment rules](../lib/models/shift_adjustment.dart)
- [Shift text/CSV report](../lib/features/reports/shift_summary_export_dialog.dart)
- [Company reports](../lib/features/admin/company_reports_screen.dart)
- [Initial operational migration record](production-migration-20261014.md)
- [Onboarding/named-pump production record](production-migration-20261014-named-pumps.md)
- [Company onboarding rollout](company-onboarding-rollout.md)
- [Named-pump rollout](named-pumps-rollout.md)
- [Shift-adjustment rollout](shift-adjustments-rollout.md)
- [Android signing guard](../android/app/build.gradle)
- [Build-configuration validation](../scripts/validate_build_config.py)
- [Release-configuration tests](../scripts/test_release_config.py)

## 19. Bottom line

**For the current declared 24-group baseline: 50% of delivery-evidence checkpoints are met, 87.5% have substantial client/persistence surfaces, and only 10% of the mandatory go-live gates are closed.**

The remaining work is concentrated in secure account/device activation, transactional correctness, recovery, server authorization and real-device release acceptance—not simply additional screen styling.

