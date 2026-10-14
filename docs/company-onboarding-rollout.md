# Company onboarding — database deployed, account activation pending

Applied to gasstation main production on 2026-10-14, in the same transaction as
named pumps. See `production-migration-20261014-named-pumps.md`. Both existing
management profiles remain unlinked; this deployment did not provision accounts.

This release targets one company per Supabase deployment. It does not provide
multi-tenant isolation for several customer companies sharing one database.

## Local implementation

- Personal-device management sign-in requests an email code for existing accounts
  only (`shouldCreateUser: false`). Verification establishes a real Auth session;
  the server supplies the active management profile and station assignment.
- Management unlock verifies email in an isolated client and cannot replace the
  attendant's session. PIN-based management unlock has been removed.
- Sign-out detaches the outbox immediately and blocks navigation until local Auth
  cleanup finishes. Cleanup failure shows a retry control instead of the workspace.
- The plaintext PIN-comparison fallback has been removed. A legacy PIN RPC success
  without a matching authenticated staff session is rejected. Staff directory loads
  no longer select PIN hashes. This deliberately blocks the existing anonymous
  staff login until the enrolled-tablet/session-issuance backend is completed.
- Company Setup shows server-confirmed company details, approval-policy state,
  station count and unlinked management count. It never asserts production readiness.
- Director sign-in opens a seven-step APK-first guide, resuming at the first
  missing server-confirmed configuration item. Managers/station staff do not enter
  this company guide. Directors can reopen it from Company onboarding navigation.
- Company web URL is optional (NULL when blank); company setup and entered-email
  OTP do not require a deployed website. Saved progress is not device-local.
- Station registration uses a verified-director RPC. Configuration, staff account
  linking, device enrollment and live readiness remain distinct states. The guide
  lets directors open management while setup stays pending; it has no fake go-live
  or enrollment-complete control. Until the outstanding services are deployed,
  director sign-in continues to resume unfinished setup.
- `20261015_company_onboarding.sql` adds a unique `profiles.auth_user_id` mapping,
  sanitized current-profile RPC, mapping-write guard, company configuration and
  status RPCs. It updates the four previously deployed operational RPCs and two
  policy read rules to use the mapped profile ID, preserving all business IDs.

## Deployment gates

1. The user approved deployment and the migration is now applied in production.
   A rollback-only rehearsal passed before the atomic deployment. Installed
   function actor lookups passed the migration's compatibility checks. This was
   not a separate staging test and does not replace authenticated release testing.
2. Configure reliable email delivery and server-side rate limits. No web URL is
   required for entered-code APK sign-in. Web URL/allowed redirect configuration
   can be added later for browser access or link-based login; never use a dummy
   deployed URL to get through setup.
   For the email-code flow, the Magic Link email template must display
   `{{ .Token }}`; do not use a link-only template. Disable public sign-ups in the
   Auth service too: the client flag alone does not disable the public API.
3. In trusted backend administration, provision the user-authorized first director
   Auth email account and link it to the company-approved existing director profile.
   Email confirmation must come from the user's code verification, not a UI checkbox.
   Use the existing-account OTP flow rather than requiring an invitation-link web
   redirect. Never bundle the service-role key, send default passwords, or infer a
   director role from user-editable Auth metadata.
4. Select the actual existing director profile by its UUID and verify its identity
   with the company owner. Link its `auth_user_id` to the provisioned Auth UUID using
   trusted administration. Require exactly one active profile and the intended,
   unbanned Auth user; privileged RPCs require email confirmation before use. Do not rewrite `profiles.id` or
   automatically match records by display name. This is a privileged activation
   step, not an exposed client RPC.
5. Director verifies email and signs in, saves company details and the actual
   approval limits/categories in Setup. No values are pre-seeded.
6. Invite/link remaining management users, then implement/deploy trusted station
   tablet enrollment and PIN-to-Auth session issuance with revocation, secure
   credential storage, PIN hashing and server rate limiting. Device-mode preferences
   are presentation settings, NOT proof of enrollment. The existing staff PIN
   flow does not establish an Auth session; it cannot use the protected ledger RPCs.
7. Remove legacy anonymous business-table and public storage access after replacing
   their client workflows with role/station-scoped APIs. Protect direct profile role,
   station, active-state and salary writes as well as the new Auth mapping. The new
   migration alone does not close those legacy permissions.
8. Verify opening meters, physical dips, book stock, prices and balances. Run a
   complete real-device shift: cash drops, credit/POS, expense approvals, final
   handover, cashier reconciliation, director reporting and offline retry isolation.

Invitations/device enrollment do not yet have an in-app provisioning service. The
manual administrator activation above is not a substitute for that remaining work.

## Required tests before release

- Unknown email never creates an account; expired/reused/wrong codes are rejected.
- Unlinked, inactive, unconfirmed or banned management cannot enter the workspace.
- Inactive/unassigned stations cannot admit managers; directors retain company scope.
- Anonymous callers cannot invoke onboarding RPCs or read company configuration.
- Staff cannot assign their own Auth UUID or escalate their role through legacy APIs.
- Managers cannot configure company policy; concurrent policy edits retain revisions.
- Management unlock never changes the active attendant/outbox identity and a manager
  from another station cannot unlock this tablet.
- Logout, session expiry and account switching do not dispatch another user's outbox.
- Native widget/visual tests remain blocked by Windows Application Control. Do not
  bypass that restriction or treat static analysis as proof of rendered behavior.

`test/onboarding_preview.dart` is a debug-only layout QA entrypoint using test-only
status data; release execution is explicitly rejected. It is not an APK release
target, production data source, provisioning service or proof of live authentication.

Email-code implementation reference: https://supabase.com/docs/guides/auth/auth-email-passwordless
