-- Milestone 2 -- workout_cards + exercises, per Requirement 1 §3.6-3.7. A card
-- is a trainer-authored template -- it never carries a client_id at the schema
-- level; assigning it to a client is workout_assignments' job (migration 007),
-- via the assign-workout-card snapshot (migration 009).
--
-- cover_media_id / intro_media_id / demo_media_id are plain nullable uuid
-- columns, deliberately WITHOUT an FK to media_assets -- that table doesn't
-- exist until a later milestone (media upload is out of scope here, same
-- deferred-upload precedent as Milestone 1's read-only avatar_url). Add the FK
-- when media_assets ships.
--
-- moderation_status defaults to 'approved': moderate-card (Plan.md's
-- moderation-api) is explicitly deferred until moderation is actually needed,
-- so nothing enforces this column yet -- it's schema-ready, not wired up.

create table workout_cards (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references trainer_profiles(id) on delete cascade,
  org_id uuid references organizations(id),
  title text not null,
  description text,
  visibility text not null default 'private' check (visibility in ('public', 'private', 'gym_only')),
  cover_media_id uuid,
  intro_media_id uuid,
  tags text[] not null default '{}',
  difficulty text not null default 'beginner' check (difficulty in ('beginner', 'intermediate', 'advanced')),
  is_published boolean not null default false,
  moderation_status text not null default 'approved' check (moderation_status in ('pending', 'approved', 'flagged', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_workout_cards_trainer on workout_cards(trainer_id);
create index idx_workout_cards_public on workout_cards(visibility) where visibility = 'public' and is_published;

create table exercises (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references workout_cards(id) on delete cascade,
  name text not null,
  order_index int not null default 0,
  sets int not null default 1,
  reps text not null default '',
  weight_kg numeric,
  rest_seconds int not null default 60,
  demo_media_id uuid,
  notes text
);

create index idx_exercises_card on exercises(card_id, order_index);

alter table workout_cards enable row level security;
alter table exercises enable row level security;

-- workout_cards: public cards readable by anyone signed in, own cards always
-- readable, gym_only cards readable by active members of the same org -- exact
-- shape from Requirement 1 §4. Writes: trainer's own rows only.
create policy workout_cards_select on workout_cards for select
  using (
    visibility = 'public'
    or trainer_id = auth.uid()
    or (
      visibility = 'gym_only' and exists (
        select 1 from organization_members om
        where om.org_id = workout_cards.org_id and om.user_id = auth.uid() and om.status = 'active'
      )
    )
  );

create policy workout_cards_write on workout_cards for all
  using (trainer_id = auth.uid())
  with check (trainer_id = auth.uid());

-- exercises: RLS does not auto-inherit through card_id -- re-check the same
-- visibility chain via the parent card, per Requirement 1 §4's own note that
-- every table needs its own policy.
create policy exercises_select on exercises for select
  using (
    exists (
      select 1 from workout_cards wc
      where wc.id = exercises.card_id
        and (
          wc.visibility = 'public'
          or wc.trainer_id = auth.uid()
          or (
            wc.visibility = 'gym_only' and exists (
              select 1 from organization_members om
              where om.org_id = wc.org_id and om.user_id = auth.uid() and om.status = 'active'
            )
          )
        )
    )
  );

create policy exercises_write on exercises for all
  using (exists (select 1 from workout_cards wc where wc.id = exercises.card_id and wc.trainer_id = auth.uid()))
  with check (exists (select 1 from workout_cards wc where wc.id = exercises.card_id and wc.trainer_id = auth.uid()));

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). anon gets select too: public cards are
-- meant to be Discover-browsable by a logged-out user once Discover ships
-- (Milestone 3) -- granting it now avoids a churny follow-up migration, RLS
-- above already restricts anon to visibility = 'public' rows only (anon has no
-- auth.uid(), so the trainer_id/gym_only branches never match for it).
grant select
on public.workout_cards, public.exercises
to anon;

grant select, insert, update, delete
on public.workout_cards, public.exercises
to authenticated;

grant select, insert, update, delete
on public.workout_cards, public.exercises
to service_role;
