// coaching-api -- per CLAUDE.md's hybrid backend pattern. Two routes:
// start-conversation (Milestone 6) and redeem-invite (Milestone 7), the two
// coaching-relationship writes that can't be plain RLS (see migration 018's
// and migration 022's header notes). Reading a trainer's own
// coaching_relationships stays a direct RLS read from the app (see
// coaching_relationships_repository.dart).
import { Hono } from "npm:hono";
import { zValidator } from "npm:@hono/zod-validator";
import { z } from "npm:zod";
import type { ContentfulStatusCode } from "npm:hono/utils/http-status";

import { type AuthEnv, authMiddleware, requireRole } from "../_shared/auth.ts";
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

const redeemInviteSchema = z.object({
  code: z
    .string()
    .trim()
    .min(1)
    .transform((v) => v.toUpperCase()),
});

const REDEEM_INVITE_ERRORS: Record<string, { status: ContentfulStatusCode; message: string }> = {
  CLIENT_NOT_FOUND: { status: 404, message: "Client profile not found" },
  INVITE_NOT_FOUND: { status: 404, message: "That invite code doesn't exist" },
  INVITE_REVOKED: { status: 409, message: "This invite has been revoked" },
  INVITE_EXPIRED: { status: 409, message: "This invite has expired" },
  INVITE_MAX_USES_REACHED: { status: 409, message: "This invite has already reached its maximum number of uses" },
  SUBSCRIPTION_INACTIVE: { status: 409, message: "This coach/gym's subscription isn't active right now" },
  SEATS_FULL: { status: 409, message: "This coach/gym has no seats left -- ask them to upgrade their plan" },
  INVITE_CREATOR_NOT_A_TRAINER: { status: 409, message: "This invite can't be redeemed right now -- contact the gym" },
  ALREADY_CONNECTED: { status: 409, message: "You're already connected with this coach" },
};

// Client only -- §13 lists this as "POST, client app". A trainer/org side
// never redeems its own invite.
app.post(
  "/redeem-invite",
  requireRole("client"),
  zValidator("json", redeemInviteSchema),
  async (c) => {
    const user = c.get("user");
    const body = c.req.valid("json");

    const { data, error } = await supabaseAdmin.rpc("redeem_invite", {
      p_client_id: user.id,
      p_code: body.code,
    });

    if (error) {
      return mapRpcError(c, error, REDEEM_INVITE_ERRORS);
    }

    return c.json({ data: { relationshipId: data as string } }, 201);
  },
);

app.onError((err, c) => {
  console.error(err);
  return errorResponse(c, "INTERNAL_ERROR", "Something went wrong", 500);
});

Deno.serve(app.fetch);
