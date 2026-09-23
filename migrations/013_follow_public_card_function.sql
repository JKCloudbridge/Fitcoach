-- Milestone 3 -- follow_public_card(): the transactional core of the
-- follow-public-card Edge Function (fitcoach_backend/workout-api), per
-- Requirement 1 §6.6. Client self-directed analog of migration 009's
-- assign_workout_card() -- same "validate everything first, then snapshot in
-- one transaction" shape, reused rather than duplicated differently per
-- Milestone 3's own instructions. Differs from assign_workout_card() in three
-- ways: the caller is the client, not a trainer; source is 'self_saved' with
-- trainer_id/org_id/relationship_id left null (no coaching_relationships row
-- involved); and it bumps card_stats.follow_count in the same transaction
-- instead of a separate update-card-stats mechanism -- see migration 010's
-- header for why a synchronous bump was chosen over a standalone job here.
--
-- security definer + search_path = '', only reachable via the Edge Function's
-- service-role connection (see the revoke at the bottom) -- same lock-down as
-- assign_workout_card(), which is what actually enforces "only a signed-in
-- client can start a genuinely public, approved, published card for
-- themselves."

create or replace function public.follow_public_card(
  p_client_id uuid,
  p_card_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment_id uuid;
begin
  if not exists (
    select 1 from public.workout_cards
    where id = p_card_id
      and visibility = 'public'
      and is_published = true
      and moderation_status = 'approved'
  ) then
    raise exception 'CARD_NOT_FOUND_OR_NOT_PUBLIC';
  end if;

  if exists (
    select 1 from public.workout_assignments
    where card_id = p_card_id and client_id = p_client_id and source = 'self_saved' and status = 'active'
  ) then
    raise exception 'ALREADY_FOLLOWING';
  end if;

  insert into public.workout_assignments (
    card_id, trainer_id, client_id, org_id, relationship_id, source,
    assigned_at, status
  )
  values (
    p_card_id, null, p_client_id, null, null, 'self_saved',
    now(), 'active'
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
  where e.card_id = p_card_id
  order by e.order_index;

  update public.card_stats set follow_count = follow_count + 1, updated_at = now() where card_id = p_card_id;

  return v_assignment_id;
end;
$$;

-- Only the service-role connection (fitcoach_backend/workout-api's
-- supabaseAdmin client) can call this -- same lock-down as
-- assign_workout_card().
revoke execute on function public.follow_public_card(uuid, uuid)
from public, anon, authenticated;
