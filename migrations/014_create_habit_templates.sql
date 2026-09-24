-- Milestone 4 -- habit_templates, per Requirement 1 §9.1. Trainer-authored,
-- reusable -- mirrors workout_cards' own visibility/moderation shape exactly
-- (migration 006), per the doc's own words ("Mirrors workout_cards -- same
-- visibility values, same moderation flow if published publicly").
--
-- Schema-ready this milestone, not yet reachable from the app: Milestone 4's
-- scope was narrowed to self-created habits only (client-side, template_id =
-- null) -- there's no trainer template-builder screen yet (no mockup
-- precedent for one, and it's a genuinely new UI surface), and no
-- habits-api route writes to this table. The table/RLS/grants still ship now
-- so habits.template_id (migration 015) has something to reference and the
-- shape matches the doc, same "schema-ready, not wired up" precedent as
-- workout_cards.moderation_status in Milestone 2. The trainer-authoring UI +
-- habits-api assign route are deferred to Milestone 4.5, per the user's own
-- scoping call this session.

create table habit_templates (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references trainer_profiles(id) on delete cascade,
  org_id uuid references organizations(id),
  title text not null,
  description text,
  type text not null check (type in ('binary', 'quantity', 'wearable_auto')),
  unit text,
  default_target_value numeric,
  wearable_metric_field text,
  visibility text not null default 'private' check (visibility in ('public', 'private', 'gym_only')),
  is_published boolean not null default false,
  moderation_status text not null default 'approved' check (moderation_status in ('pending', 'approved', 'flagged', 'removed')),
  created_at timestamptz not null default now()
);

create index idx_habit_templates_trainer on habit_templates(trainer_id);
create index idx_habit_templates_public on habit_templates(visibility) where visibility = 'public' and is_published;

alter table habit_templates enable row level security;

-- Identical shape to workout_cards_select/workout_cards_write (migration
-- 006): public templates readable by anyone signed in, own templates always
-- readable/writable, gym_only templates readable by active members of the
-- same org.
create policy habit_templates_select on habit_templates for select
  using (
    visibility = 'public'
    or trainer_id = auth.uid()
    or (
      visibility = 'gym_only' and exists (
        select 1 from organization_members om
        where om.org_id = habit_templates.org_id and om.user_id = auth.uid() and om.status = 'active'
      )
    )
  );

create policy habit_templates_write on habit_templates for all
  using (trainer_id = auth.uid())
  with check (trainer_id = auth.uid());

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). anon gets select too, same reasoning as
-- workout_cards' own anon grant: public templates are meant to be
-- Discover-browsable by a logged-out user once a habit-template browsing
-- surface exists -- granting it now avoids a churny follow-up migration, RLS
-- above already restricts anon to visibility = 'public' rows only.
grant select
on public.habit_templates
to anon;

grant select, insert, update, delete
on public.habit_templates
to authenticated;

grant select, insert, update, delete
on public.habit_templates
to service_role;
