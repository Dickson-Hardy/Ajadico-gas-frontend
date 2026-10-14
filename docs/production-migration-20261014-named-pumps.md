# Production deployment — onboarding and named pumps

Applied on 2026-10-14 following the user's explicit migration approval.

## Target and execution

- Supabase project: gasstation (`haeakygzrnrjwphmhlkp`), main PRODUCTION.
- Executed using the authenticated Supabase dashboard SQL Editor.
- Query ID: `4bf0c765-759a-4f94-b469-73c7d40d109c`.
- Order: `20261015_company_onboarding.sql`, then `20261016_named_pumps.sql`.
- Removed the files' outer transaction boundaries and ran their bodies in one
  transaction. A rollback-only rehearsal succeeded before the committed run.
- No Supabase CLI migration history table existed at preflight. This was a manual
  SQL deployment, not a CLI push; reconcile migration history before future pushes.
  Do not rerun the named-pump migration: it contains one-time object creation and
  renames the original adjustment function.
- Original source files are retained byte-for-byte (their prepared-only header
  comments describe their authoring state; this deployment record supersedes it).

Source SHA-256 at execution:

| File | SHA-256 |
| --- | --- |
| 20261015_company_onboarding.sql | `5CDBD3292F11219EE1D7C083CA93ACF9BF6AC3AEF3EB93FA80120A7498E02DE9` |
| 20261016_named_pumps.sql | `55B6CD30F0192510A7F5731A7185ACF8E547294F53C847A88E16182F5899417F` |

## Checks performed

- Preflight: 3 dispensing points, 4 profiles, no missing parent stations and no
  duplicated legacy point numbers within a station. Neither migration was installed.
- Temporary before/after JSON snapshots compared existing point fields, profile
  fields, credit sales, shift adjustments and shift meter assignments. Newly added
  metadata columns were excluded. An unexpected difference would abort the entire
  deployment. All comparisons passed; temporary snapshots dropped on commit.
- No-session creation and rename calls rejected with `Verified director required`.
- A separate read-only query after commit confirmed both migrations installed,
  all 3 points having valid station/name metadata, the unique name index and audit
  trigger enabled, RLS enabled on company workspace and pump name history,
  anonymous create/rename execution denied, and the private legacy adjustment
  implementation not executable by the authenticated client role.
- Linked profiles: 0. Unlinked active management profiles: 2. Existing profiles
  matching Auth user UUIDs directly: 0. No accounts or role mappings were created.
- No company values, approval limits, fake pumps, sales or financial records seeded.

## Remaining gates

Authenticated create/rename/duplicate-name/station-isolation and concurrent retry
tests have not been run. The rollback rehearsal was on the production database,
not a separate staging environment. Director account provisioning and explicit
profile linking, email delivery verification, enrolled-tablet authentication,
legacy API/storage hardening and a complete real-device shift remain outstanding.
No signed APK was generated or distributed by this deployment.

The schema is deployed; this is not a declaration of overall production readiness.
Do not undo it by dropping the new columns or changing permanent IDs. Any rollback
must first account for subsequently created pump names, history and linked records.
