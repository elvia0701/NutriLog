begin;

create table public.foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  calories integer not null,
  protein numeric(10, 3) not null,
  carbs numeric(10, 3) not null default 0,
  fat numeric(10, 3) not null default 0,
  favorite boolean not null default false,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint foods_name_check
    check (char_length(btrim(name)) between 1 and 200),
  constraint foods_calories_check check (calories >= 0),
  constraint foods_protein_check check (protein >= 0),
  constraint foods_carbs_check check (carbs >= 0),
  constraint foods_fat_check check (fat >= 0),
  constraint foods_user_id_id_key unique (user_id, id)
);

create table public.meal_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  entry_date date not null,
  meal_type text not null,
  food_id uuid not null,
  servings numeric(10, 3) not null,
  food_name_snapshot text not null,
  calories_snapshot integer not null,
  protein_snapshot numeric(10, 3) not null,
  carbs_snapshot numeric(10, 3) not null,
  fat_snapshot numeric(10, 3) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_records_meal_type_check
    check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  constraint meal_records_servings_check check (servings > 0),
  constraint meal_records_food_name_snapshot_check
    check (char_length(btrim(food_name_snapshot)) between 1 and 200),
  constraint meal_records_calories_snapshot_check
    check (calories_snapshot >= 0),
  constraint meal_records_protein_snapshot_check check (protein_snapshot >= 0),
  constraint meal_records_carbs_snapshot_check check (carbs_snapshot >= 0),
  constraint meal_records_fat_snapshot_check check (fat_snapshot >= 0),
  constraint meal_records_food_owner_fk
    foreign key (user_id, food_id)
    references public.foods (user_id, id)
    on update no action
    on delete no action
    deferrable initially deferred
);

create table public.weight_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  entry_date date not null,
  weight numeric(4, 1) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint weight_records_weight_check check (weight between 20 and 500),
  constraint weight_records_user_date_key unique (user_id, entry_date)
);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  effective_date date not null,
  calorie_target numeric(7, 2) not null,
  protein_target numeric(6, 2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint goals_calorie_target_check
    check (calorie_target between 100 and 10000),
  constraint goals_protein_target_check
    check (protein_target between 1 and 1000),
  constraint goals_user_effective_date_key unique (user_id, effective_date)
);

create index foods_user_active_name_idx
  on public.foods (user_id, is_archived, name);

create index foods_user_favorite_idx
  on public.foods (user_id)
  where favorite = true and is_archived = false;

create index meal_records_user_date_type_idx
  on public.meal_records (user_id, entry_date desc, meal_type, created_at);

create index meal_records_user_food_idx
  on public.meal_records (user_id, food_id);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = statement_timestamp();
  return new;
end;
$$;

create trigger foods_set_updated_at
before update on public.foods
for each row execute function public.set_updated_at();

create trigger meal_records_set_updated_at
before update on public.meal_records
for each row execute function public.set_updated_at();

create trigger weight_records_set_updated_at
before update on public.weight_records
for each row execute function public.set_updated_at();

create trigger goals_set_updated_at
before update on public.goals
for each row execute function public.set_updated_at();

revoke all on function public.set_updated_at() from public, anon, authenticated;

alter table public.foods enable row level security;
alter table public.meal_records enable row level security;
alter table public.weight_records enable row level security;
alter table public.goals enable row level security;

create policy foods_select_own
on public.foods
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy foods_insert_own
on public.foods
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy foods_update_own
on public.foods
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy foods_delete_own
on public.foods
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy meal_records_select_own
on public.meal_records
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy meal_records_insert_own
on public.meal_records
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy meal_records_update_own
on public.meal_records
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy meal_records_delete_own
on public.meal_records
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy weight_records_select_own
on public.weight_records
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy weight_records_insert_own
on public.weight_records
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy weight_records_update_own
on public.weight_records
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy weight_records_delete_own
on public.weight_records
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy goals_select_own
on public.goals
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy goals_insert_own
on public.goals
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy goals_update_own
on public.goals
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy goals_delete_own
on public.goals
for delete
to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.foods from public, anon, authenticated;
revoke all on table public.meal_records from public, anon, authenticated;
revoke all on table public.weight_records from public, anon, authenticated;
revoke all on table public.goals from public, anon, authenticated;

grant select, insert, update, delete on table public.foods to authenticated;
grant select, insert, update, delete on table public.meal_records
  to authenticated;
grant select, insert, update, delete on table public.weight_records
  to authenticated;
grant select, insert, update, delete on table public.goals to authenticated;

create function public.add_meal_record(
  food_id uuid,
  entry_date date,
  meal_type text,
  servings numeric
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_food public.foods%rowtype;
  new_record_id uuid;
begin
  if current_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  if $2 is null then
    raise exception using
      errcode = '22004',
      message = 'entry_date is required';
  end if;

  if $3 is null
    or $3 not in ('breakfast', 'lunch', 'dinner', 'snack')
  then
    raise exception using
      errcode = '23514',
      message = 'Invalid meal_type';
  end if;

  if $4 is null or $4 <= 0 then
    raise exception using
      errcode = '23514',
      message = 'servings must be greater than zero';
  end if;

  select f.*
  into selected_food
  from public.foods as f
  where f.id = $1
    and f.user_id = current_user_id
    and f.is_archived = false
  for key share;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Food not found or unavailable';
  end if;

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
    current_user_id,
    $2,
    $3,
    selected_food.id,
    $4,
    selected_food.name,
    selected_food.calories,
    selected_food.protein,
    selected_food.carbs,
    selected_food.fat
  )
  returning id into new_record_id;

  return new_record_id;
end;
$$;

create function public.remove_food(food_id uuid)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_food_id uuid;
begin
  if current_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  select f.id
  into selected_food_id
  from public.foods as f
  where f.id = $1
    and f.user_id = current_user_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Food not found';
  end if;

  if exists (
    select 1
    from public.meal_records as mr
    where mr.user_id = current_user_id
      and mr.food_id = selected_food_id
  ) then
    update public.foods as f
    set is_archived = true
    where f.id = selected_food_id
      and f.user_id = current_user_id;

    return 'archived';
  end if;

  delete from public.foods as f
  where f.id = selected_food_id
    and f.user_id = current_user_id;

  return 'deleted';
end;
$$;

revoke all on function public.add_meal_record(uuid, date, text, numeric)
  from public, anon, authenticated;
revoke all on function public.remove_food(uuid)
  from public, anon, authenticated;

grant execute
  on function public.add_meal_record(uuid, date, text, numeric)
  to authenticated;
grant execute on function public.remove_food(uuid) to authenticated;

comment on function public.add_meal_record(uuid, date, text, numeric) is
  'Creates an owned meal record using a server-side food nutrition snapshot.';
comment on function public.remove_food(uuid) is
  'Deletes an unreferenced owned food or archives it when meals reference it.';

commit;
