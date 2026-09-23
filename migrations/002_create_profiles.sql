-- Milestone 0 -- trainer_profiles / client_profiles, per Requirement 1 §3.3-3.4.
-- Both extend auth.users via a 1:1 id FK -- neither row exists until the
-- Milestone 1 signup flow's role-selection step creates it (see
-- Milestone readme/Milestone 0 manual steps.md for the JWT hook this feeds).

create table trainer_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  org_id uuid references organizations(id),
  display_name text,
  bio text,
  certifications text[],
  is_verified boolean not null default false,
  avatar_url text,
  created_at timestamptz not null default now()
);

create table client_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  org_id uuid references organizations(id),
  display_name text,
  date_of_birth date,
  height_cm numeric,
  weight_kg numeric,
  goals text[],
  avatar_url text,
  created_at timestamptz not null default now()
);
