-- Milestone 2 -- workout_logs, per Requirement 1 §3.10: "what actually
-- happened." Scoped to assignment_exercise_id, never to the template exercise
-- directly -- that's what keeps Progress unified regardless of how the workout
-- got into the client's hands, and stops a trainer's later template edit from
-- rewriting a client's history (doc's own words, quoted in Plan.md's research).
--
-- One row per (assignment_exercise, log_date): a client re-logs the same
-- assignment_exercise on different days as they repeat the plan. The app
-- derives a given day's "done" state by checking for a log_date = today row,
-- not from a stored boolean on assignment_exercises.

create table workout_logs (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references client_profiles(id) on delete cascade,
  assignment_exercise_id uuid not null references assignment_exercises(id) on delete cascade,
  log_date date not null default current_date,
  actual_sets int,
  actual_reps text,
  actual_weight_kg numeric,
  completed boolean not null default false,
  perceived_effort int check (perceived_effort between 1 and 10),
  notes text,
  created_at timestamptz not null default now()
);

create index idx_workout_logs_client_date on workout_logs(client_id, log_date);
create index idx_workout_logs_assignment_exercise on workout_logs(assignment_exercise_id, log_date);

alter table workout_logs enable row level security;

-- Client owns their own logs (insert/update); the owning trainer can also
-- read them (via assignment_exercises -> workout_assignments.trainer_id) so a
-- future trainer-client-dashboard Edge Function (Milestone 4+) has something
-- to aggregate -- RLS does not auto-inherit, so this is a fresh EXISTS chain,
-- same pattern as migrations 006-007.
create policy workout_logs_select on workout_logs for select
  using (
    client_id = auth.uid()
    or exists (
      select 1 from assignment_exercises ae
      join workout_assignments wa on wa.id = ae.assignment_id
      where ae.id = workout_logs.assignment_exercise_id and wa.trainer_id = auth.uid()
    )
  );

create policy workout_logs_write on workout_logs for all
  using (client_id = auth.uid())
  with check (client_id = auth.uid());

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon grant: logging always requires a
-- signed-in client.
grant select, insert, update, delete
on public.workout_logs
to authenticated;

grant select, insert, update, delete
on public.workout_logs
to service_role;
