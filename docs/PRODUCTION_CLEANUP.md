# Production data cleanup

Application startup is signed out with no station, staff, tank, nozzle, bank account or retail price invented in code. Master PINs and the built-in director login have been removed. Both sign-in paths and management lockout recovery require an active registered profile and online PIN verification.

Retail prices come from the latest configured database prices. Delivery purchase costs and bank/teller details require actual input. Profit is unavailable until delivery costs and remaining inventory are reconciled. Failed or unavailable persistence no longer reports success or discards the outbox item as completed.

The obsolete HTML demonstration screens were removed. Database scripts no longer create sample stations, staff, credentials, customers, tanks or prices. Canonical PMS/AGO product definitions remain. Test fixtures are isolated under test/ and never initialize a live Supabase connection.

No deployed database records were deleted, and no schema or edge function was deployed. Existing sample records in a live database require a separately reviewed migration, including transaction dependencies.

## Setup and release requirements

The configuration hardening follow-up removes embedded backend credentials and moves expense limits/categories into a database-managed policy. See [configuration and remaining release gates](PRODUCTION_CONFIGURATION.md). No migration has been applied to a live database.

Provision the first genuine station and management profile through a trusted administrative process. There is no universal fallback account or default PIN. Configure tanks, nozzles, retail prices, storage and notification credentials for the deployment.

This cleanup is not a production certification. The current bootstrap still grants broad database access, and PIN provisioning/verification includes legacy plaintext handling. Server-enforced role/station policies, secure credential provisioning, storage access, financial reconciliation, shift isolation and real-device/offline acceptance testing must be completed before release. Push dispatch configuration was made honest; delivery with the existing FCM integration still needs verification.

## Checks

- flutter analyze --no-pub
- flutter test --no-pub --no-test-assets test/

The widget tests cover all 19 screens at tablet and phone sizes, navigation and unsaved-work protection. Production-data regression checks cover neutral startup, no fallback credentials/prices/station, honest offline write results, correct local-deposit context, outbox retention and session clearing.
