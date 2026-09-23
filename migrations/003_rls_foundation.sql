-- Milestone 0 -- RLS foundation. Per the confirmed hybrid backend pattern
-- (Plan.md): Flutter reads these tables directly via supabase_flutter, gated
-- by policies here -- there is no service-role backend sitting in front of
-- reads the way both sibling apps' Hono layer does. Every table needs its
-- own policy; RLS does not auto-inherit through a foreign key (Requirement 1 §4).

alter table organizations enable row level security;
alter table organization_members enable row level security;
alter table trainer_profiles enable row level security;
alter table client_profiles enable row level security;

-- organizations: readable by any member; writable only by owner/admin members.
create policy organizations_select on organizations for select
  using (
    exists (
      select 1 from organization_members om
      where om.org_id = organizations.id and om.user_id = auth.uid() and om.status = 'active'
    )
  );

create policy organizations_update on organizations for update
  using (
    exists (
      select 1 from organization_members om
      where om.org_id = organizations.id and om.user_id = auth.uid()
        and om.status = 'active' and om.role in ('owner', 'admin')
    )
  );

-- organization_members: readable by any member of the same org_id; writable
-- only by rows where the caller's own membership role is owner or admin --
-- exact policy shape from Requirement 1 §4.
create policy organization_members_select on organization_members for select
  using (
    exists (
      select 1 from organization_members om
      where om.org_id = organization_members.org_id and om.user_id = auth.uid() and om.status = 'active'
    )
  );

create policy organization_members_write on organization_members for all
  using (
    exists (
      select 1 from organization_members om
      where om.org_id = organization_members.org_id and om.user_id = auth.uid()
        and om.status = 'active' and om.role in ('owner', 'admin')
    )
  )
  with check (
    exists (
      select 1 from organization_members om
      where om.org_id = organization_members.org_id and om.user_id = auth.uid()
        and om.status = 'active' and om.role in ('owner', 'admin')
    )
  );

-- trainer_profiles: public read (Discover needs to show coach info to
-- everyone, same as workout_cards' public visibility in §4); a trainer can
-- only write their own row. Trainer-side read access to their CLIENTS'
-- profiles is added in Milestone 2 alongside coaching_relationships, not here.
create policy trainer_profiles_select on trainer_profiles for select using (true);

create policy trainer_profiles_write on trainer_profiles for all
  using (id = auth.uid())
  with check (id = auth.uid());

-- client_profiles: private -- a client can only read/write their own row.
-- Trainer-side read access to a connected client's profile is added in
-- Milestone 2 (via an active coaching_relationships row), same as above.
create policy client_profiles_select on client_profiles for select using (id = auth.uid());

create policy client_profiles_write on client_profiles for all
  using (id = auth.uid())
  with check (id = auth.uid());
