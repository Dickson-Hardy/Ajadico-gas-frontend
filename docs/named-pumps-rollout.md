# Named pumps — database deployed, release verification pending

Applied to gasstation main production on 2026-10-14, together with company
onboarding in one transaction. See `production-migration-20261014-named-pumps.md`.
The required live-device and authenticated workflow tests below remain pending.

Admins enter an arbitrary 1–80 character dispensing-point name in Station Setup,
also reached from APK onboarding. Name, product, supplying tank and actual opening
meter are saved through a verified-director RPC. A generated equipment UUID is
stable; renaming never changes it, the station, legacy number or transaction FKs.
There is no hardcoded pump catalog. Hint examples and QA fixtures are not records.

## Deploy in order after review

1. The previously applied operational policy and shift adjustment migrations.
2. `20261015_company_onboarding.sql` (applied; account activation still pending).
3. `20261016_named_pumps.sql` (applied; do not rerun this one-time migration).

The naming migration follows the inspected live schema: dispensing points are in
`nozzles`, linked through `pumps.station_id`. It adds a validated station identity,
case-insensitive station/name uniqueness, creation/rename RPCs and protected name
history. Existing IDs, numbers, meter readings and financial amounts are retained.
Legacy names are initially derived from their actual numeric records (`PumpN`),
then editable by the director. It fails rather than silently renumbering duplicated
legacy numbers within a station. Review/repair those records first if found.

New readings, credit sales and changeover maps use equipment UUIDs. An old numeric
reading payload can resolve only against its explicit station and only one matching
row. Pump1a/Pump1b are never parsed as numeric identities. Historic adjustment and
credit names are snapshots; rename history is audited. CSV name cells are quoted
and spreadsheet-formula escaped by the existing exporter.

Structural configuration must be online and server-confirmed. Failed creation or
rename retains the editor draft and does not fabricate a saved pump. Retry creation
uses the same UUID. Legacy queued creations retain their UUID/number and replay
through the new RPC only if unambiguous. Older credit payloads without shift/station
identity remain held for review, not silently written to a guessed point.

## Required staging verification

- Same name twice in one station rejects; the same name in two stations succeeds.
- Pump1a/Pump1b, Unicode, spaces/punctuation and case-only renames work as intended.
- Empty/control-character/overlength names and invalid opening meters reject.
- Wrong station/product/tank combinations reject; anonymous/managers cannot create
  or rename equipment through the director RPCs.
- Renaming leaves UUID, prior readings, credit records, adjustment snapshots and
  stock untouched. Name history records the verified actor.
- Concurrent creation allocates unique legacy keys; retries don't duplicate pumps.
- Report names/CSV cells are safe; long names work on mobile and with larger text.
- Offline replay respects original actor/station ownership and holds ambiguity.

Static analysis/pure Dart checks and debug-browser UI QA do not prove live database
permissions or APK execution. Native widget tests remain blocked by Windows
Application Control. The debug-only `test/pump_names_preview.dart` is never a release
entrypoint. Existing provisioning/tablet/legacy API hardening gates still apply.
