-- Milestone 8 -- subscribe_program(): the transactional core of the
-- subscribe-program Edge Function (fitcoach_backend/programs-api), per
-- Requirement 1 §11.3. Modeled directly on migration 009's
-- assign_workout_card() / migration 013's follow_public_card() shape --
-- validate everything first, then write in one transaction. Self-serve stub
-- this milestone, same payment posture as Milestone 7's redeem_invite()/
-- createSubscription: no payment gateway call anywhere in here,
-- price_paid_inr is copied straight from programs.price_inr, flagged
-- on-screen and in the manual steps doc as pending real Razorpay
-- integration (see Milestone 8.md §0 -- confirmed with the person before
-- building, same question M7 asked and answered the same way).
--
-- Unlike assign_workout_card(), there is no coaching_relationships check --
-- a program purchase is the marketplace's own, independent entry point into
-- workout_assignments/habits (§12: "Two independent entry points into the
-- same ... execution layer: a seat ... or a program purchase"), not a
-- private/gym coaching connection. relationship_id is left null on the
-- resulting workout_assignments row for that reason.
--
-- workout_card_id is nullable on programs (a program can be habit-only, per
-- §11.1), so the exercises snapshot only runs when one is actually bundled.
-- The habits insert always runs (a no-op select when program_habits has no
-- rows for this program).
--
-- security definer + search_path = '' so it can write program_subscriptions/
-- workout_assignments/assignment_exercises/habits (none of which grant
-- authenticated a direct cross-user insert path) regardless of the calling
-- role -- but it's only reachable via programs-api's service-role
-- connection (see the revoke at the bottom), same lock-down as every other
-- definer RPC in this project.

create or replace function public.subscribe_program(
  p_client_id uuid,
  p_program_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_program public.programs%rowtype;
  v_subscription_id uuid;
  v_assignment_id uuid;
  v_period_end timestamptz;
begin
  if not exists (select 1 from public.client_profiles where id = p_client_id) then
    raise exception 'CLIENT_NOT_FOUND';
  end if;

  select * into v_program
  from public.programs
  where id = p_program_id and is_published = true and moderation_status = 'approved';

  if not found then
    raise exception 'PROGRAM_NOT_FOUND_OR_NOT_PUBLISHED';
  end if;

  if exists (
    select 1 from public.program_subscriptions
    where client_id = p_client_id and program_id = p_program_id and status = 'active'
  ) then
    raise exception 'ALREADY_SUBSCRIBED';
  end if;

  -- No real recurring billing this milestone -- see migration 029's header
  -- for what actually happens to a 'monthly' subscription once this passes
  -- with no renewal behind it. 'one_time' gets current_period_end = null,
  -- i.e. permanent access, by design.
  v_period_end := case when v_program.billing_period = 'monthly' then now() + interval '1 month' else null end;

  insert into public.program_subscriptions (
    client_id, program_id, status, price_paid_inr, started_at, current_period_end
  )
  values (
    p_client_id, p_program_id, 'active', v_program.price_inr, now(), v_period_end
  )
  returning id into v_subscription_id;

  if v_program.workout_card_id is not null then
    insert into public.workout_assignments (
      card_id, trainer_id, client_id, org_id, relationship_id, source,
      assigned_at, status, program_subscription_id
    )
    values (
      v_program.workout_card_id, v_program.trainer_id, p_client_id, v_program.org_id, null, 'trainer_assigned',
      now(), 'active', v_subscription_id
    )
    returning id into v_assignment_id;

    insert into public.assignment_exercises (
      assignment_id, source_exercise_id, order_index, name, sets, reps,
      weight_kg, rest_seconds, demo_media_id, notes
    )
    select
      v_assignment_id, e.id, e.order_index, e.name, e.sets, e.reps,
      e.weight_kg, e.rest_seconds, e.demo_media_id, e.notes
    from public.exercises e
    where e.card_id = v_program.workout_card_id
    order by e.order_index;
  end if;

  insert into public.habits (
    template_id, client_id, trainer_id, source, title, type, unit,
    target_value, wearable_metric_field, status, program_subscription_id
  )
  select
    ht.id, p_client_id, v_program.trainer_id, 'trainer_assigned', ht.title, ht.type, ht.unit,
    ht.default_target_value, ht.wearable_metric_field, 'active', v_subscription_id
  from public.program_habits ph
  join public.habit_templates ht on ht.id = ph.habit_template_id
  where ph.program_id = p_program_id;

  return v_subscription_id;
end;
$$;

-- Only the service-role connection (fitcoach_backend/programs-api's
-- supabaseAdmin client) can call this -- same lock-down as every other
-- definer RPC in this project.
revoke execute on function public.subscribe_program(uuid, uuid)
from public, anon, authenticated;
