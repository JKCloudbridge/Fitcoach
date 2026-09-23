-- Milestone 3 -- saved_cards, per Requirement 1 §3.11. Pure bookmark -- "I
-- want to keep this," not "I'm doing this." Unlike workout_assignments
-- (Milestone 2), this table IS directly RLS-writable: the doc's own §6.5 API
-- section lists it as a plain POST/DELETE /rest/v1/saved_cards, not an Edge
-- Function route, since a client bookmarking their own card is single-owner
-- data with no cross-user transactional logic -- no security-definer RPC
-- needed here, unlike follow_public_card (migration 013), which does need one
-- because it also creates a workout_assignments row.

create table saved_cards (
  client_id uuid not null references client_profiles(id) on delete cascade,
  card_id uuid not null references workout_cards(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (client_id, card_id)
);

create index idx_saved_cards_client on saved_cards(client_id);

alter table saved_cards enable row level security;

-- Client owns their own bookmarks -- select/insert/delete only, no update
-- (bookmarking is add/remove, there's nothing on the row itself to edit).
create policy saved_cards_select on saved_cards for select
  using (client_id = auth.uid());

create policy saved_cards_insert on saved_cards for insert
  with check (client_id = auth.uid());

create policy saved_cards_delete on saved_cards for delete
  using (client_id = auth.uid());

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon grant: bookmarking always
-- requires a signed-in client.
grant select, insert, delete
on public.saved_cards
to authenticated;

grant select, insert, delete
on public.saved_cards
to service_role;

-- Keeps card_stats.save_count in sync with actual saved_cards rows --
-- security definer so it can write to card_stats, which grants no direct
-- authenticated access (see migration 010's header). Safe as a plain UPDATE,
-- never an upsert: migration 010's own trigger guarantees a card_stats row
-- already exists for every workout_cards row.
create or replace function public.bump_card_save_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.card_stats set save_count = save_count + 1, updated_at = now() where card_id = new.card_id;
    return new;
  else
    update public.card_stats set save_count = greatest(save_count - 1, 0), updated_at = now() where card_id = old.card_id;
    return old;
  end if;
end;
$$;

create trigger saved_cards_bump_stats
  after insert or delete on saved_cards
  for each row execute function public.bump_card_save_count();
