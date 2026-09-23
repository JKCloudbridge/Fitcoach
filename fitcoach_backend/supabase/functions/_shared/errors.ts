// Shared response envelope, matching Proximity's convention:
// { data: ... } on success, { error: { code, message } } on failure.
import type { Context } from "npm:hono";
import type { ContentfulStatusCode } from "npm:hono/utils/http-status";

export class ApiError extends Error {
  constructor(public code: string, message: string, public status: ContentfulStatusCode = 400) {
    super(message);
  }
}

export function errorResponse(c: Context, code: string, message: string, status: ContentfulStatusCode = 400) {
  return c.json({ error: { code, message } }, status);
}

// Maps a Postgres RAISE EXCEPTION message (matched by substring, same
// approach as Proximity's PLACE_ORDER_ERRORS lookup) raised inside a
// security-definer RPC to a typed HTTP error. Falls through to a generic 500
// if nothing matches, since that means the RPC failed in a way this route
// didn't anticipate.
export function mapRpcError(
  c: Context,
  err: unknown,
  table: Record<string, { status: ContentfulStatusCode; message: string }>,
) {
  const raw = err instanceof Error ? err.message : String(err);
  for (const [code, mapped] of Object.entries(table)) {
    if (raw.includes(code)) {
      return errorResponse(c, code, mapped.message, mapped.status);
    }
  }
  console.error(raw);
  return errorResponse(c, "INTERNAL_ERROR", "Something went wrong", 500);
}
