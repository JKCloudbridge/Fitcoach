-- Milestone 8 -- adds program_subscription_id to workout_assignments
-- (migration 007) and habits (migration 015), per §11.3's closing note --
-- lets expire-program-subscriptions (migration 029) find exactly the rows a
-- lapsed program_subscriptions row created, without touching either
-- already-shipped migration file in place (same additive-column rule this
-- project has followed since migration 020).

alter table workout_assignments
  add column program_subscription_id uuid references program_subscriptions(id);

create index idx_workout_assignments_program_subscription
  on workout_assignments(program_subscription_id) where program_subscription_id is not null;

alter table habits
  add column program_subscription_id uuid references program_subscriptions(id);

create index idx_habits_program_subscription
  on habits(program_subscription_id) where program_subscription_id is not null;
