-- Milestone 3 -- card_stats, per Requirement 1 §3.15. Aggregates kept off the
-- hot workout_cards row, "written only by an Edge Function" per the doc --
-- here that means every write goes through a security-definer function
-- (never a direct authenticated grant), same lock-down shape as migration
-- 009's assign_workout_card(). Two writers this milestone:
--   - the auto-create trigger below (every workout_cards row gets a zeroed
--     card_stats row the moment it's created, so later increments are always
--     a plain UPDATE, never an upsert-or-race)
--   - migration 011's saved_cards insert/delete trigger (save_count)
--   - migration 013's follow_public_card() RPC (follow_count, in the same
--     transaction as the assignment it creates -- Plan.md's own instruction
--     was "decide whether update-card-stats is a synchronous side-effect or a
--     separate mechanism, don't over-build it"; a whole extra Edge Function
--     invoked on every save/follow would be over-building for what's really a
--     one-line counter bump each caller can already afford to do inline)
--
-- view_count/completion_count/share_count stay at their default 0 this
-- milestone -- view tracking has no obvious trigger point yet (Discover just
-- lists cards, it doesn't have a "card view" event), and completion_count
-- would mean reaching back into workout_logs from Discover's scope, which
-- Plan.md's milestone sequencing deliberately avoids re-touching. Deferred,
-- not forgotten -- see Milestone 3.md.

create table card_stats (
  card_id uuid primary key references workout_cards(id) on delete cascade,
  view_count int not null default 0,
  save_count int not null default 0,
  follow_count int not null default 0,
  completion_count int not null default 0,
  share_count int not null default 0,
  updated_at timestamptz not null default now()
);

alter table card_stats enable row level security;

-- Readable wherever the parent card is readable -- same visibility chain as
-- exercises_select in migration 006, RLS doesn't auto-inherit through card_id
-- so this is its own EXISTS check.
create policy card_stats_select on card_stats for select
  using (
    exists (
      select 1 from workout_cards wc
      where wc.id = card_stats.card_id
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

-- No insert/update/delete policy for authenticated at all -- every write is
-- security-definer-function-only, see header note.

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). anon gets select too, same reasoning as
-- workout_cards' own anon grant: public cards' stats are meant to be
-- Discover-browsable by a logged-out user, and RLS above already restricts
-- anon to public cards only (no auth.uid() for the trainer_id/gym_only
-- branches to match).
grant select
on public.card_stats
to anon;

grant select
on public.card_stats
to authenticated;

grant select, insert, update, delete
on public.card_stats
to service_role;

-- Auto-create a zeroed card_stats row the moment a workout_cards row exists,
-- so every later increment (save/follow/etc.) is a plain UPDATE against a row
-- that's guaranteed to already be there -- no upsert-or-race handling needed
-- in migration 011's trigger or migration 013's RPC.
create or replace function public.create_card_stats_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.card_stats (card_id) values (new.id);
  return new;
end;
$$;

create trigger workout_cards_create_stats
  after insert on workout_cards
  for each row execute function public.create_card_stats_row();
