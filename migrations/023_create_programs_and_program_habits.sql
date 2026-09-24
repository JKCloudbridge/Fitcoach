-- Milestone 8 -- programs + program_habits, per Requirement 1 §11.1-11.2. A
-- program bundles one workout_card and zero or more habit_templates into a
-- single paid (or free, price_inr = 0) Discover listing a client can
-- subscribe to directly -- the marketplace's second, independent entry point
-- into the same workout_assignments/habits execution layer
-- coaching_relationships already feeds (§12).
--
-- moderation_status defaults to 'approved', same precedent workout_cards
-- (migration 006) and habit_templates (migration 014) already set --
-- moderate-card/moderation-api stays deferred, this isn't a new decision for
-- this milestone to make.
--
-- billing_period defaults to 'one_time' (the doc gives no default) -- the
-- simpler MVP shape given subscribe-program is a self-serve stub with no
-- real recurring billing this milestone (see Milestone 8.md §0); a trainer
-- can still set 'monthly' explicitly, see migration 028/029 for how a
-- monthly program's access actually lapses without a real billing cycle.

create or replace function public.validate_program_workout_card()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.workout_card_id is not null then
    if not exists (
      select 1 from public.workout_cards
      where id = new.workout_card_id and trainer_id = new.trainer_id
    ) then
      raise exception 'WORKOUT_CARD_NOT_OWNED';
    end if;
  end if;
  return new;
end;
$$;

create table programs (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references trainer_profiles(id) on delete cascade,
  org_id uuid references organizations(id),
  title text not null,
  description text,
  price_inr numeric not null default 0 check (price_inr >= 0),
  billing_period text not null default 'one_time' check (billing_period in ('monthly', 'one_time')),
  workout_card_id uuid references workout_cards(id),
  is_published boolean not null default false,
  moderation_status text not null default 'approved' check (moderation_status in ('pending', 'approved', 'flagged', 'removed')),
  created_at timestamptz not null default now()
);

create index idx_programs_trainer on programs(trainer_id);
create index idx_programs_public on programs(is_published) where is_published and moderation_status = 'approved';

create trigger programs_validate_workout_card
  before insert or update of workout_card_id, trainer_id on programs
  for each row execute function public.validate_program_workout_card();

create table program_habits (
  program_id uuid not null references programs(id) on delete cascade,
  habit_template_id uuid not null references habit_templates(id) on delete cascade,
  primary key (program_id, habit_template_id)
);

alter table programs enable row level security;
alter table program_habits enable row level security;

-- programs: published+approved listings readable by anyone (Discover,
-- including logged-out via the anon grant below); a trainer always sees
-- their own (published or not, same as workout_cards' own trainer_id =
-- auth.uid() branch). No gym_only-equivalent branch -- §11.1 has no
-- visibility column, a program is either a public marketplace listing or a
-- trainer's own draft.
create policy programs_select on programs for select
  using (
    (is_published and moderation_status = 'approved')
    or trainer_id = auth.uid()
  );

create policy programs_write on programs for all
  using (trainer_id = auth.uid())
  with check (trainer_id = auth.uid());

-- program_habits: readable wherever the parent program is readable (mirrors
-- exercises -> workout_cards in migration 006); writable only by the
-- program's own trainer, and only for a habit_template they themselves
-- authored -- closes an obvious integrity gap, same category as the
-- workout_card-ownership trigger above: bundling someone else's template
-- into your paid program would let you sell content you don't own.
create policy program_habits_select on program_habits for select
  using (
    exists (
      select 1 from programs p
      where p.id = program_habits.program_id
        and ((p.is_published and p.moderation_status = 'approved') or p.trainer_id = auth.uid())
    )
  );

create policy program_habits_write on program_habits for all
  using (
    exists (select 1 from programs p where p.id = program_habits.program_id and p.trainer_id = auth.uid())
    and exists (select 1 from habit_templates ht where ht.id = program_habits.habit_template_id and ht.trainer_id = auth.uid())
  )
  with check (
    exists (select 1 from programs p where p.id = program_habits.program_id and p.trainer_id = auth.uid())
    and exists (select 1 from habit_templates ht where ht.id = program_habits.habit_template_id and ht.trainer_id = auth.uid())
  );

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). anon gets select on programs, same
-- Discover-browsable-while-logged-out precedent as workout_cards/
-- habit_templates -- RLS above already restricts anon to published+approved
-- rows (anon has no auth.uid(), so the trainer_id branch never matches).
-- program_habits gets the same anon select so a logged-out Discover listing
-- can show bundled habit titles, not just the card.
grant select
on public.programs, public.program_habits
to anon;

grant select, insert, update, delete
on public.programs, public.program_habits
to authenticated;

grant select, insert, update, delete
on public.programs, public.program_habits
to service_role;
