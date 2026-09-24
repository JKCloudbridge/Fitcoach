-- Milestone 7 -- redeem_invite(): the transactional core of the
-- redeem-invite Edge Function (fitcoach_backend/coaching-api), per
-- Requirement 1 §10.3/§13. Modeled directly on migration 009's
-- assign_workout_card() / migration 018's start_conversation() shape --
-- validate everything first (no writes until every check passes), then
-- write in one transaction, raising a typed exception per failure mode that
-- the Edge Function maps to an HTTP status.
--
-- security definer + search_path = '' so it can write coaching_relationships
-- (authenticated has no direct insert path there covering this flow) and
-- lock invites/subscriptions rows for update regardless of the calling
-- role -- but it's only reachable via coaching-api's service-role
-- connection (see the revoke at the bottom), same lock-down as every other
-- definer RPC in this project.
--
-- Row locks (`for update`) on the invite and subscription rows guard against
-- two concurrent redemptions of the same last seat both passing the
-- seats_used < seat_limit check before either writes -- same reasoning
-- Proximity's rpc_place_order uses for its own inventory check.

create or replace function public.redeem_invite(
  p_client_id uuid,
  p_code text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.invites%rowtype;
  v_subscription public.subscriptions%rowtype;
  v_trainer_id uuid;
  v_org_id uuid;
  v_type text;
  v_relationship_id uuid;
begin
  if not exists (select 1 from public.client_profiles where id = p_client_id) then
    raise exception 'CLIENT_NOT_FOUND';
  end if;

  select * into v_invite from public.invites where code = p_code for update;
  if not found then
    raise exception 'INVITE_NOT_FOUND';
  end if;

  if v_invite.status <> 'active' then
    raise exception 'INVITE_REVOKED';
  end if;

  if v_invite.expires_at is not null and v_invite.expires_at <= now() then
    raise exception 'INVITE_EXPIRED';
  end if;

  if v_invite.max_uses is not null and v_invite.uses_count >= v_invite.max_uses then
    raise exception 'INVITE_MAX_USES_REACHED';
  end if;

  select * into v_subscription from public.subscriptions where id = v_invite.subscription_id for update;
  if not found or v_subscription.status <> 'active' then
    raise exception 'SUBSCRIPTION_INACTIVE';
  end if;

  if v_subscription.seats_used >= v_subscription.seat_limit then
    raise exception 'SEATS_FULL';
  end if;

  -- Which trainer does this redemption connect the client to? A
  -- trainer-owned subscription has exactly one answer (the owner). A gym
  -- (organization-owned) subscription has no per-invite trainer column in
  -- the doc's own §10.2 schema, so the invite's creator -- required by
  -- migration 021's invites_insert policy to hold a trainer_profiles row --
  -- is used instead. Re-checked here (not just trusted from the RLS policy
  -- at creation time) in case that policy is ever loosened later.
  if v_subscription.owner_type = 'trainer' then
    v_trainer_id := v_subscription.owner_id;
    v_org_id := null;
    v_type := 'private';
  else
    v_trainer_id := v_invite.created_by;
    v_org_id := v_subscription.owner_id;
    v_type := 'gym';
    if not exists (select 1 from public.trainer_profiles where id = v_trainer_id) then
      raise exception 'INVITE_CREATOR_NOT_A_TRAINER';
    end if;
  end if;

  if exists (
    select 1 from public.coaching_relationships
    where trainer_id = v_trainer_id and client_id = p_client_id and status = 'active'
  ) then
    raise exception 'ALREADY_CONNECTED';
  end if;

  insert into public.coaching_relationships (trainer_id, client_id, org_id, type, status, started_at)
  values (v_trainer_id, p_client_id, v_org_id, v_type, 'active', now())
  returning id into v_relationship_id;

  update public.invites set uses_count = uses_count + 1 where id = v_invite.id;
  update public.subscriptions set seats_used = seats_used + 1 where id = v_subscription.id;

  return v_relationship_id;
end;
$$;

-- Only the service-role connection (coaching-api's supabaseAdmin client) can
-- call this -- same lock-down as every other definer RPC in this project.
revoke execute on function public.redeem_invite(uuid, text)
from public, anon, authenticated;
