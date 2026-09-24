-- Milestone 4 -- habits, per Requirement 1 §9.2. The per-client instance
-- actually tracked -- snapshotted from the template at creation, same
-- reasoning as assignment_exercises (migration 007): a trainer editing the
-- template later shouldn't rewrite what a client is currently held to.
--
-- Milestone 4 built the self-created path only (client makes their own from
-- scratch, template_id = null, source = 'self_created'). Milestone 4.5 adds
-- a second self_created shape alongside it: a client browsing a *public*
-- habit_template and adopting it themselves (template_id set, still
-- source = 'self_created' -- per the user's own framing that habit tracking
-- is fundamentally something a client does for their own betterment, not
-- something that has to arrive via a trainer). Neither shape needs
-- snapshot-at-creation transactional logic in an Edge Function: unlike
-- assign-workout-card, a habit has no child table to snapshot into (no
-- assignment_exercises equivalent) -- the habits row itself *is* the
-- snapshot, so a client can safely copy a public template's fields into
-- their own insert directly, same precedent as workout_logs (single-owner
-- write, migration 008). RLS below validates the *link* (the template must
-- be genuinely public/published/approved), not that every copied field
-- matches the template exactly -- a client adjusting their own target on
-- adoption (e.g. a water-intake goal tuned to their own body weight) is a
-- legitimate use, not a hole to close.
--
-- trainer_assigned rows are the actual cross-user case: a trainer pushing
-- one of their own templates to a specific client needs the active-
-- coaching_relationships check, which RLS alone can't gate for an insert
-- where client_id <> auth.uid() -- that's Milestone 4.5's
-- assign_habit_template() (migration 017) + habits-api, mirroring
-- migration 009's assign_workout_card() exactly. Reachable only via the
-- service-role connection, so it doesn't need a matching policy branch here.
--
-- current_streak/best_streak are maintained by an AFTER trigger on
-- habit_logs (migration 016), not computed per-request and not client-
-- writable -- see that migration's header for why a DB trigger was chosen
-- over Plan.md's originally-sketched `update-habit-streaks` scheduled Edge
-- Function. Enforced here via column-level grants: `authenticated` has no
-- insert/update privilege on current_streak/best_streak at all, only the
-- table owner (via the SECURITY DEFINER trigger) can write them.

create table habits (
  id uuid primary key default gen_random_uuid(),
  template_id uuid references habit_templates(id),
  client_id uuid not null references client_profiles(id) on delete cascade,
  trainer_id uuid references trainer_profiles(id),
  source text not null default 'self_created' check (source in ('trainer_assigned', 'self_created')),
  title text not null,
  type text not null check (type in ('binary', 'quantity', 'wearable_auto')),
  unit text,
  target_value numeric,
  wearable_metric_field text,
  current_streak int not null default 0,
  best_streak int not null default 0,
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now()
);

create index idx_habits_client on habits(client_id) where status = 'active';
create index idx_habits_trainer on habits(trainer_id) where trainer_id is not null;

alter table habits enable row level security;

-- Per §9.5: client owns (client_id = auth.uid()), trainer gets read-only via
-- an EXISTS check against an active coaching_relationships row -- same
-- "active" status convention migration 007's own policies/indexes use.
create policy habits_select on habits for select
  using (
    client_id = auth.uid()
    or exists (
      select 1 from coaching_relationships cr
      where cr.client_id = habits.client_id and cr.trainer_id = auth.uid() and cr.status = 'active'
    )
  );

-- Direct-RLS insert covers both self_created shapes (from scratch, or
-- adopting a public template): the row must be the client's own, never
-- carry a trainer_id, and never `wearable_auto` (that type is only
-- meaningful once sync-wearable-data, Milestone 5, can actually write to it
-- via the service-role connection). When template_id is set, it must point
-- at a template that's actually public/published/approved -- a client can't
-- link to someone else's private or unpublished template just because the
-- uuid satisfies the FK. trainer_assigned rows come from habits-api's
-- service-role connection (migration 017), which bypasses RLS entirely, so
-- they don't need a matching policy branch here.
create policy habits_insert on habits for insert
  with check (
    client_id = auth.uid()
    and source = 'self_created'
    and trainer_id is null
    and type <> 'wearable_auto'
    and (
      template_id is null
      or exists (
        select 1 from habit_templates ht
        where ht.id = habits.template_id
          and ht.visibility = 'public'
          and ht.is_published = true
          and ht.moderation_status = 'approved'
      )
    )
  );

-- template_id isn't in the update column grant below (it's effectively
-- insert-only from the client's side), so there's no need to re-validate
-- the template link here -- only that the row is still the client's own
-- self_created shape.
create policy habits_update on habits for update
  using (client_id = auth.uid())
  with check (
    client_id = auth.uid()
    and source = 'self_created'
    and trainer_id is null
    and type <> 'wearable_auto'
  );

-- No delete policy/grant -- stopping tracking is a status update to
-- 'archived', same no-hard-delete precedent as workout_assignments
-- (migration 007).

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon grant: habits are always
-- behind a signed-in client, same as workout_logs/workout_assignments.
-- Column-level insert/update grants (first use of this shape in the
-- project) are what actually keeps current_streak/best_streak out of
-- client reach -- RLS's `with check` above governs which *rows* a client
-- can touch, not which *columns*, so this is the enforcement layer for
-- those two specifically.
grant select
on public.habits
to authenticated;

grant insert (template_id, client_id, trainer_id, source, title, type, unit, target_value, wearable_metric_field, status)
on public.habits
to authenticated;

grant update (title, unit, target_value, wearable_metric_field, status)
on public.habits
to authenticated;

grant select, insert, update, delete
on public.habits
to service_role;
