// workout-api -- the first Edge Function in the whole project. Per CLAUDE.md's
// hybrid backend pattern, this only hosts the one write RLS can't gate on its
// own this milestone: assigning a card snapshots its exercises into a new
// workout_assignments/assignment_exercises pair (migration 009's
// assign_workout_card RPC) -- everything else (listing cards, reading an
// assignment, logging a set) is a direct supabase_flutter + RLS read/write
// from the app, no Edge Function route needed.
import { Hono } from "npm:hono";
import { zValidator } from "npm:@hono/zod-validator";
import { z } from "npm:zod";
import type { ContentfulStatusCode } from "npm:hono/utils/http-status";

import { type AuthEnv, authMiddleware, requireRole } from "../_shared/auth.ts";
import { errorResponse, mapRpcError } from "../_shared/errors.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";

const app = new Hono<AuthEnv>().basePath("/workout-api");

app.use("/*", authMiddleware);

const assignWorkoutCardSchema = z.object({
  cardId: z.string().uuid(),
  clientId: z.string().uuid(),
  startDate: z.string().date().nullish(),
  dueDate: z.string().date().nullish(),
});

const ASSIGN_WORKOUT_CARD_ERRORS: Record<string, { status: ContentfulStatusCode; message: string }> = {
  CARD_NOT_FOUND_OR_NOT_OWNED: { status: 404, message: "That card doesn't exist or isn't yours" },
  NO_ACTIVE_RELATIONSHIP: { status: 409, message: "You don't have an active coaching relationship with this client" },
};

app.post(
  "/assign-workout-card",
  requireRole("trainer"),
  zValidator("json", assignWorkoutCardSchema),
  async (c) => {
    const trainer = c.get("user");
    const body = c.req.valid("json");

    const { data, error } = await supabaseAdmin.rpc("assign_workout_card", {
      p_trainer_id: trainer.id,
      p_card_id: body.cardId,
      p_client_id: body.clientId,
      p_start_date: body.startDate ?? null,
      p_due_date: body.dueDate ?? null,
    });

    if (error) {
      return mapRpcError(c, error, ASSIGN_WORKOUT_CARD_ERRORS);
    }

    return c.json({ data: { assignmentId: data as string } }, 201);
  },
);

app.onError((err, c) => {
  console.error(err);
  return errorResponse(c, "INTERNAL_ERROR", "Something went wrong", 500);
});

Deno.serve(app.fetch);
