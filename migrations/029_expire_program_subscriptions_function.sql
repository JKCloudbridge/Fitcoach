-- Milestone 8 -- expire_program_subscriptions(): the transactional core of
-- the expire-program-subscriptions route (fitcoach_backend/programs-api),
-- per §11.3/§13. Doc-specced as scheduled daily; built here as a plain
-- callable function reachable on demand -- Supabase Cron isn't configured
-- anywhere in this project yet (grep confirms this is the first scheduled/
-- cron job attempted here), so wiring the actual schedule is a manual step
-- (see Milestone 8 manual steps.md), not something a migration can do.
-- Callable/testable without a live cron, same "code complete, needs a human
-- to flip a dashboard switch" treatment Milestone 6 gave FCM push.
--
-- No real recurring billing exists yet -- subscribe-program (migration 028)
-- is a self-serve stub, same posture as Milestone 7's seat subscriptions --
-- so a 'monthly' program_subscriptions row has no renewal path once its
-- current_period_end passes. This function is what actually cuts off access
-- at that point: flips status to 'canceled', then archives every
-- workout_assignments/habits row tagged with a program_subscription_id
-- whose subscription is no longer 'active' (covers rows expired just now,
-- and any that became inactive some other way in the future -- idempotent
-- either way, re-running it is always safe). 'one_time' rows have
-- current_period_end = null (set by subscribe_program()) and are never
-- touched here -- a one-time purchase's access is permanent by design.
--
-- security definer + search_path = '' so it can write program_subscriptions/
-- workout_assignments/habits regardless of the calling role -- only
-- reachable via programs-api's service-role connection (see the revoke at
-- the bottom), same lock-down as every other definer RPC in this project.

create or replace function public.expire_program_subscriptions()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_expired_count int;
begin
  with expired as (
    update public.program_subscriptions
    set status = 'canceled'
    where status = 'active'
      and current_period_end is not null
      and current_period_end < now()
    returning id
  )
  select count(*) into v_expired_count from expired;

  update public.workout_assignments
  set status = 'archived'
  where status <> 'archived'
    and program_subscription_id in (
      select id from public.program_subscriptions where status <> 'active'
    );

  update public.habits
  set status = 'archived'
  where status <> 'archived'
    and program_subscription_id in (
      select id from public.program_subscriptions where status <> 'active'
    );

  return v_expired_count;
end;
$$;

-- Only the service-role connection (fitcoach_backend/programs-api's
-- supabaseAdmin client) can call this -- same lock-down as every other
-- definer RPC in this project.
revoke execute on function public.expire_program_subscriptions()
from public, anon, authenticated;
