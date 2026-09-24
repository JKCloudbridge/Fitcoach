// programs-api -- per CLAUDE.md's hybrid backend pattern and Plan.md's own
// function table. First route ever added to this function (Milestone 8 is
// its first deploy, not a redeploy -- same situation coaching-api was in at
// Milestone 6). Three routes, none of them RLS-gateable on their own:
//
// - subscribe-program: multi-table transactional write (program_subscriptions
//   + cascading workout_assignments/habits), same shape as workout-api's
//   assign-workout-card/follow-public-card. Self-serve stub this milestone --
//   no payment gateway call, see migration 028's header and Milestone 8.md
//   §0. program-payment-webhook (§13's other listed endpoint, for when a
//   real gateway confirms payment) is deliberately NOT built this milestone,
//   same "don't build both blindly" call Milestone 7 made for gym-seat
//   billing -- there's nothing for it to confirm yet.
// - expire-program-subscriptions / run-payouts: scheduled per §13, but
//   Supabase Cron isn't wired up anywhere in this project yet (this is the
//   first scheduled job attempted here) -- both are plain callable routes,
//   gated by requireServiceRole instead of a signed-in user, reachable
//   on-demand for testing and by Supabase Cron once that's configured (see
//   Milestone 8 manual steps.md).
//
// Everything else -- listing programs (Discover), a trainer building/
// publishing one, bundling habit_templates via program_habits, a client's
// "My Programs" list -- is a direct supabase_flutter + RLS read/write, no
// route needed (see migration 023/024's own header comments).
import { Hono } from "npm:hono";
import { zValidator } from "npm:@hono/zod-validator";
import { z } from "npm:zod";
import type { ContentfulStatusCode } from "npm:hono/utils/http-status";

import { type AuthEnv, authMiddleware, requireRole, requireServiceRole } from "../_shared/auth.ts";
import { errorResponse, mapRpcError } from "../_shared/errors.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";

const app = new Hono<AuthEnv>().basePath("/programs-api");

// No blanket app.use("/*", authMiddleware) here, unlike every other function
// in this project -- expire-program-subscriptions/run-payouts are called
// with the service-role key itself, not a user bearer token, which
// authMiddleware's auth.getUser() call would reject outright. Auth is
// applied per-route below instead.

const subscribeProgramSchema = z.object({
  programId: z.string().uuid(),
});

const SUBSCRIBE_PROGRAM_ERRORS: Record<string, { status: ContentfulStatusCode; message: string }> = {
  CLIENT_NOT_FOUND: { status: 404, message: "Client profile not found" },
  PROGRAM_NOT_FOUND_OR_NOT_PUBLISHED: { status: 404, message: "That program isn't available right now" },
  ALREADY_SUBSCRIBED: { status: 409, message: "You're already subscribed to this program" },
};

// Client only -- a trainer never subscribes to their own program. Mirrors
// redeem-invite's shape (coaching-api) exactly: validate via RPC, map typed
// errors, 201 with the new row's id.
app.post(
  "/subscribe-program",
  authMiddleware,
  requireRole("client"),
  zValidator("json", subscribeProgramSchema),
  async (c) => {
    const client = c.get("user");
    const body = c.req.valid("json");

    const { data, error } = await supabaseAdmin.rpc("subscribe_program", {
      p_client_id: client.id,
      p_program_id: body.programId,
    });

    if (error) {
      return mapRpcError(c, error, SUBSCRIBE_PROGRAM_ERRORS);
    }

    return c.json({ data: { subscriptionId: data as string } }, 201);
  },
);

// Scheduled per §13 (daily), not yet wired to an actual Supabase Cron
// schedule -- see the file header and Milestone 8 manual steps.md. Thin
// wrapper around migration 029's expire_program_subscriptions(), which does
// all the actual work (flip lapsed subscriptions to 'canceled', archive
// their tagged workout_assignments/habits) in one transaction.
app.post("/expire-program-subscriptions", requireServiceRole, async (c) => {
  const { data, error } = await supabaseAdmin.rpc("expire_program_subscriptions");

  if (error) {
    console.error(error);
    return errorResponse(c, "INTERNAL_ERROR", "Failed to expire program subscriptions", 500);
  }

  return c.json({ data: { expiredCount: data as number } }, 200);
});

