# Production configuration and release gates

## Implemented

The app no longer embeds a Supabase project URL or client key. Missing configuration disables initialization with an explicit sign-in message. Only HTTPS endpoints and publishable/anon keys are accepted; this is a key-type check, not a connectivity or cryptographic verification. Never put a service-role or secret key in an APK or web bundle.

Expense limits and categories now come from the singleton `operational_policy` record. The app has no Dart fallback for these rules. Missing or invalid policy blocks new expenses; the most recently loaded policy remains in memory, but there is no persistent policy cache for a cold offline start. This client policy is not an authorization boundary: server enforcement is still required.

Deposit confirmation/discrepancy actions leave the local record unchanged when backend persistence fails. Evidence uses durable `storage://bucket/path` references and temporary signed links at viewing time. Queued tokens resolve to the same object after upload. Same-origin legacy storage URLs are recognized; foreign URLs and traversal references are rejected. Expense, company-report, deposit and remittance viewers share the resolver. Uploads no longer create orphan remittance-evidence rows. Delivery waybill references are retained; review/apply the delivery-evidence migration in staging before using the new runtime payload. Private bucket policies and end-to-end retrieval still require backend implementation/acceptance. Fuel-delivery and deposit drafts require confirmation before leaving.

Outbox items carry their originating profile, authenticated principal and station. Replay requires an exact owner match and freezes the JWT for the dispatched operation. Session/station changes invalidate further dispatches; restored interrupted items keep their ownership and become retryable. Expired-token failures can retry during periodic connectivity checks. Ownerless legacy items and PIN-only sessions without a real Auth principal remain held, not deleted or reassigned. These require trusted reconciliation; never attach them automatically to the next user. This is deliberately fail-closed while the Auth migration is outstanding. Offline data-at-rest protection and real-backend reconciliation remain release requirements.

## Configuration steps (not performed against a live project)

1. Review and apply `supabase/migrations/20261013_operational_policy.sql` using a trusted database administrator. Its initial values preserve the former rules (cashier 10,000, manager 50,000); confirm these are approved company policy before use. It does not insert sample transactions or replace an existing policy record. Anonymous/authenticated clients receive read-only policy access.
2. Provision genuine stations, profiles, tanks, nozzles and prices. Do not reuse demo credentials or master PINs.
3. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the GitHub `production` environment. Add `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. Require human reviewers on that environment in GitHub settings. Builds are manually requested after checks pass; pushes no longer publish public APK releases. Client publishable keys are embedded in artifacts and are not a replacement for database security.
4. For local builds, supply both values explicitly:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR-PUBLISHABLE-KEY
flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR-PUBLISHABLE-KEY
```

The Flutter web target and Vercel build configuration are added; see `WEB_DEPLOYMENT.md`. Compilation and local browser setup/sign-in rendering were checked without a live backend. Vercel deployment was not performed. Do not deploy the legacy bootstrap as a production security policy.

### Android signing

Release builds no longer fall back to the Android debug certificate. Local builds require `ANDROID_KEYSTORE_PATH` (absolute path), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` in their environment. Debug builds do not require these settings. Keep the existing production signing identity if devices already depend on it; changing the certificate affects in-place updates. Back up the key securely. Keystores and `key.properties` are ignored by Git.

Codemagic uses the `ajadico-production` environment group instead of embedded backend values. Configure the same backend and signing settings there. Supply an existing keystore at `ANDROID_KEYSTORE_PATH`, or its base64 bytes via `ANDROID_KEYSTORE_BASE64` with an absolute output path. The preparation script refuses to overwrite an existing file. Actual key/password compatibility must be verified by a signed build; preparation alone does not validate a certificate.

### Approved authentication direction — not yet implemented

The approved target is verified email accounts for management and PIN access on enrolled tablets for attendants/cashiers. This authentication target is not implemented. One APK covers both modes. Legacy login creates no Supabase Auth session; the new owner-partitioned outbox therefore holds its entries. Auth sessions, trusted provisioning and restrictive policies must migrate together before public release.

The migration must preserve existing profile UUIDs referenced by financial records, introduce a separate Auth-user mapping, restrict pre-login discovery to a minimal station directory, and prevent staff queues being replayed under another user's session. Tablet enrollment must be revocable and server-verified, not a local device-mode preference. Management unlock must verify an authorized account without leaving a privileged session on a shared tablet.

Implementation/deployment of this boundary is awaiting confirmation of an authorized staging project and its actual schema. The legacy bootstrap removes foreign keys and changes identifier types, while the separate RLS script assumes profile IDs equal Auth IDs. Neither file can safely be used unchanged as the production authorization migration. Local Docker/PostgreSQL validation was unavailable because the Docker daemon was not running.

## Required before public release

- Replace custom profile/PIN checks with authenticated sessions and securely provisioned credentials; remove legacy plaintext PIN storage/verification.
- Enforce role, station, approval limits and financial state transitions on the server. Restrict the legacy anonymous write grants.
- Make evidence storage private and verify authorized retrieval, offline uploads and reconciliation.
- Verify expense approvals/rejections, delivery evidence, shift isolation, outbox recovery, reconciliation and push delivery against a staging backend.
- Complete real-device, accessibility and populated-workflow acceptance checks, and backup/recovery procedures. Phone overflow fixes and semantic dark-mode colours were applied to the audited forms and shared tank gauge. Widget checks cover all 19 screens at tablet/phone sizes, including 320px and 1.3 text scale. These do not replace actual-device acceptance. Release signing still needs the genuine key and an Android build host.

## Local implementation surfaces

- Ownership/replay: `lib/core/offline/sync_queue_item.dart`, `offline_sync_service.dart`, repository session snapshots and state session/station binding.
- Evidence: `lib/core/storage/evidence_reference.dart`, `camera_compression_service.dart`, `evidence_photo_picker.dart`, `evidence_preview_dialog.dart`, company/manager/deposit/remittance viewers and delivery references.
- Guardrails: expense approval/rejection limit checks, director-only credit-account creation and honest action feedback.
- UX: manager/attendant phone actions, verification evidence sizing, cash/setup wrapping, semantic colours in cash/remittance/delivery/dip/setup, shared tank-gauge readability and fresh dip input.
- Web: `web/`, `vercel.json`, `scripts/build_web.sh`, `.github/workflows/build-web.yml`. Hosting preparation follows the [Flutter](https://docs.flutter.dev/deployment/web) and [Vercel](https://vercel.com/docs/builds/configure-a-build) documentation.
- Tests: `test/session_and_evidence_test.dart`, expanded `workspace_ux_test.dart`, policy/neutral-startup checks and `scripts/test_release_config.py`.

No live migration or deployment was performed. Static analysis and widget tests do not certify backend security or production readiness.
