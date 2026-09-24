-- Milestone 7 -- subscriptions/invites, per Requirement 1 §10.1-10.2. The
-- seat license (subscriptions) and the invite codes that consume a seat on
-- redemption (invites, redeemed via migration 022's redeem_invite()).
--
-- §13 only lists GET endpoints for both tables (no POST) -- read as this
-- project's now-standard "permissive direct-RLS insert by the owning
-- trainer/org" pattern, same precedent migration 005 set for
-- coaching_relationships, not a new Edge Function route. redeem-invite is the
-- one write here that genuinely needs an Edge Function, because it's the one
-- operation crossing from "the invite's owner" to "someone else redeeming
-- it" -- see migration 022.
--
-- owner_id (§10.1's own note): can't be a real FK across two tables
-- (trainer_profiles vs organizations depending on owner_type). Rather than
-- leaving that purely app-layer as the doc describes, a BEFORE INSERT/UPDATE
-- trigger below validates owner_id actually resolves against the right table
-- for the given owner_type -- cheap to add, closes an obvious integrity gap
-- (a typo'd owner_id would otherwise silently create an orphaned
-- subscription no RLS policy could ever match, since every policy below
-- joins back through trainer_profiles/organizations).

create or replace function public.validate_subscription_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.owner_type = 'trainer' then
    if not exists (select 1 from public.trainer_profiles where id = new.owner_id) then
      raise exception 'OWNER_NOT_FOUND';
    end if;
  elsif new.owner_type = 'organization' then
    if not exists (select 1 from public.organizations where id = new.owner_id) then
      raise exception 'OWNER_NOT_FOUND';
    end if;
  end if;
  return new;
end;
$$;

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  owner_type text not null check (owner_type in ('trainer', 'organization')),
  owner_id uuid not null,
  plan_tier text not null,
  seat_limit int not null check (seat_limit > 0),
  -- Denormalized counter. Maintained directly by redeem_invite() (migration
  -- 022) rather than a trigger on coaching_relationships insert/delete --
  -- §10.1 says "trigger", §10.3's flow increments it as an explicit RPC step;
  -- picked the RPC step because a trigger would also need to handle
  -- relationships ended *outside* this flow (a trainer manually pausing a
  -- client, a future "remove from roster" feature) to keep the counter
  -- accurate, which is more moving parts than this milestone needs. Known
  -- gap: seats_used currently only ever increments -- there's no decrement
  -- path yet when a coaching_relationship ends, since no such
  -- end-relationship flow exists in the app yet either. Flagged in
  -- Milestone 7.md, not silently deferred.
  seats_used int not null default 0 check (seats_used >= 0),
  price_inr numeric not null default 0,
  billing_period text not null default 'monthly' check (billing_period in ('monthly')),
  current_period_start timestamptz not null default now(),
  current_period_end timestamptz,
  status text not null default 'active' check (status in ('active', 'past_due', 'canceled')),
  created_at timestamptz not null default now()
);

create index idx_subscriptions_owner on subscriptions(owner_type, owner_id);

create trigger subscriptions_validate_owner
  before insert or update of owner_type, owner_id on subscriptions
  for each row execute function public.validate_subscription_owner();

-- Small wrapper so the invites.code default reads clearly. 8 uppercase hex
-- chars (~4.3B combinations) -- no collision-retry loop built for this MVP
-- pass, same "don't over-build" call this project has made elsewhere; the
-- unique constraint below still rejects a collision outright rather than
-- silently overwriting another invite.
create or replace function public.generate_invite_code()
returns text
language sql
volatile
as $$
  select upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
$$;

create table invites (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references subscriptions(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  code text not null unique default public.generate_invite_code(),
  max_uses int check (max_uses is null or max_uses > 0),
  uses_count int not null default 0,
  expires_at timestamptz,
  status text not null default 'active' check (status in ('active', 'revoked')),
  created_at timestamptz not null default now()
);

create index idx_invites_subscription on invites(subscription_id);
create index idx_invites_code on invites(code);

alter table subscriptions enable row level security;
alter table invites enable row level security;

-- subscriptions: readable by the owning trainer, or any active member of the
-- owning organization (so a gym's roster/front-desk staff can see seat usage,
-- not just owner/admin). Writable (insert/most columns) only by the owning
-- trainer, or an org's owner/admin -- see decision log in Milestone 7.md for
-- why org writes are owner/admin-only (§14's organization_members role
-- matrix is still unresolved; this is the conservative default).
create policy subscriptions_select on subscriptions for select
  using (
    (owner_type = 'trainer' and owner_id = auth.uid())
    or (owner_type = 'organization' and exists (
      select 1 from organization_members om
      where om.org_id = subscriptions.owner_id and om.user_id = auth.uid() and om.status = 'active'
    ))
  );

create policy subscriptions_insert on subscriptions for insert
  with check (
    (owner_type = 'trainer' and owner_id = auth.uid())
    or (owner_type = 'organization' and exists (
      select 1 from organization_members om
      where om.org_id = subscriptions.owner_id and om.user_id = auth.uid()
        and om.status = 'active' and om.role in ('owner', 'admin')
    ))
  );

create policy subscriptions_update on subscriptions for update
  using (
    (owner_type = 'trainer' and owner_id = auth.uid())
    or (owner_type = 'organization' and exists (
      select 1 from organization_members om
      where om.org_id = subscriptions.owner_id and om.user_id = auth.uid()
        and om.status = 'active' and om.role in ('owner', 'admin')
    ))
  )
  with check (
    (owner_type = 'trainer' and owner_id = auth.uid())
    or (owner_type = 'organization' and exists (
      select 1 from organization_members om
      where om.org_id = subscriptions.owner_id and om.user_id = auth.uid()
        and om.status = 'active' and om.role in ('owner', 'admin')
    ))
  );

-- invites: creator must ALSO hold a trainer_profiles row, on top of the
-- owner/admin-or-trainer-owner check below -- redeem_invite() (migration
-- 022) uses invites.created_by as the coaching_relationships.trainer_id for
-- gym-mode redemptions (that table's trainer_id is not-null, and the doc's
-- own invites schema has no separate trainer_id column to pick one some
-- other way), so whoever creates an org invite has to be someone who can
-- legitimately become the assigned trainer. For a trainer-owned subscription
-- this is automatic (owner_id already has to be a trainer_profiles row, see
-- the validation trigger above). Known gap: a gym owner/admin who isn't
-- personally a trainer can manage the subscription but can't personally
-- issue invite codes -- flagged in Milestone 7.md, not silently papered over.
create policy invites_select on invites for select
  using (
    created_by = auth.uid()
    or exists (
      select 1 from subscriptions s
      where s.id = invites.subscription_id
        and (
          (s.owner_type = 'trainer' and s.owner_id = auth.uid())
          or (s.owner_type = 'organization' and exists (
            select 1 from organization_members om
            where om.org_id = s.owner_id and om.user_id = auth.uid() and om.status = 'active'
          ))
        )
    )
  );

create policy invites_insert on invites for insert
  with check (
    created_by = auth.uid()
    and exists (select 1 from trainer_profiles tp where tp.id = auth.uid())
    and exists (
      select 1 from subscriptions s
      where s.id = invites.subscription_id
        and (
          (s.owner_type = 'trainer' and s.owner_id = auth.uid())
          or (s.owner_type = 'organization' and exists (
            select 1 from organization_members om
            where om.org_id = s.owner_id and om.user_id = auth.uid()
              and om.status = 'active' and om.role in ('owner', 'admin')
          ))
        )
    )
  );

-- Revoking is the only post-creation write RLS needs to allow directly (no
-- PATCH /invites in §13 either) -- narrowed to the `status` column by the
-- grant below, same shape as migration 018/019's read_at/status column
-- grants. uses_count/expires_at/max_uses stay redeem_invite()-only /
-- creation-time-only.
create policy invites_update on invites for update
  using (
    exists (
      select 1 from subscriptions s
      where s.id = invites.subscription_id
        and (
          (s.owner_type = 'trainer' and s.owner_id = auth.uid())
          or (s.owner_type = 'organization' and exists (
            select 1 from organization_members om
            where om.org_id = s.owner_id and om.user_id = auth.uid()
              and om.status = 'active' and om.role in ('owner', 'admin')
          ))
        )
    )
  )
  with check (
    exists (
      select 1 from subscriptions s
      where s.id = invites.subscription_id
        and (
          (s.owner_type = 'trainer' and s.owner_id = auth.uid())
          or (s.owner_type = 'organization' and exists (
            select 1 from organization_members om
            where om.org_id = s.owner_id and om.user_id = auth.uid()
              and om.status = 'active' and om.role in ('owner', 'admin')
          ))
        )
    )
  );

-- Data API grants -- required from 2026-10-30 on for every new public-schema
-- table (see memory: project-supabase-data-api-grants). No anon grant on
-- either table: managing a subscription/invite always requires a signed-in
-- trainer/org member. A redeeming client never touches these tables
-- directly either -- redeem_invite() runs security definer via
-- coaching-api's service-role connection, see migration 022.
grant select, insert
on public.subscriptions
to authenticated;

grant update (plan_tier, seat_limit, price_inr, billing_period, current_period_start, current_period_end, status)
on public.subscriptions
to authenticated;

grant select, insert, update, delete
on public.subscriptions
to service_role;

grant select, insert
on public.invites
to authenticated;

grant update (status)
on public.invites
to authenticated;

grant select, insert, update, delete
on public.invites
to service_role;
