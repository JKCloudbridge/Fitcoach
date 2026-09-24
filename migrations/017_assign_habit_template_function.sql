-- Milestone 4.5 -- assign_habit_template(): the transactional core of the
-- assign-habit-template Edge Function (fitcoach_backend/habits-api).
-- Modeled directly on migration 009's assign_workout_card() -- same
-- "validate everything first, then insert" shape, same reason it has to be
-- an Edge-Function-only RPC rather than a direct-RLS write: a trainer
-- inserting a row where client_id <> auth.uid() is a cross-user write RLS
-- can't gate on its own, and needs the active-coaching_relationships check
-- migration 015's own RLS can't express for an insert made on someone
-- else's behalf.
--
-- Unlike assign_workout_card(), there's no second insert into a child
-- snapshot table here -- habits has no assignment_exercises equivalent, the
-- habits row itself is the snapshot (title/type/unit/target_value/
-- wearable_metric_field copied straight off the template in the same
-- select).
--
-- security definer + search_path = '' so it runs with the elevated
-- privileges needed to write a trainer_assigned row (which authenticated's
-- own insert grant, migration 015, only ever allows for source =
-- 'self_created') regardless of the calling role -- but it is only
-- reachable via the Edge Function's service-role connection (see the
-- revoke at the bottom), which is what actually enforces "only a trainer
-- who owns this template, for a client they have an active relationship
-- with, can call this."

create or replace function public.assign_habit_template(
  p_trainer_id uuid,
  p_template_id uuid,
  p_client_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_relationship_id uuid;
  v_habit_id uuid;
begin
  if not exists (
    select 1 from public.habit_templates
    where id = p_template_id and trainer_id = p_trainer_id
  ) then
    raise exception 'TEMPLATE_NOT_FOUND_OR_NOT_OWNED';
  end if;

  select id into v_relationship_id
  from public.coaching_relationships
  where trainer_id = p_trainer_id and client_id = p_client_id and status = 'active'
  limit 1;

  if v_relationship_id is null then
    raise exception 'NO_ACTIVE_RELATIONSHIP';
  end if;

  insert into public.habits (
    template_id, client_id, trainer_id, source, title, type, unit,
    target_value, wearable_metric_field, status
  )
  select
    p_template_id, p_client_id, p_trainer_id, 'trainer_assigned', ht.title, ht.type, ht.unit,
    ht.default_target_value, ht.wearable_metric_field, 'active'
  from public.habit_templates ht
  where ht.id = p_template_id
  returning id into v_habit_id;

  return v_habit_id;
end;
$$;

-- Only the service-role connection (fitcoach_backend/habits-api's
-- supabaseAdmin client) can call this -- same lock-down as migration 009.
revoke execute on function public.assign_habit_template(uuid, uuid, uuid)
from public, anon, authenticated;
