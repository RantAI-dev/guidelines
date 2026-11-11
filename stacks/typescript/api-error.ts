// The one place that turns an error into a response. Copy it beside the generated
// error-codes.ts (see .agents/error-codes.tsv) and have every route return through it.
// It uses the standard Response, so it works in Bun, Next.js route handlers and Hono.
import { ERROR_CODES, type ErrorCode } from "./error-codes";

export type FieldError = {
  /** A JSON Pointer into the body ("/items/0/quantity"), or the name of a query or path parameter. */
  field: string;
  code: string;
  message: string;
};

export type ApiError = {
  code: ErrorCode;
  /** A more specific sentence than the registry's. Never exception text. */
  message?: string;
  /** Only with invalid_request: every bad field, not only the first. */
  errors?: FieldError[];
  details?: Record<string, unknown>;
  retryAfterSeconds?: number;
};

const SAFE_REQUEST_ID = /^[A-Za-z0-9._-]{1,128}$/;

/** The caller's X-Request-Id when it is safe to echo, otherwise a new one. */
export function requestIdOf(request: Request): string {
  const sent = request.headers.get("x-request-id");
  return sent !== null && SAFE_REQUEST_ID.test(sent) ? sent : crypto.randomUUID();
}

export function errorResponse(error: ApiError, requestId: string): Response {
  const entry = ERROR_CODES[error.code];
  // A 5xx never carries a caller-supplied sentence: the cause belongs in the log.
  const message = entry.status >= 500 ? entry.message : (error.message ?? entry.message);
  const headers = new Headers({ "content-type": "application/json", "x-request-id": requestId });
  if (entry.status === 401) headers.set("www-authenticate", "Bearer");
  if (error.retryAfterSeconds !== undefined) {
    headers.set("retry-after", String(error.retryAfterSeconds));
  }
  const body = {
    error: {
      code: error.code,
      message,
      requestId,
      ...(error.errors !== undefined && error.errors.length > 0 ? { errors: error.errors } : {}),
      ...(error.details !== undefined ? { details: error.details } : {}),
    },
  };
  return new Response(JSON.stringify(body), { status: entry.status, headers });
}
