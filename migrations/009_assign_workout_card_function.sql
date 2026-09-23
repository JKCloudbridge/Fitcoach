-- Milestone 2 -- assign_workout_card(): the transactional core of the
-- assign-workout-card Edge Function (fitcoach_backend/workout-api), per
-- Requirement 1 §6.6. Modeled directly on Proximity's rpc_place_order pattern
-- (Proximity/migrations/032_rpc_place_order.sql) -- cart -> order there is the
-- same shape as card -> assignment here: validate everything first (no writes
-- until validation passes), then snapshot child rows in one transaction,
-- raising a typed exception per failure mode that the Edge Function maps to an
-- HTTP status.
--
-- security definer + search_path = '' so it runs with the elevated privileges
-- needed to write workout_assignments/assignment_exercises (which grant no
-- direct INSERT to `authenticated`, see migration 007's header) regardless of
-- the calling role -- but it is only reachable via the Edge Function's
-- service-role connection (see the revoke at the bottom), which is what
-- actually enforces "only a trainer who owns this card, for a client they
-- have an active relationship with, can call this."
--
-- Deliberately does NOT insert a notification ("notifies client" in §6.6) --
-- the notifications table doesn't exist until Milestone 6. Flagged as
-- deferred, not forgotten, in Milestone 2.md.

create or replace function public.assign_workout_card(
  p_trainer_id uuid,
  p_card_id uuid,
  p_client_id uuid,
  p_start_date date default null,
  p_due_date date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_relationship_id uuid;
  v_assignment_id uuid;
begin
  if not exists (
    select 1 from public.workout_cards
    where id = p_card_id and trainer_id = p_trainer_id
  ) then
    raise exception 'CARD_NOT_FOUND_OR_NOT_OWNED';
  end if;

  select id into v_relationship_id
  from public.coaching_relationships
  where trainer_id = p_trainer_id and client_id = p_client_id and status = 'active'
  limit 1;

  if v_relationship_id is null then
    raise exception 'NO_ACTIVE_RELATIONSHIP';
  end if;

  insert into public.workout_assignments (
    card_id, trainer_id, client_id, org_id, relationship_id, source,
    assigned_at, start_date, due_date, status
  )
  select
    p_card_id, p_trainer_id, p_client_id, wc.org_id, v_relationship_id, 'trainer_assigned',
    now(), p_start_date, p_due_date, 'active'
  from public.workout_cards wc
  where wc.id = p_card_id
  returning id into v_assignment_id;

  insert into public.assignment_exercises (
    assignment_id, source_exercise_id, order_index, name, sets, reps,
    weight_kg, rest_seconds, demo_media_id, notes
  )
  select
    v_assignment_id, e.id, e.order_index, e.name, e.sets, e.reps,
    e.weight_kg, e.rest_seconds, e.demo_media_id, e.notes
  from public.exercises e
  where e.card_id = p_card_id
  order by e.order_index;

  return v_assignment_id;
end;
$$;

-- Only the service-role connection (fitcoach_backend/workout-api's
-- supabaseAdmin client) can call this -- same lock-down as Proximity's
-- rpc_place_order.
revoke execute on function public.assign_workout_card(uuid, uuid, uuid, date, date)
from public, anon, authenticated;
