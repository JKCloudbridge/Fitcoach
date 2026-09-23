-- Milestone 0 -- foundation tables. Schema per Initial requirement/Requirement 1
-- §3.1-3.2. Applied by hand against the linked Supabase project:
--   cd fitcoach_backend && supabase db query -f ../migrations/001_create_organizations.sql --linked
-- (plain numbered .sql files, no supabase/migrations dir / db push workflow --
-- same convention as both sibling apps' /migrations folder.)

create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  plan_tier text not null default 'free',
  owner_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- Resolves the "one user, one gym" limitation (§3.2): a trainer can be
-- independent and staff a gym; a client can belong to more than one gym.
create table organization_members (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'trainer', 'client')),
  status text not null default 'active' check (status in ('active', 'invited', 'removed')),
  joined_at timestamptz not null default now(),
  unique (org_id, user_id)
);

create index idx_organization_members_org on organization_members(org_id) where status = 'active';
create index idx_organization_members_user on organization_members(user_id) where status = 'active';
