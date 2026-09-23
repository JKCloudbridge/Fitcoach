-- Milestone 2 -- workout_assignments + assignment_exercises, per Requirement 1
-- §3.8-3.9: the snapshot pattern. assignment_exercises is a copy of exercises
-- taken at the moment a card is assigned -- editing the template afterward
-- never touches an existing assignment, and editing an assignment (e.g. a
-- trainer bumping one client's weight_kg) never touches the template.
--
-- workout_assignments creation is deliberately NOT reachable via direct RLS
-- insert -- it's multi-table transactional logic (validate coaching_relationship
-- -> insert assignment -> snapshot exercises), which CLAUDE.md's hybrid pattern
-- says belongs in an Edge Function (assign-workout-card, migration 009 +
-- fitcoach_backend/workout-api), not a direct write path. So there is no
-- INSERT policy or grant for `authenticated` on workout_assignments -- only
-- the service-role connection (via the assign_workout_card() RPC) can create
-- one. `source='self_saved'` (follow-public-card, client self-assigning from
-- Discover) is schema-ready but out of scope this milestone -- Discover itself
-- isn't built yet.

create table workout_assignments (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references workout_cards(id),
  trainer_id uuid references trainer_profiles(id),
  client_id uuid not null references client_profiles(id) on delete cascade,
  org_id uuid references organizations(id),
  relationship_id uuid references coaching_relationships(id),
  source text not null default 'trainer_assigned' check (source in ('trainer_assigned', 'self_saved')),
  assigned_at timestamptz not null default now(),
  start_date date,
  due_date date,
  status text not null default 'active' check (status in ('active', 'completed', 'archived'))
);

create index idx_workout_assignments_client on workout_assignments(client_id);
create index idx_workout_assignments_trainer on workout_assignments(trainer_id);

create table assignment_exercises (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references workout_assignments(id) on delete cascade,
  source_exercise_id uuid references exercises(id) on delete set null,
  order_index int not null default 0,
  name text not null,
  sets int not null default 1,
  reps text not null default '',
  weight_kg numeric,
  rest_seconds int not null default 60,
  demo_media_id uuid,
  notes text
);

create index idx_assignment_exercises_assignment on assignment_exercises(assignment_id, order_index);

alter table workout_assignments enable row level security;
alter table assignment_exercises enable row level security;

-- workout_assignments: either party can read their own assignment. Only
-- UPDATE is direct-RLS (e.g. a client archiving their own plan, or a trainer
-- marking one completed) -- creation is Edge-Function-only, see header note.
create policy workout_assignments_select on workout_assignments for select
  using (client_id = auth.uid() or trainer_id = auth.uid());

create policy workout_assignments_update on workout_assignments for update
  using (client_id = auth.uid() or trainer_id = auth.uid())
  with check (client_id = auth.uid() or trainer_id = auth.uid());

-- assignment_exercises: RLS does not auto-inherit through assignment_id --
-- re-check via the parent assignment, same pattern as exercises ->
-- workout_cards in migration 006. Trainers can adjust an already-assigned
-- plan's per-client sets/reps/weight_kg/notes (insert/update/delete) without
-- touching the source template, per §3.9's own note that this is deliberately
-- editable; clients only read (they log against it via workout_logs instead,
-- migration 008).
create policy assignment_exercises_select on assignment_exercises for select
  using (
    exists (
      select 1 from workout_assignments wa
      where wa.id = assignment_exercises.assignment_id
        and (wa.client_id = auth.uid() or wa.trainer_id = auth.uid())
    )
  );

create policy assignment_exercises_trainer_write on assignment_exercises for all
  using (
    exists (
      select 1 from workout_assignments wa
      where wa.id = assignment_exercises.assignment_id and wa.trainer_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from workout_assignments wa
      where wa.id = assignment_exercises.assignment_id and wa.trainer_id = auth.uid()
    )
  );

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon grant on either table -- both are
-- always behind a signed-in trainer/client relationship.
grant select, update
on public.workout_assignments
to authenticated;

grant select, insert, update, delete
on public.assignment_exercises
to authenticated;

grant select, insert, update, delete
on public.workout_assignments, public.assignment_exercises
to service_role;