// Milestone 8.md §0 decisions: 15% flat platform fee, monthly cadence with a
// ₹500 minimum threshold (held/skipped rather than paid out, per §11.6's own
// "hold and roll over anything under ₹500" framing). No gateway payout call
// anywhere below -- writes a 'pending' payouts row only, per §11.8's
// compliance note and Plan.md's own explicit instruction not to build real
// money movement here without a CA/fintech-consultant sign-off.
const PLATFORM_FEE_RATE = 0.15;
const MIN_PAYOUT_THRESHOLD_INR = 500;

const runPayoutsSchema = z.object({
  periodStart: z.string().date(),
  periodEnd: z.string().date(),
});

type ProgramSubscriptionRevenueRow = {
  price_paid_inr: number;
  programs: { trainer_id: string } | { trainer_id: string }[] | null;
};

app.post(
  "/run-payouts",
  requireServiceRole,
  zValidator("json", runPayoutsSchema),
  async (c) => {
    const { periodStart, periodEnd } = c.req.valid("json");

    const { data: rows, error } = await supabaseAdmin
      .from("program_subscriptions")
      .select("price_paid_inr, programs!inner(trainer_id)")
      .gte("started_at", periodStart)
      .lt("started_at", periodEnd);

    if (error) {
      console.error(error);
      return errorResponse(c, "INTERNAL_ERROR", "Failed to aggregate program_subscriptions revenue", 500);
    }

    // Grouped by trainer_id only -- programs.org_id is informational (same
    // as workout_cards.org_id), not an alternate payout target the way
    // subscriptions.owner_type could split trainer- vs org-owned seat
    // licenses in Milestone 7. Every program always has a trainer_id, so
    // that's always who earned it.
    const grossByTrainer = new Map<string, number>();
    for (const row of (rows ?? []) as ProgramSubscriptionRevenueRow[]) {
      const program = Array.isArray(row.programs) ? row.programs[0] : row.programs;
      const trainerId = program?.trainer_id;
      if (!trainerId) continue;
      grossByTrainer.set(trainerId, (grossByTrainer.get(trainerId) ?? 0) + Number(row.price_paid_inr));
    }

    const created: Array<{ trainerId: string; grossAmountInr: number; platformFeeInr: number; netAmountInr: number }> = [];
    // Real "roll over to next period" needs a ledger linking each
    // program_subscriptions row to the payout it was included in -- out of
    // scope for this data-only stub (no real money moves either way this
    // milestone). Below-threshold trainers are simply skipped this run,
    // flagged as a known simplification in Milestone 8.md, not a real
    // carry-forward.
    const heldBelowThreshold: string[] = [];

    for (const [trainerId, gross] of grossByTrainer) {
      const platformFeeInr = Math.round(gross * PLATFORM_FEE_RATE * 100) / 100;
      const netAmountInr = Math.round((gross - platformFeeInr) * 100) / 100;

      if (netAmountInr < MIN_PAYOUT_THRESHOLD_INR) {
        heldBelowThreshold.push(trainerId);
        continue;
      }

      const { error: insertError } = await supabaseAdmin.from("payouts").insert({
        trainer_id: trainerId,
        period_start: periodStart,
        period_end: periodEnd,
        gross_amount_inr: gross,
        platform_fee_inr: platformFeeInr,
        net_amount_inr: netAmountInr,
        status: "pending",
      });

      if (insertError) {
        console.error(insertError);
        return errorResponse(c, "INTERNAL_ERROR", "Failed to write a payout row", 500);
      }

      created.push({ trainerId, grossAmountInr: gross, platformFeeInr, netAmountInr });
    }

    return c.json({ data: { created, heldBelowThreshold } }, 201);
  },
);

app.onError((err, c) => {
  console.error(err);
  return errorResponse(c, "INTERNAL_ERROR", "Something went wrong", 500);
});

Deno.serve(app.fetch);
