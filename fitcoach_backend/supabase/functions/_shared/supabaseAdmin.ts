// Service-role Supabase client, shared by every domain function's _shared
// import. Used both to verify a caller's JWT (auth.getUser) and to call
// security-definer RPCs (like assign_workout_card) that intentionally aren't
// reachable through the anon/authenticated Data API grants -- see
// migrations/007's and 009's header comments.
import { createClient } from "npm:@supabase/supabase-js";

export const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);
