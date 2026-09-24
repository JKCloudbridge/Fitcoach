-- Milestone 6 -- notifications, per Requirement 1 §3.20. Always
-- system-written (a trainer/client never inserts one directly), so there's no
-- INSERT grant for `authenticated` at all -- only the four triggers below
-- (each SECURITY DEFINER, same lock-down shape as migration 010's
-- create_card_stats_row()) and service_role can write one. Marking one read
-- is a plain PATCH, narrowed to the read_at column by the grant below, same
-- pattern as migration 018's messages_update.
--
-- Four emitters, one per `type`, each hooked onto whatever table already
-- carries that event rather than editing any previously-shipped
-- migration/RPC in place:
--   - card_assigned:            AFTER INSERT on workout_assignments where
--                                source = 'trainer_assigned' (assign_workout_card,
--                                migration 009, deliberately left this as a
--                                deferred "notifies client" -- this is that follow-up)
--   - client_completed_workout: AFTER UPDATE on workout_assignments when
--                                status transitions to 'completed' -- the
--                                coarsest signal the current schema actually
--                                has for "a client finished this plan" (no
--                                whole-session-complete event exists at the
--                                per-set workout_logs granularity, and firing
--                                one notification per logged set would be
--                                noise, not signal)
--   - card_flagged:              AFTER INSERT on card_reports (migration 012)
--   - message:                   AFTER INSERT on messages (migration 018),
--                                notifying every other conversation member

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('card_assigned', 'client_completed_workout', 'card_flagged', 'message')),
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_notifications_user on notifications(user_id, created_at desc);

alter table notifications enable row level security;

create policy notifications_select on notifications for select
  using (user_id = auth.uid());

create policy notifications_update on notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon grant, no insert grant for
-- authenticated -- see header note.
grant select
on public.notifications
to authenticated;

grant update (read_at)
on public.notifications
to authenticated;

grant select, insert, update, delete
on public.notifications
to service_role;

-- card_assigned
create or replace function public.notify_card_assigned()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.source = 'trainer_assigned' then
    insert into public.notifications (user_id, type, payload)
    values (new.client_id, 'card_assigned', jsonb_build_object('assignment_id', new.id, 'card_id', new.card_id));
  end if;
  return new;
end;
$$;

create trigger workout_assignments_notify_card_assigned
  after insert on workout_assignments
  for each row execute function public.notify_card_assigned();

-- client_completed_workout
create or replace function public.notify_client_completed_workout()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' and new.trainer_id is not null then
    insert into public.notifications (user_id, type, payload)
    values (new.trainer_id, 'client_completed_workout', jsonb_build_object('assignment_id', new.id, 'client_id', new.client_id));
  end if;
  return new;
end;
$$;

create trigger workout_assignments_notify_completed
  after update on workout_assignments
  for each row execute function public.notify_client_completed_workout();

-- card_flagged
create or replace function public.notify_card_flagged()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trainer_id uuid;
begin
  select trainer_id into v_trainer_id from public.workout_cards where id = new.card_id;
  if v_trainer_id is not null then
    insert into public.notifications (user_id, type, payload)
    values (v_trainer_id, 'card_flagged', jsonb_build_object('card_id', new.card_id, 'report_id', new.id));
  end if;
  return new;
end;
$$;

create trigger card_reports_notify_flagged
  after insert on card_reports
  for each row execute function public.notify_card_flagged();

-- message
create or replace function public.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (user_id, type, payload)
  select cm.user_id, 'message', jsonb_build_object('conversation_id', new.conversation_id, 'message_id', new.id)
  from public.conversation_members cm
  where cm.conversation_id = new.conversation_id and cm.user_id != new.sender_id;
  return new;
end;
$$;

create trigger messages_notify_new_message
  after insert on messages
  for each row execute function public.notify_new_message();

-- Same reasoning as migration 018's publication add -- the bell's
-- `notifications-{user_id}` channel needs this table streamed.
alter publication supabase_realtime add table notifications;
