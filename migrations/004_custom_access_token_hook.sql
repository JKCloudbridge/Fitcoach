-- Milestone 0 -- JWT custom claim hook, same mechanism as Baker Ally's
-- 006_custom_access_token_hook.sql. Must be enabled manually in the Supabase
-- Dashboard after this migration runs (Authentication -> Hooks -> "Customize
-- Access Token (JWT) Claims" -> select public.custom_access_token_hook) --
-- see Milestone readme/Milestone 0 manual steps.md.
--
-- Role here is presence-of-profile-row, not a single stored column: a
-- trainer_profiles row means 'trainer', a client_profiles row means
-- 'client'. A user with both rows (out of scope for v1, per Plan.md's "Two
-- role-gated shells" note) gets 'trainer' as the JWT claim -- the app's own
-- role-select/shell-switch logic is the real source of truth for which UI a
-- dual-role user sees, this claim is only a convenience for RLS/Edge
-- Function checks that need a single value.
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  resolved_role text;
begin
  if exists (select 1 from trainer_profiles where id = (event->>'user_id')::uuid) then
    resolved_role := 'trainer';
  elsif exists (select 1 from client_profiles where id = (event->>'user_id')::uuid) then
    resolved_role := 'client';
  else
    resolved_role := null;
  end if;

  claims := event->'claims';
  claims := jsonb_set(claims, '{app_metadata}', coalesce(claims->'app_metadata', '{}'::jsonb) || jsonb_build_object('role', resolved_role));
  event := jsonb_set(event, '{claims}', claims);

  return event;
end;
$$;

grant execute on function public.custom_access_token_hook to supabase_auth_admin;
