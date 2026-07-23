# NutriLog Supabase database validation

Run these checks only after creating a disposable Supabase project and applying
the migration. Create two test users with email and password in Authentication
and copy their UUIDs as `USER_A` and `USER_B`.

Do not use production users or a service-role key. The SQL snippets that seed
fixtures are intended for the Dashboard SQL Editor, which runs as the database
owner. The RLS checks explicitly switch to `anon` or `authenticated`.

Each negative test should be run in its own transaction because an expected
constraint error aborts the current transaction. Replace every placeholder UUID
before running a snippet.

## 1. Structural checks

Confirm RLS is enabled on all four tables:

```sql
select relname, relrowsecurity
from pg_class
where oid in (
  'public.foods'::regclass,
  'public.meal_records'::regclass,
  'public.weight_records'::regclass,
  'public.goals'::regclass
)
order by relname;
```

Expected: four rows and every `relrowsecurity` value is `true`.

Confirm each table has authenticated-only policies for all four commands:

```sql
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('foods', 'meal_records', 'weight_records', 'goals')
order by tablename, cmd;
```

Expected: 16 policies. Every `roles` value contains only `authenticated`.
Every update policy has both `qual` (`USING`) and `with_check`.

Confirm RPC execution is unavailable to `anon` and available to
`authenticated`:

```sql
select
  has_function_privilege(
    'anon',
    'public.add_meal_record(uuid,date,text,numeric)',
    'execute'
  ) as anon_add_meal,
  has_function_privilege(
    'authenticated',
    'public.add_meal_record(uuid,date,text,numeric)',
    'execute'
  ) as authenticated_add_meal,
  has_function_privilege(
    'anon',
    'public.remove_food(uuid)',
    'execute'
  ) as anon_remove_food,
  has_function_privilege(
    'authenticated',
    'public.remove_food(uuid)',
    'execute'
  ) as authenticated_remove_food;
```

Expected: `false, true, false, true`.

## 2. Seed isolated fixtures

Run as the SQL Editor owner after replacing the user UUIDs:

```sql
insert into public.foods (
  id,
  user_id,
  name,
  calories,
  protein,
  carbs,
  fat,
  favorite
)
values
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    'USER_A',
    'Same name',
    0,
    0,
    0,
    0,
    true
  ),
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    'USER_A',
    'Same name',
    120,
    8.5,
    10.25,
    4.75,
    false
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    'USER_B',
    'User B food',
    90,
    1.1,
    23,
    0.3,
    false
  );
```

Expected: all three inserts succeed. This verifies same-name foods and zero
nutrients are accepted.

## 3. Anonymous access is denied

```sql
begin;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

select * from public.foods;
rollback;
```

Expected: the select is denied at the table privilege layer. Run the insert
below as a separate transaction; it must also be denied:

```sql
begin;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

insert into public.foods (
  user_id, name, calories, protein, carbs, fat
)
values (
  'USER_A', 'Anonymous food', 0, 0, 0, 0
);
rollback;
```

Calling either RPC as `anon` must fail with a function permission error.

## 4. User A cannot read or write User B data

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'USER_A', true);

select id from public.foods
where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';

update public.foods
set name = 'Attempted overwrite'
where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';

delete from public.foods
where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
rollback;
```

Expected: the select returns zero rows; update and delete affect zero rows.

Run the following separately. It must fail its RLS `WITH CHECK`:

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'USER_A', true);

insert into public.foods (
  user_id, name, calories, protein, carbs, fat
)
values (
  'USER_B', 'Cross-user insert', 0, 0, 0, 0
);
rollback;
```

Also verify `WITH CHECK` prevents User A from moving an owned row to User B:

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'USER_A', true);

