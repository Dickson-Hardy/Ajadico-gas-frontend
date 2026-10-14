# Shift-linked expenses and non-sale fuel

Implemented entry and review UI, pending ledger/outbox recovery, and snapshot
accounting. The policy and adjustment migrations were applied to gasstation main
production on 2026-10-14. See `production-migration-20261014.md` for verification.

- Pump expenses represent money spent from attendant sales cash, not a second
  withdrawal from the cashier safe. Approved amounts are added to accounted-for
  value; they are not counted as cash received by the cashier.
- Approved calibration returns, generator fuel and company-vehicle fuel are
  removed from collectible metered sales. Generator fuel requires an AGO nozzle.
- Calibration returns alone restore tank **book stock**, through the review RPC.
  Actual physical dip is never increased by an estimated transaction.
- Remittance snapshots apply metered book-stock deductions as atomic deltas;
  do not deploy the new client without the corresponding migration.
- All entries start pending, require evidence and review notes, prohibit
  self-approval, and follow the configured cashier/manager approval limits.
- The policy migration seeds no amounts or categories. A verified director
  configures the company policy in Station & Forecourt Setup. Until that is
  saved, expense approvals remain unavailable. Policy revisions are audited,
  and stale concurrent edits are rejected by the server.
- New reviews fail closed offline or without a verified Supabase Auth principal.
  Legacy PIN-only sessions cannot use these RPCs. Complete authenticated account
  and trusted-tablet enrollment before rollout.
- Old fuel-return outbox records lack type, shift and review metadata and are
  deliberately held. Review/re-enter them; do not bulk-publish as verified.

## Required staging verification

Review `supabase/migrations/20261014_shift_adjustments.sql` against the actual
schema first. It requires compatible `shifts`, `remittances`, `tanks`, `profiles`,
`stations`, `fuel_products` and `operational_policy` tables. Profiles must map
to authenticated user IDs; this migration does not create that mapping or secure
all legacy APIs/tables.

Test create/retry, cross-station denial, anonymous denial, self-approval denial,
limit escalation, evidence access, concurrent review, review-after-remittance
denial, stock restoration/deduction retry, and snapshots on a second device.
Restart an attendant session and verify open-shift resume/outbox visibility;
the existing login lifecycle still needs a durable server-backed shift-resume
flow. Policy configuration remains empty until saved by a verified director in
Setup. At deployment, none of the four active staff profiles was linked to Auth;
complete verified-account linkage before exercising live operational workflows.

Windows Application Control blocked the Flutter test runner during this pass.
Widget tests were added but must be run in an approved environment before release.
No security policy was disabled or bypassed.
