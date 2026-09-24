-- Milestone 8 -- program_subscriptions, per Requirement 1 §11.3. Created only
-- by subscribe_program() (migration 028) -- multi-table transactional logic
-- (insert this row, then cascade into workout_assignments + a habits row per
-- program_habits entry, all tagged program_subscription_id) that CLAUDE.md's
-- hybrid pattern puts in an Edge Function, same "no direct INSERT policy"
-- shape as workout_assignments itself (migration 007). Self-serve stub this
-- milestone, same payment posture as Milestone 7's subscriptions --
-- price_paid_inr is written straight from programs.price_inr at call time,
-- no gateway charge collected (see Milestone 8.md §0).

create table program_subscriptions (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references client_profiles(id) on delete cascade,
  program_id uuid not null references programs(id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'canceled', 'past_due')),
  price_paid_inr numeric not null default 0,
  started_at timestamptz not null default now(),
  current_period_end timestamptz
);

-- One active subscription per (client, program) -- defense-in-depth against
-- a double-subscribe race beyond subscribe_program()'s own existence check,
-- same "cheap integrity gap to close" precedent as migration 021's owner
-- validation trigger.
create unique index idx_program_subscriptions_active_unique
  on program_subscriptions(client_id, program_id)
  where status = 'active';

create index idx_program_subscriptions_program on program_subscriptions(program_id);
create index idx_program_subscriptions_client on program_subscriptions(client_id) where status = 'active';

alter table program_subscriptions enable row level security;

-- Readable by the subscribing client, or the program's own trainer (so a
-- trainer can see who's subscribed to their program) -- same "owner can see
-- who's using it" shape as invites_select (migration 021).
create policy program_subscriptions_select on program_subscriptions for select
  using (
    client_id = auth.uid()
    or exists (select 1 from programs p where p.id = program_subscriptions.program_id and p.trainer_id = auth.uid())
  );

-- No INSERT/UPDATE policy for authenticated -- creation (migration 028) and
-- status changes (migration 029) both go through security-definer RPCs on
-- the service-role connection only, same as workout_assignments (migration
-- 007). No cancel-subscription flow is built this milestone either (not in
-- this milestone's scope) -- flagged in Milestone 8.md as a known gap, same
-- treatment M7 gave the gym-admin UI gap.

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon, no direct authenticated write.
grant select
on public.program_subscriptions
to authenticated;

grant select, insert, update, delete
on public.program_subscriptions
to service_role;
