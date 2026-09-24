-- Milestone 6 -- conversations/conversation_members/messages, per Requirement 1
-- §3.17-3.19. Messages themselves are plain PostgREST + RLS per §6.7 (POST
-- /rest/v1/messages, RLS checks conversation_members) -- no Edge Function for
-- sending. Starting a *new* conversation is the one piece that can't be plain
-- RLS: inserting the first conversation_members rows for two people has no
-- existing membership row to authorize itself against (the doc's own §4
-- pattern -- "readable/writable only where auth.uid() has a row in
-- conversation_members for that conversation_id" -- is circular for the very
-- first row), and it needs real logic anyway (confirm an active
-- coaching_relationship between the two users, find-or-create the 1:1
-- conversation). That's exactly CLAUDE.md's "transactional write RLS can't
-- gate on its own" case, so it's a security-definer RPC
-- (start_conversation()) behind a new coaching-api Edge Function, same shape
-- as migration 009's assign_workout_card(). conversation_members therefore
-- gets no direct authenticated INSERT grant at all -- membership rows are
-- only ever created by that RPC.
--
-- 1:1 only this milestone (the join-table shape supports groups later, but
-- neither the concept HTML nor Plan.md's M6 scope row asks for group chat
-- yet -- see Milestone 6.md's scope notes).

create table conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table conversation_members (
  conversation_id uuid not null references conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index idx_conversation_members_user on conversation_members(user_id);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id),
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index idx_messages_conversation on messages(conversation_id, created_at);

alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;

-- Membership check as a SECURITY DEFINER helper, not a direct self-join
-- inside conversation_members' own policy -- a policy on a table that
-- queries that same table for its own USING clause hits Postgres' "infinite
-- recursion detected in policy" the moment the inner query needs RLS applied
-- too. Routing it through a definer function (which bypasses RLS on the read
-- inside it) is the standard way around that, same reasoning as this
-- project's other definer functions, just for a read instead of a write.
create or replace function public.is_conversation_member(p_conversation_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = p_conversation_id and cm.user_id = auth.uid()
  );
$$;

create policy conversations_select on conversations for select
  using (public.is_conversation_member(id));

-- No insert/update/delete policy for authenticated on conversations -- always
-- created via start_conversation() below.

create policy conversation_members_select on conversation_members for select
  using (public.is_conversation_member(conversation_id));

-- No insert/update/delete policy for authenticated on conversation_members
-- either -- see header note, membership rows are start_conversation()-only.

create policy messages_select on messages for select
  using (public.is_conversation_member(conversation_id));

create policy messages_insert on messages for insert
  with check (public.is_conversation_member(conversation_id) and sender_id = auth.uid());

-- Marking a message read: any member of the conversation can flip read_at
-- (not just the recipient -- with 1:1 chat that's the same person anyway, and
-- restricting further isn't worth it until group chat exists). The insert
-- policy's with check doesn't apply to update, so a fresh update policy is
-- needed -- and the grant below narrows it to the read_at column only, so a
-- member can't rewrite someone else's body/sender_id through this path.
create policy messages_update on messages for update
  using (public.is_conversation_member(conversation_id))
  with check (public.is_conversation_member(conversation_id));

-- Data API grants -- required from 2026-10-30 on (see memory:
-- project-supabase-data-api-grants). No anon grant anywhere here: messaging
-- always requires a signed-in, related user.
grant select
on public.conversations, public.conversation_members
to authenticated;

grant select, insert
on public.messages
to authenticated;

grant update (read_at)
on public.messages
to authenticated;

grant select, insert, update, delete
on public.conversations, public.conversation_members, public.messages
to service_role;

-- start_conversation(): the trainer<->client 1:1 find-or-create. Mirrors
-- migration 009's assign_workout_card() shape -- validate first (an active
-- coaching_relationships row must exist between the two, in either
-- direction), then either return an existing 1:1 conversation between them or
-- create a new one + both membership rows in the same transaction.
create or replace function public.start_conversation(
  p_user_id uuid,
  p_other_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation_id uuid;
begin
  if p_user_id = p_other_user_id then
    raise exception 'CANNOT_MESSAGE_SELF';
  end if;

  if not exists (
    select 1 from public.coaching_relationships
    where status = 'active'
      and (
        (trainer_id = p_user_id and client_id = p_other_user_id)
        or (trainer_id = p_other_user_id and client_id = p_user_id)
      )
  ) then
    raise exception 'NO_ACTIVE_RELATIONSHIP';
  end if;

  -- Existing 1:1 conversation between exactly these two members, if any.
  select cm1.conversation_id into v_conversation_id
  from public.conversation_members cm1
  join public.conversation_members cm2
    on cm2.conversation_id = cm1.conversation_id and cm2.user_id = p_other_user_id
  where cm1.user_id = p_user_id
    and (
      select count(*) from public.conversation_members cm3
      where cm3.conversation_id = cm1.conversation_id
    ) = 2
  limit 1;

  if v_conversation_id is not null then
    return v_conversation_id;
  end if;

  insert into public.conversations default values
  returning id into v_conversation_id;

  insert into public.conversation_members (conversation_id, user_id)
  values (v_conversation_id, p_user_id), (v_conversation_id, p_other_user_id);

  return v_conversation_id;
end;
$$;

-- Only the service-role connection (coaching-api's supabaseAdmin client) can
-- call this -- same lock-down as every other definer RPC in this project.
revoke execute on function public.start_conversation(uuid, uuid)
from public, anon, authenticated;

-- This project's first table that needs live updates -- Realtime Postgres
-- Changes only streams tables added to this publication, RLS above still
-- applies per-subscriber on top of it. Only `messages` needs it (the
-- `conversation-{id}` channel from Requirement 1 §6.8); the conversation
-- list itself refreshes on the `notifications` row a new message also
-- creates (migration 019), not by watching conversation_members/conversations
-- directly.
alter publication supabase_realtime add table messages;
