// habits-api -- per CLAUDE.md's hybrid backend pattern, this only hosts the
// one write RLS can't gate on its own: a trainer pushing one of their own
// habit_templates to a specific client (assign-habit-template, migration
// 017's assign_habit_template RPC), the cross-user case that needs the
// active-coaching_relationships check. Everything else -- listing/creating
// templates, a client creating or adopting a habit, logging a day -- is a
// direct supabase_flutter + RLS read/write, no Edge Function route needed
// (see migrations 014-016's own header comments for why).
import { Hono } from "npm:hono";
import { zValidator } from "npm:@hono/zod-validator";
import { z } from "npm:zod";
import type { ContentfulStatusCode } from "npm:hono/utils/http-status";

import { type AuthEnv, authMiddleware, requireRole } from "../_shared/auth.ts";
import { errorResponse, mapRpcError } from "../_shared/errors.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";

const app = new Hono<AuthEnv>().basePath("/habits-api");

app.use("/*", authMiddleware);

const assignHabitTemplateSchema = z.object({
  templateId: z.string().uuid(),
  clientId: z.string().uuid(),
});

const ASSIGN_HABIT_TEMPLATE_ERRORS: Record<string, { status: ContentfulStatusCode; message: string }> = {
  TEMPLATE_NOT_FOUND_OR_NOT_OWNED: { status: 404, message: "That habit template doesn't exist or isn't yours" },
  NO_ACTIVE_RELATIONSHIP: { status: 409, message: "You don't have an active coaching relationship with this client" },
};

app.post(
  "/assign-habit-template",
  requireRole("trainer"),
  zValidator("json", assignHabitTemplateSchema),
  async (c) => {
    const trainer = c.get("user");
    const body = c.req.valid("json");

    const { data, error } = await supabaseAdmin.rpc("assign_habit_template", {
      p_trainer_id: trainer.id,
      p_template_id: body.templateId,
      p_client_id: body.clientId,
    });

    if (error) {
      return mapRpcError(c, error, ASSIGN_HABIT_TEMPLATE_ERRORS);
    }

    return c.json({ data: { habitId: data as string } }, 201);
  },
);

app.onError((err, c) => {
  console.error(err);
  return errorResponse(c, "INTERNAL_ERROR", "Something went wrong", 500);
});

Deno.serve(app.fetch);
