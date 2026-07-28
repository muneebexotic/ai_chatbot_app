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

  /// Set when this turn is spoken rather than typed (Milestone 4, §4.2).
  ///
  /// It does NOT let the client choose which budget to spend — that would be
  /// F2 again, in a new coat. The server looks the session up, requires it to
  /// belong to the caller and to be open, and only then treats the turn as
  /// voice. A forged or foreign id is a 400, and a *missing* one simply makes
  /// the turn typed, which is the more expensive of the two for the caller.
  ///
  /// Why the distinction has to exist at all: §8 gives a free user 30 typed
  /// messages AND 10 spoken minutes. Charging a spoken turn to the message
  /// counter would end a ten-minute session at message 30 and would spend the
  /// user's typed allowance on a feature that has its own.
  sessionId: string | null;
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
  const allowed = new Set(['threadId', 'partnerId', 'text', 'sessionId']);
  for (const key of Object.keys(record)) {
    if (!allowed.has(key)) {
      return { ok: false, error: { code: 'invalid_request', field: key } };
    }
  }

  const { threadId, partnerId, text, sessionId } = record;

  if (threadId !== null && threadId !== undefined) {
    if (typeof threadId !== 'string' || !UUID.test(threadId)) {
      return { ok: false, error: { code: 'invalid_request', field: 'threadId' } };
    }
  }

  if (sessionId !== null && sessionId !== undefined) {
    if (typeof sessionId !== 'string' || !UUID.test(sessionId)) {
      return { ok: false, error: { code: 'invalid_request', field: 'sessionId' } };
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
      sessionId: (sessionId as string | null | undefined) ?? null,
    },
  };
}

/// What the client may send to the `session` function (Milestone 4, §4.2).
///
/// The same allowlist discipline as `GatewayRequest`, and for the same reason:
/// this endpoint decides how many minutes a user has left, so every field it
/// reads is a field an attacker gets to choose.
///
/// **There is no duration field anywhere in this type.** F2 requires quota to
/// be computed server-side, and a client-reported "I spoke for 12 seconds" is
/// the exact shape of the defect. Seconds are measured by the database clock in
/// `meter_voice_session`.
export type SessionAction = 'open' | 'heartbeat' | 'close';

export interface SessionRequest {
  action: SessionAction;
  /// Required for heartbeat and close, absent for open.
  sessionId: string | null;
  /// Required for open.
  partnerId: string | null;
  threadId: string | null;
  /// R4.1.3's optional one-line goal ("I have a frontend interview on
  /// Tuesday"), stored on the session record and passed into the prompt.
  goal: string | null;
  /// R4.3.1 metrics, computed on the device. Stored, never trusted for quota.
  metrics: Record<string, unknown> | null;
  /// The session length the user saw, for the report. Also not trusted for
  /// quota — `metered_seconds` is.
  durationSeconds: number | null;
}

/// R4.1.3: "an optional one-line goal". One line, and short enough that it
/// cannot become a prompt-injection payload smuggled in as a goal.
export const MAX_GOAL_LENGTH = 200;

export type SessionValidation =
  | { ok: true; value: SessionRequest }
  | { ok: false; error: GatewayError };

export function validateSessionRequest(body: unknown): SessionValidation {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return { ok: false, error: { code: 'invalid_request', field: 'body' } };
  }

  const record = body as Record<string, unknown>;

  const allowed = new Set([
    'action',
    'sessionId',
    'partnerId',
    'threadId',
    'goal',
    'metrics',
    'durationSeconds',
  ]);
  for (const key of Object.keys(record)) {
    if (!allowed.has(key)) {
      return { ok: false, error: { code: 'invalid_request', field: key } };
    }
  }

  const action = record.action;
  if (action !== 'open' && action !== 'heartbeat' && action !== 'close') {
    return { ok: false, error: { code: 'invalid_request', field: 'action' } };
  }

  const optionalUuid = (value: unknown, field: string): GatewayError | null => {
    if (value === null || value === undefined) return null;
    if (typeof value !== 'string' || !UUID.test(value)) {
      return { code: 'invalid_request', field };
    }
    return null;
  };

  for (const [value, field] of [
    [record.sessionId, 'sessionId'],
    [record.partnerId, 'partnerId'],
    [record.threadId, 'threadId'],
  ] as const) {
    const error = optionalUuid(value, field);
    if (error) return { ok: false, error };
  }

  // `open` needs a partner; `heartbeat` and `close` need a session. Checking
  // this here rather than in the handler keeps the whole shape in one testable
  // function (§14).
  if (action === 'open' && typeof record.partnerId !== 'string') {
    return { ok: false, error: { code: 'invalid_request', field: 'partnerId' } };
  }
  if (action !== 'open' && typeof record.sessionId !== 'string') {
    return { ok: false, error: { code: 'invalid_request', field: 'sessionId' } };
  }

  let goal: string | null = null;
  if (record.goal !== null && record.goal !== undefined) {
    if (typeof record.goal !== 'string') {
      return { ok: false, error: { code: 'invalid_request', field: 'goal' } };
    }
    // Collapse newlines: R4.1.3 says one line, and a multi-line "goal" is the
    // natural place to paste an instruction block at the partner prompt.
    goal = record.goal.replace(/\s+/g, ' ').trim();
    if (goal.length > MAX_GOAL_LENGTH) {
      return { ok: false, error: { code: 'invalid_request', field: 'goal' } };
    }
    if (goal.length === 0) goal = null;
  }

  let metrics: Record<string, unknown> | null = null;
  if (record.metrics !== null && record.metrics !== undefined) {
    if (
      typeof record.metrics !== 'object' ||
      Array.isArray(record.metrics)
    ) {
      return { ok: false, error: { code: 'invalid_request', field: 'metrics' } };
    }
    metrics = record.metrics as Record<string, unknown>;
  }

  let durationSeconds: number | null = null;
  if (record.durationSeconds !== null && record.durationSeconds !== undefined) {
    const value = record.durationSeconds;
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) {
      return {
        ok: false,
        error: { code: 'invalid_request', field: 'durationSeconds' },
      };
    }
    durationSeconds = Math.floor(value);
  }

  return {
    ok: true,
    value: {
      action,
      sessionId: (record.sessionId as string | null | undefined) ?? null,
      partnerId: (record.partnerId as string | null | undefined) ?? null,
      threadId: (record.threadId as string | null | undefined) ?? null,
      goal,
      metrics,
      durationSeconds,
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
