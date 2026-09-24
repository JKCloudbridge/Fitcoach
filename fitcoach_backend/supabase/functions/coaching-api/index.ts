// coaching-api -- per CLAUDE.md's hybrid backend pattern. First route in this
// function: start-conversation (Milestone 6), the one messaging write that
// can't be plain RLS (see migration 018's header note -- bootstrapping a
// conversation_members row for someone else has no existing membership row to
// authorize itself against, and it needs to validate an active
// coaching_relationship first anyway). Reading a trainer's own
// coaching_relationships stays a direct RLS read from the app (see
// coaching_relationships_repository.dart) -- redeem-invite and the rest of
// this function's eventual routes are Milestone 7's gym-seat work, not built
// yet.
import { Hono } from "npm:hono";
import { zValidator } from "npm:@hono/zod-validator";
import { z } from "npm:zod";
import type { ContentfulStatusCode } from "npm:hono/utils/http-status";

import { type AuthEnv, authMiddleware } from "../_shared/auth.ts";
import { errorResponse, mapRpcError } from "../_shared/errors.ts";
import { supabaseAdmin } from "../_shared/supabaseAdmin.ts";

const app = new Hono<AuthEnv>().basePath("/coaching-api");

app.use("/*", authMiddleware);

const startConversationSchema = z.object({
  otherUserId: z.string().uuid(),
});

const START_CONVERSATION_ERRORS: Record<string, { status: ContentfulStatusCode; message: string }> = {
  CANNOT_MESSAGE_SELF: { status: 400, message: "You can't start a conversation with yourself" },
  NO_ACTIVE_RELATIONSHIP: { status: 409, message: "You don't have an active coaching relationship with this person" },
};

// Either role can call this -- a client messaging their trainer and a trainer
// messaging their client are the same operation from start_conversation()'s
// point of view, since it checks the relationship in both directions.
app.post(
  "/start-conversation",
  zValidator("json", startConversationSchema),
  async (c) => {
    const user = c.get("user");
    const body = c.req.valid("json");

    const { data, error } = await supabaseAdmin.rpc("start_conversation", {
      p_user_id: user.id,
      p_other_user_id: body.otherUserId,
    });

    if (error) {
      return mapRpcError(c, error, START_CONVERSATION_ERRORS);
    }

    return c.json({ data: { conversationId: data as string } }, 201);
  },
);

app.onError((err, c) => {
  console.error(err);
  return errorResponse(c, "INTERNAL_ERROR", "Something went wrong", 500);
});

Deno.serve(app.fetch);
