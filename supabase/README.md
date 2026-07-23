# NutriLog Supabase infrastructure

This directory contains database infrastructure only. It does not link or
create a Supabase project, add Flutter dependencies, or switch the app away
from its current SQLite repositories.

## Files

- `migrations/202607230001_create_nutrilog_schema.sql` creates the four tables,
  constraints, indexes, updated-at triggers, RLS policies, and RPC functions.
- `tests/DATABASE_VALIDATION.md` provides the post-deployment security and
  behavior validation procedure for two disposable Auth users.

## Deployment model

Apply the migration exactly once through Supabase migration history. Prefer
`supabase db push` after linking the intended project rather than pasting the
file into the Dashboard SQL Editor. Supabase records applied migration
timestamps and does not rerun an already-applied migration.

The migration is intentionally forward-only and not silently idempotent:

- It is wrapped in a transaction, so an error rolls back the whole migration.
- It does not use destructive `drop ... cascade` statements.
- A manual second execution fails on existing objects instead of masking
  schema drift or replacing policies unexpectedly.
- If migration history and the remote schema ever disagree, inspect
  `supabase migration list` and use `supabase migration repair` only after
  verifying the actual remote schema.

## Security decisions

- Every row belongs to an Auth user through `user_id`.
- RLS is enabled on every application table with explicit authenticated-only
  policies for SELECT, INSERT, UPDATE, and DELETE.
- Table privileges are revoked from `PUBLIC`, `anon`, and `authenticated`
  before granting authenticated users only the four intended CRUD privileges.
  In particular, API roles are not granted `TRUNCATE`.
- RPCs do not accept `user_id`; they derive it from `auth.uid()`.
- RPCs use caller privileges (`security invoker`) and an empty `search_path`.
  Every referenced relation is schema-qualified.
- Function execution is revoked from `PUBLIC` and `anon`, then granted only to
  `authenticated`.
- No service-role key is required or stored.

Application meal creation must use `add_meal_record`, which locks the selected
active food and writes the name and nutrition snapshot in the same transaction.
Application food removal must use `remove_food`, which locks the food before
choosing the delete or archive path.
