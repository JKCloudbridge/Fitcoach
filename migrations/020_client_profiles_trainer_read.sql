-- Milestone 6 -- fixes a gap left over from Milestone 0/2: migration 003's
-- own header comment says "Trainer-side read access to their CLIENTS'
-- profiles is added in Milestone 2 alongside coaching_relationships" (003,
-- line 60), but migration 005 (coaching_relationships) never actually added
-- that policy -- client_profiles_select has stayed `id = auth.uid()` only
-- ever since. That means every existing embedded-select of
-- `client_profiles(display_name)` a trainer runs (e.g.
-- coaching_relationships_repository.dart's fetchActiveClients, used by
-- assign_card_sheet.dart) has been silently returning null for that nested
-- object the whole time -- explaining assign_card_sheet's "Unnamed client"
-- fallback firing unconditionally. Not fixed in place (migration 003 may
-- already be applied live, so a DROP+CREATE there is out -- this is a purely
-- additive new policy, which Postgres OR's together with the existing one).
--
-- Surfaced now because Milestone 6's conversation list needs a trainer to be
-- able to read the display_name of a client they're messaging, not just a
-- fallback string -- see manual steps doc for what to double check once this
-- is live.

create policy client_profiles_select_by_trainer on client_profiles for select
  using (
    exists (
      select 1 from coaching_relationships cr
      where cr.client_id = client_profiles.id
        and cr.trainer_id = auth.uid()
        and cr.status = 'active'
    )
  );
