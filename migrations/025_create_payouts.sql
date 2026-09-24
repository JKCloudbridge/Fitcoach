-- Milestone 8 -- payouts, per Requirement 1 §11.4. Data-only this milestone,
-- per Plan.md's own explicit compliance flag (§11.8: splitting a client
-- payment between the platform and a coach falls under RBI's Payment
-- Aggregator regulations in India, needing a PA product built for split
-- settlement -- Razorpay Route, Cashfree Easy Split -- plus GST/TDS
-- handling, not custom payout logic) -- there is no gateway payout call
-- anywhere in this project. run-payouts (fitcoach_backend/programs-api)
-- aggregates program_subscriptions revenue per trainer/org for a period,
-- applies a flat 15% platform fee (see Milestone 8.md §0), and writes a row
-- here with status = 'pending'. Nothing ever transitions a row past
-- 'pending' automatically -- 'processing'/'paid'/'failed' are schema-ready
-- for whenever real settlement is built, after the CA/fintech-consultant
-- sign-off §11.8 requires. This is not optional to skip; do not add a real
-- transfer call here without that sign-off.

create table payouts (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid references trainer_profiles(id),
  org_id uuid references organizations(id),
  period_start date not null,
  period_end date not null,
  gross_amount_inr numeric not null default 0,
  platform_fee_inr numeric not null default 0,
  net_amount_inr numeric not null default 0,
  status text not null default 'pending' check (status in ('pending', 'processing', 'paid', 'failed')),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  check (trainer_id is not null or org_id is not null)
);

create index idx_payouts_trainer on payouts(trainer_id) where trainer_id is not null;
create index idx_payouts_org on payouts(org_id) where org_id is not null;

alter table payouts enable row level security;

-- Readable by the earning trainer, or an active owner/admin member of the
-- earning org -- same shape as subscriptions_select (migration 021). No
-- write policy for authenticated at all: every row here is system-generated
-- by run-payouts' service-role connection, never client-writable.
create policy payouts_select on payouts for select
  using (
    (trainer_id is not null and trainer_id = auth.uid())
    or (org_id is not null and exists (
      select 1 from organization_members om
      where om.org_id = payouts.org_id and om.user_id = auth.uid()
        and om.status = 'active' and om.role in ('owner', 'admin')
    ))
  );

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon, no authenticated write.
grant select
on public.payouts
to authenticated;

grant select, insert, update, delete
on public.payouts
to service_role;
