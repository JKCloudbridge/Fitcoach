-- Milestone 3 -- card_reports, per Requirement 1 §3.16. The "basic moderation
-- flag" this milestone's own scope calls for -- NOT a moderation UI. There's
-- no admin role/claim plumbed anywhere in the project yet (moderate-card /
-- moderation-api stay deferred per Plan.md's open decisions and CLAUDE.md),
-- so this table is deliberately write-only from the client side: any signed-in
-- user can file a report for a card they can see, nobody but service_role can
-- read the list back. That's the safest default until an admin surface
-- actually exists to decide who should see reports.

create table card_reports (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references workout_cards(id) on delete cascade,
  reported_by uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  status text not null default 'open' check (status in ('open', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);

create index idx_card_reports_card on card_reports(card_id);

alter table card_reports enable row level security;

-- Insert-only: a signed-in user can file a report as themselves for any card
-- they can see (RLS doesn't re-check card visibility here -- reporting a card
-- you can't otherwise read isn't a meaningful attack, there's nothing to gain
-- from filing a report). No select/update/delete policy for authenticated at
-- all -- reports are unreadable via the Data API until an admin surface
-- exists to consume them (see header note).
create policy card_reports_insert on card_reports for insert
  with check (reported_by = auth.uid());

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon grant: reporting requires being
-- signed in. No select grant for authenticated either, per the RLS note above
-- -- the grant would be meaningless without a matching select policy, but
-- omitting it here keeps the intent explicit rather than relying on RLS alone.
grant insert
on public.card_reports
to authenticated;

grant select, insert, update, delete
on public.card_reports
to service_role;
