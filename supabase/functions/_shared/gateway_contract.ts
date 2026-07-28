// The wire contract between the client and the gateway — PRD §9.3, F4.
//
// Kept in one file, imported by the gateway and by its tests, so the error
// codes the server emits and the codes the client maps to `AppFailure` cannot
// drift apart. R11.5 requires the UI to say something specific for offline,
// rate-limited, quota-exceeded, safety-blocked, and unknown; that is only true
// if both ends agree on the words.

/// Everything the client is permitted to send.
///
/// R9.3.2: "The client MUST NOT be able to influence the model, temperature,
/// system prompt, or safety settings by request parameters. It sends: partner
/// id, thread id, and user text. Everything else is server-decided."
///
/// This type is the whole allowlist. A field that is not here is not read, and
/// `validateRequest` rejects unknown keys outright rather than ignoring them —
/// silently dropping `{"model": "..."}` teaches an attacker nothing, while
/// rejecting it tells an honest client its bug immediately.
export interface GatewayRequest {
  /// Null starts a new thread. Any other value must be a thread the caller
  /// owns; ownership is checked server-side, never assumed from the id.
  threadId: string | null;
  partnerId: string;
  text: string;
}

/// Error codes, chosen to map one-to-one onto `AppFailure` in the client.
export type GatewayErrorCode =
  | 'unauthorized'
  | 'email_not_confirmed'
  | 'invalid_request'
  | 'rate_limited'
  | 'quota_exceeded'
  | 'at_capacity'
  | 'safety_blocked'
  | 'upstream_failed'
  | 'server_misconfigured';

export interface GatewayError {
  code: GatewayErrorCode;
  /// Machine-readable detail. Never a message for a person: §7.6 copy lives in
  /// the client's ARB files, because the server cannot know the user's locale
  /// at the granularity the UI does, and a translated string baked into an API
  /// response is a string no translator will ever find.
  field?: string;
  retryAfterSeconds?: number;
  resetsAt?: string;
  upgradeable?: boolean;
}

/// Hard caps on the one free-text field the client controls.
///
/// 4000 characters is roughly 1000 tokens, which keeps a single hostile
/// request from eating a meaningful share of the 12K tokens-per-minute free
/// tier by itself.
export const MAX_TEXT_LENGTH = 4000;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type ValidationResult =
  | { ok: true; value: GatewayRequest }
  | { ok: false; error: GatewayError };

/// Schema validation for a hostile caller (R9.3.2).
///
/// Exported and pure so it can be tested without a server, a database, or a
/// network — §14 requires request-validation tests for every Edge Function,
/// and a validator that can only be exercised through a deployed function is
/// one nobody exercises.
export function validateRequest(body: unknown): ValidationResult {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return { ok: false, error: { code: 'invalid_request', field: 'body' } };
  }

  const record = body as Record<string, unknown>;

  // Reject unknown keys rather than ignoring them. An accepted-and-ignored
  // `{"tier": "pro"}` looks to the sender exactly like an accepted-and-honoured
  // one, and §14 requires proving a forged premium claim is rejected — not
  // merely that it has no effect.
  const allowed = new Set(['threadId', 'partnerId', 'text']);
  for (const key of Object.keys(record)) {
    if (!allowed.has(key)) {
      return { ok: false, error: { code: 'invalid_request', field: key } };
    }
  }

  const { threadId, partnerId, text } = record;

  if (threadId !== null && threadId !== undefined) {
    if (typeof threadId !== 'string' || !UUID.test(threadId)) {
      return { ok: false, error: { code: 'invalid_request', field: 'threadId' } };
    }
  }

  if (typeof partnerId !== 'string' || !UUID.test(partnerId)) {
    return { ok: false, error: { code: 'invalid_request', field: 'partnerId' } };
  }

  if (typeof text !== 'string') {
    return { ok: false, error: { code: 'invalid_request', field: 'text' } };
  }

  const trimmed = text.trim();
  if (trimmed.length === 0 || trimmed.length > MAX_TEXT_LENGTH) {
    return { ok: false, error: { code: 'invalid_request', field: 'text' } };
  }

  return {
    ok: true,
    value: {
      threadId: (threadId as string | null | undefined) ?? null,
      partnerId,
      text: trimmed,
    },
  };
}

/// Turns the first user message into a thread title.
///
/// Deliberately not a model call. A title is decoration, and RESEARCH.md §4.A
/// puts the free-tier breach point at 8-48 daily active users — spending a
/// request per thread on a label is the wrong place for scarce quota. It also
/// removes a whole class of failure: a title cannot be slow, refused, or
/// hallucinated if no model produced it.
///
/// Exported for the same reason as `validateRequest`: it is pure, so it is
/// testable.
export function deriveTitle(text: string): string {
  const firstLine = text.split('\n').map((l) => l.trim()).find((l) => l.length > 0) ?? '';
  const collapsed = firstLine.replace(/\s+/g, ' ');
  if (collapsed.length <= 48) return collapsed;

  // Cut at a word boundary, not mid-word. An ellipsis is added only when
  // something was actually removed.
  const cut = collapsed.slice(0, 48);
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > 24 ? cut.slice(0, lastSpace) : cut).trimEnd()}...`;
}
