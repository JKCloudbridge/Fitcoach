-- Milestone 8 -- extends exercises_select (migration 006) and
-- habit_templates_select (migration 014) per §11.7: a paid program's card/
-- template still shows in Discover as a listing (workout_cards_select /
-- the rest of habit_templates_select's own row are untouched -- title/
-- cover/price stay visible to everyone the existing visibility rule already
-- allows), but the *detail* underneath (exercises rows, and a bundled
-- habit_templates row's own type/unit/target fields) is gated to the
-- trainer, non-subscribers of a free-or-unbundled card/template, or an
-- active program_subscriptions row.
--
-- §11.7's own SQL only shows the paid-gating clause in isolation, without
-- restating §4's visibility chain -- read here as composing with it (AND),
-- not replacing it: a private card's exercises still need the owning
-- trainer regardless of programs, and a public-but-unpaid card's exercises
-- stay open exactly as before. Implemented as AND so a *paid* program's
-- exercises need both "the card is visible at all" and "you're allowed past
-- the paywall" to pass -- the alternative (OR) would make the new clause
-- pointless, since `NOT EXISTS (paid program for this card)` already lets
-- every non-program card through unchanged regardless of the visibility
-- check. Same pattern extended to program_habits -> habit_templates per
-- §11.7's own closing line ("Same pattern extends to program_habits ->
-- habit_templates").
--
-- Not editable in place (migrations 006/014 are already live, per the M7
-- session's confirmed live-tables check) -- dropped and recreated as a new
-- policy object in this additive migration. Safe to do this way for RLS
-- specifically (unlike a table's shape): a policy is just a rule Postgres
-- re-evaluates on every query, no data migration or backfill involved.

drop policy if exists exercises_select on exercises;

create policy exercises_select on exercises for select
  using (
    exists (
      select 1 from workout_cards wc
      where wc.id = exercises.card_id
        and (
          wc.visibility = 'public'
          or wc.trainer_id = auth.uid()
          or (
            wc.visibility = 'gym_only' and exists (
              select 1 from organization_members om
              where om.org_id = wc.org_id and om.user_id = auth.uid() and om.status = 'active'
            )
          )
        )
        and (
          wc.trainer_id = auth.uid()
          or not exists (select 1 from programs p where p.workout_card_id = wc.id and p.price_inr > 0)
          or exists (
            select 1 from programs p
            join program_subscriptions ps on ps.program_id = p.id
            where p.workout_card_id = wc.id
              and ps.client_id = auth.uid()
              and ps.status = 'active'
          )
        )
    )
  );

drop policy if exists habit_templates_select on habit_templates;

create policy habit_templates_select on habit_templates for select
  using (
    (
      visibility = 'public'
      or trainer_id = auth.uid()
      or (
        visibility = 'gym_only' and exists (
          select 1 from organization_members om
          where om.org_id = habit_templates.org_id and om.user_id = auth.uid() and om.status = 'active'
        )
      )
    )
    and (
      trainer_id = auth.uid()
      or not exists (
        select 1 from program_habits ph
        join programs p on p.id = ph.program_id
        where ph.habit_template_id = habit_templates.id and p.price_inr > 0
      )
      or exists (
        select 1 from program_habits ph
        join programs p on p.id = ph.program_id
        join program_subscriptions ps on ps.program_id = p.id
        where ph.habit_template_id = habit_templates.id
          and ps.client_id = auth.uid()
          and ps.status = 'active'
      )
    )
  );
