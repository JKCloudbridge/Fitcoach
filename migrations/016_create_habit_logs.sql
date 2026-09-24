-- Milestone 4 -- habit_logs, per Requirement 1 §9.3. One row per
-- (habit_id, log_date), enforced by a real unique constraint this time --
-- unlike workout_logs (migration 008), which deliberately left "one log per
-- exercise per day" as an app-level convention because assignment_exercise
-- ids can repeat across re-assignments, habit_id is stable for the life of
-- a habit, so the doc's own unique constraint is exactly right here and the
-- app can upsert on it directly (see fitcoach_app's habits_repository.dart)
-- instead of the fetch-then-insert-or-update dance workout_logs_repository
-- uses.
--
-- source stays schema-ready for 'wearable_auto' even though nothing writes
-- it yet -- sync-wearable-data (§9.4) is Milestone 5 scope, out of bounds
-- here, same "schema-ready, not wired up" precedent as migration 014's
-- moderation_status. Direct client writes are locked to source = 'manual'
-- via RLS below; a future service-role sync job bypasses RLS entirely.

create table habit_logs (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references habits(id) on delete cascade,
  log_date date not null default current_date,
  value numeric,
  completed boolean not null default false,
  source text not null default 'manual' check (source in ('manual', 'wearable_auto')),
  created_at timestamptz not null default now(),
  unique (habit_id, log_date)
);

create index idx_habit_logs_habit_date on habit_logs(habit_id, log_date);

alter table habit_logs enable row level security;

-- Same shape as habits' own RLS (migration 015, per §9.5): client owns via
-- the parent habit's client_id, trainer read-only via an EXISTS check
-- against an active coaching_relationships row. RLS doesn't auto-inherit
-- through habit_id -- fresh EXISTS chains, same pattern as exercises ->
-- workout_cards (migration 006) and assignment_exercises -> workout_
-- assignments (migration 007).
create policy habit_logs_select on habit_logs for select
  using (
    exists (
      select 1 from habits h
      where h.id = habit_logs.habit_id and h.client_id = auth.uid()
    )
    or exists (
      select 1 from habits h
      join coaching_relationships cr on cr.client_id = h.client_id
      where h.id = habit_logs.habit_id and cr.trainer_id = auth.uid() and cr.status = 'active'
    )
  );

-- Direct-RLS write, no Edge Function -- same precedent as workout_logs
-- (single-owner write, migration 008). source is pinned to 'manual' here:
-- the only other value ('wearable_auto') is written by a future service-
-- role sync job, which bypasses RLS entirely, so it never needs to satisfy
-- this check.
create policy habit_logs_write on habit_logs for all
  using (exists (select 1 from habits h where h.id = habit_logs.habit_id and h.client_id = auth.uid()))
  with check (
    exists (select 1 from habits h where h.id = habit_logs.habit_id and h.client_id = auth.uid())
    and source = 'manual'
  );

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon grant: logging always requires
-- a signed-in client, same as workout_logs.
grant select, insert, update, delete
on public.habit_logs
to authenticated;

grant select, insert, update, delete
on public.habit_logs
to service_role;

-- Streak maintenance -- per §9.2, current_streak/best_streak are "maintained
-- by update-habit-streaks Edge Function, not computed per-request". Plan.md
-- sketched that as a scheduled Supabase Cron job hitting a habits-api route;
-- built instead as a synchronous AFTER trigger here, same call Milestone 3
-- made for card_stats.follow_count (migration 013's own comment: "a whole
-- extra scheduled/Edge Function path for a one-line counter bump would be
-- over-building it"). habit_logs rows are small per habit (one per day), so
-- a full rescan on every insert/update/delete is cheap -- no incremental-
-- update bookkeeping needed. Revisit as an async/scheduled job only if
-- wearable_auto logging (Milestone 5) makes this trigger's per-row cost
-- actually matter; not a concern at self-created-habit volumes.
--
-- current_streak: length of the run of consecutive completed=true days
-- ending at the most recent log_date that exists for the habit (0 if that
-- most recent log isn't completed, or there are no logs at all).
-- best_streak: the largest current_streak this habit has ever reached,
-- monotonically non-decreasing.
create or replace function public.recompute_habit_streak()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_habit_id uuid;
  v_current int := 0;
  v_expected_date date;
  r record;
begin
  v_habit_id := coalesce(new.habit_id, old.habit_id);

  for r in
    select log_date, completed
    from public.habit_logs
    where habit_id = v_habit_id
    order by log_date desc
  loop
    exit when r.completed is not true;
    exit when v_expected_date is not null and r.log_date <> v_expected_date;
    v_current := v_current + 1;
    v_expected_date := r.log_date - 1;
  end loop;

  update public.habits
  set current_streak = v_current,
      best_streak = greatest(best_streak, v_current)
  where id = v_habit_id;

  return coalesce(new, old);
end;
$$;

create trigger habit_logs_streak
  after insert or update or delete on habit_logs
  for each row execute function public.recompute_habit_streak();
