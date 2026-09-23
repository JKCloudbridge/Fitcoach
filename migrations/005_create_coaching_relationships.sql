-- Milestone 2 -- coaching_relationships, per Requirement 1 §3.5. The
-- trainer<->client connection that assign-workout-card (migration 009) checks
-- before letting a trainer assign a card, and that workout_assignments /
-- assignment_exercises / workout_logs RLS below chains through.
--
-- The doc's own §4 RLS section does not give an explicit policy block for this
-- table (only workout_cards/exercises/wearable_*/organization_members/messages
-- get literal SQL there) -- the policies below are this migration's own design:
-- either party can read their own relationship row, and since there's no
-- invite/consent flow yet (redeem-invite is Milestone 7's gym-seat work), a
-- trainer can insert a relationship for themselves directly. This is
-- permissive by design for MVP testing -- see Milestone 2 manual steps.md for
-- how to create a test relationship by hand until Milestone 7 replaces this
-- with a real invite flow.

create table coaching_relationships (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references trainer_profiles(id) on delete cascade,
  client_id uuid not null references client_profiles(id) on delete cascade,
  org_id uuid references organizations(id),
  type text not null default 'private' check (type in ('private', 'gym')),
  status text not null default 'active' check (status in ('active', 'paused', 'ended')),
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

-- Partial unique index: a trainer and client can only have one *active*
-- relationship at a time (they can re-connect after one ends, hence partial
-- rather than a plain unique constraint).
create unique index idx_coaching_relationships_active_pair
  on coaching_relationships(trainer_id, client_id) where status = 'active';

create index idx_coaching_relationships_trainer on coaching_relationships(trainer_id) where status = 'active';
create index idx_coaching_relationships_client on coaching_relationships(client_id) where status = 'active';

alter table coaching_relationships enable row level security;

create policy coaching_relationships_select on coaching_relationships for select
  using (trainer_id = auth.uid() or client_id = auth.uid());

create policy coaching_relationships_insert on coaching_relationships for insert
  with check (trainer_id = auth.uid());

create policy coaching_relationships_update on coaching_relationships for update
  using (trainer_id = auth.uid() or client_id = auth.uid())
  with check (trainer_id = auth.uid() or client_id = auth.uid());

-- Data API grants -- required from 2026-10-30 on for every new public-schema
-- table (see memory: project-supabase-data-api-grants). No anon grant: this
-- table is never relevant to a logged-out user.
grant select, insert, update
on public.coaching_relationships
to authenticated;

grant select, insert, update, delete
on public.coaching_relationships
to service_role;