update public.foods
set user_id = 'USER_B'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
rollback;
```

Expected: the update is denied by the update policy's `WITH CHECK`.

## 5. Cross-user food foreign key is rejected

Run as the SQL Editor owner so RLS does not hide the foreign-key check:

```sql
begin;
insert into public.meal_records (
  user_id,
  entry_date,
  meal_type,
  food_id,
  servings,
  food_name_snapshot,
  calories_snapshot,
  protein_snapshot,
  carbs_snapshot,
  fat_snapshot
)
values (
  'USER_A',
  current_date,
  'lunch',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
  1,
  'Invalid cross-user snapshot',
  0,
  0,
  0,
  0
);
commit;
```

Expected: commit fails on `meal_records_food_owner_fk`.

## 6. Meal RPC creates the server-side snapshot

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'USER_A', true);

select public.add_meal_record(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
  current_date,
  'dinner',
  1.5
) as meal_id;

select
  food_name_snapshot,
  calories_snapshot,
  protein_snapshot,
  carbs_snapshot,
  fat_snapshot,
  servings
from public.meal_records
where user_id = 'USER_A'
  and food_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
rollback;
```

Expected snapshot: `Same name, 120, 8.500, 10.250, 4.750`; servings is
`1.500`.

Also confirm that User A calling `add_meal_record` with User B's food UUID fails
with `Food not found or unavailable`.

## 7. remove_food delete and archive paths

Delete path:

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'USER_A', true);

select public.remove_food(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
);
rollback;
```

Expected result: `deleted`.

Archive path:

```sql
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'USER_A', true);

select public.add_meal_record(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
  current_date,
  'breakfast',
  1
);

select public.remove_food(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2'
);

select is_archived
from public.foods
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
rollback;
```

Expected result: `archived`; `is_archived` is `true`, and the meal remains
readable with its snapshot.

## 8. Date uniqueness

Run each duplicate insert as a separate test:

```sql
insert into public.weight_records (user_id, entry_date, weight)
values
  ('USER_A', date '2026-07-23', 70),
  ('USER_A', date '2026-07-23', 71);
```

Expected: `weight_records_user_date_key` violation.

```sql
insert into public.goals (
  user_id, effective_date, calorie_target, protein_target
)
values
  ('USER_A', date '2026-07-23', 2000, 100),
  ('USER_A', date '2026-07-23', 2100, 110);
```

Expected: `goals_user_effective_date_key` violation.

The same date for User B must still be accepted.

## 9. Invalid values are rejected

Run each case separately and expect the named check constraint to fail:

```sql
-- Invalid meal type.
insert into public.meal_records (
  user_id, entry_date, meal_type, food_id, servings,
  food_name_snapshot, calories_snapshot, protein_snapshot,
  carbs_snapshot, fat_snapshot
)
values (
  'USER_A', current_date, 'brunch',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 1,
  'Invalid', 0, 0, 0, 0
);

-- Zero servings.
insert into public.meal_records (
  user_id, entry_date, meal_type, food_id, servings,
  food_name_snapshot, calories_snapshot, protein_snapshot,
  carbs_snapshot, fat_snapshot
)
values (
  'USER_A', current_date, 'snack',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 0,
  'Invalid', 0, 0, 0, 0
);

-- Negative nutrient.
insert into public.foods (
  user_id, name, calories, protein, carbs, fat
)
values ('USER_A', 'Invalid', 0, -0.001, 0, 0);

-- Out-of-range weights.
insert into public.weight_records (user_id, entry_date, weight)
values ('USER_A', current_date, 19.9);

insert into public.weight_records (user_id, entry_date, weight)
values ('USER_A', current_date, 500.1);
```

Repeat the negative food test with `calories = -1`, `carbs = -0.001`, and
`fat = -0.001`; each corresponding check constraint must reject the row.

Also verify `add_meal_record` rejects `brunch`, zero servings, archived foods,
and another user's food.

## 10. Cleanup

Run as the SQL Editor owner:

```sql
delete from public.meal_records
where user_id in ('USER_A', 'USER_B');

delete from public.weight_records
where user_id in ('USER_A', 'USER_B');

delete from public.goals
where user_id in ('USER_A', 'USER_B');

delete from public.foods
where user_id in ('USER_A', 'USER_B');
```
