// Auth middleware -- FitCoach's first Edge Function, so this is built fresh
// here, patterned directly on Proximity's proximity_backend/supabase/functions
// /api/middleware/auth.ts (the only approved reference for this milestone).
import { createMiddleware } from "npm:hono/factory";
import type { User } from "npm:@supabase/supabase-js";

import { supabaseAdmin } from "./supabaseAdmin.ts";

export type AuthEnv = { Variables: { user: User } };

export const authMiddleware = createMiddleware<AuthEnv>(async (c, next) => {
  const token = c.req.header("Authorization")?.replace("Bearer ", "");
  if (!token) {
    return c.json({ error: { code: "UNAUTHORIZED", message: "Missing bearer token" } }, 401);
  }

  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) {
    return c.json({ error: { code: "UNAUTHORIZED", message: "Invalid or expired token" } }, 401);
  }

  // getUser() returns app_metadata as persisted on auth.users
  // (raw_app_meta_data) -- it does NOT include the 'role' claim migration
  // 004's custom_access_token_hook stamps into the *signed JWT payload*
  // itself (trainer_profiles/client_profiles row presence, resolved fresh per
  // token). requireRole() below needs that hook-injected claim, so it's
  // decoded directly off the token this request carries -- a decode only, not
  // a second signature check, since getUser() above already verified this
  // exact token is authentic.
  const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
  const user = { ...data.user, app_metadata: { ...data.user.app_metadata, ...payload.app_metadata } };

  c.set("user", user);
  await next();
});

export const requireRole = (...roles: Array<"trainer" | "client">) =>
  createMiddleware<AuthEnv>(async (c, next) => {
    const user = c.get("user");
    const role = user.app_metadata?.role;
    if (!role || !roles.includes(role)) {
      return c.json({ error: { code: "FORBIDDEN", message: "Insufficient role" } }, 403);
    }
    await next();
  });

// Milestone 8 -- gates a route to the service-role key only, for scheduled/
// admin routes (programs-api's expire-program-subscriptions, run-payouts)
// that Supabase Cron (or a human, manually) invokes directly rather than a
// signed-in trainer/client -- authMiddleware above can't apply to these,
// since auth.getUser() rejects a service-role key outright (it isn't a user
// JWT). Compares the bearer token to this project's own service-role key
// rather than decoding it, same "the key itself is the credential" shape
// Supabase Cron's own pg_net invocations use.
export const requireServiceRole = createMiddleware(async (c, next) => {
  const token = c.req.header("Authorization")?.replace("Bearer ", "");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!token || !serviceKey || token !== serviceKey) {
    return c.json({ error: { code: "FORBIDDEN", message: "Service-role access only" } }, 403);
  }
  await next();
});
