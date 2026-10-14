# Production migration record — 2026-10-14

Target: `gasstation`, `main (PRODUCTION)`, project `haeakygzrnrjwphmhlkp`.
Applied through the authenticated Supabase SQL Editor after explicit user approval.
The two migration bodies were executed together in one transaction, with a single
commit, a five-second lock timeout and a sixty-second statement timeout.

## Applied files

- `supabase/migrations/20261013_operational_policy.sql`
- `supabase/migrations/20261014_shift_adjustments.sql`

Supabase reported `Success. No rows returned`. A fresh verification query then
confirmed the database objects and permissions; this was not inferred from the
local files or an attempted execution.

## Verification

- Policy, policy audit and shift adjustment tables exist and contain zero rows.
  No limits, categories or example business transactions were seeded.
- Row-level security is enabled on all three tables.
- Anonymous SELECT is denied on all three tables.
- Authenticated direct INSERT/UPDATE/DELETE is denied on all three tables.
- Anonymous execution is denied on policy configuration, entry submission and
  adjustment review RPCs. Authenticated execution is available, with role and
  station checks inside the RPCs.
- Invocations without an authenticated identity were tested and rejected with
  the expected errors: `Verified director required`, `Authenticated attendant
  required`, and `Authorized reviewer and notes required`. No records were written.
- The generated remittance variance expression includes approved pump expenses.
- Both adjustment-snapshot and metered-stock triggers are installed.
- Four active staff profiles remain present; zero are linked to Auth user IDs.

## Remaining release gates

Complete verified staff-account linkage and trusted-tablet authentication.
Then configure company limits/categories using director Setup, and test real
authorized approvals, limit escalation, cross-station isolation, retries,
concurrent submissions, stock arithmetic and second-device reporting in staging.
Deployment of these objects does not secure every legacy table/API or complete
the existing PIN-to-Auth transition.

New client Setup and ledger screens must be released separately. Native visual
tests remain blocked by Windows Application Control; no policy was bypassed.
No staff IDs were remapped, no business records were deleted, and no credentials
were stored in this record.
