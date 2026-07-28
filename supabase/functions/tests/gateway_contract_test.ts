// Request-validation tests for the gateway — PRD §14.
//
// "every Edge Function has request-validation tests"
//
// Run:  deno test supabase/functions/tests/
//
// These exercise the pure half of the gateway: the schema validator and the
// title derivation. Nothing here touches a network, a database, or a model, so
// the whole file runs in well under a second and can be part of the ordinary
// loop rather than a thing someone remembers to do.
//
// The half that is not covered here is the streaming loop, which needs a real
// upstream. That gap is named in CRITIQUE.md rather than papered over with a
// mock of the provider's SSE format — a mock of a format is a test of my
// understanding of the format, which is the thing most likely to be wrong.

import { assertEquals } from 'jsr:@std/assert@1';
import {
  deriveTitle,
  MAX_TEXT_LENGTH,
  validateRequest,
} from '../_shared/gateway_contract.ts';

const PARTNER = '11111111-1111-4111-8111-000000000002';
const THREAD = '3ac627eb-bd1a-4852-a59f-d757bec1feb2';

function rejects(body: unknown, field?: string) {
  const result = validateRequest(body);
  assertEquals(result.ok, false, `expected rejection of ${JSON.stringify(body)}`);
  if (!result.ok) {
    assertEquals(result.error.code, 'invalid_request');
    if (field) assertEquals(result.error.field, field);
  }
}

Deno.test('accepts the three fields the contract allows', () => {
  const result = validateRequest({
    threadId: THREAD,
    partnerId: PARTNER,
    text: '  hello  ',
  });
  assertEquals(result.ok, true);
  if (result.ok) {
    assertEquals(result.value.threadId, THREAD);
    assertEquals(result.value.partnerId, PARTNER);
    // Trimmed, so a message of spaces cannot become a model call.
    assertEquals(result.value.text, 'hello');
  }
});

Deno.test('a null threadId starts a new thread', () => {
  const result = validateRequest({ threadId: null, partnerId: PARTNER, text: 'hi there' });
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.value.threadId, null);
});

Deno.test('an absent threadId is the same as null', () => {
  const result = validateRequest({ partnerId: PARTNER, text: 'hi there' });
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.value.threadId, null);
});

// ── R9.3.2: the client cannot influence the model ───────────────────────────
//
// §14 requires proving "a patched client cannot gain Pro ... by calling the
// gateway directly with a forged client claim of premium status". The reason
// these are rejected rather than ignored is that an accepted-and-ignored field
// is indistinguishable, from the sender's side, from an accepted-and-honoured
// one — and the next person to add a field named `tier` to this API would find
// clients already sending it.

Deno.test('a forged premium claim is rejected, not ignored', () => {
  rejects({ threadId: null, partnerId: PARTNER, text: 'hi', tier: 'pro' }, 'tier');
  rejects({ threadId: null, partnerId: PARTNER, text: 'hi', isPremium: true }, 'isPremium');
  rejects({ threadId: null, partnerId: PARTNER, text: 'hi', entitlement: 'pro' }, 'entitlement');
});

Deno.test('model, temperature, and system prompt are not request fields', () => {
  for (const field of [
    'model',
    'temperature',
    'max_tokens',
    'system',
    'systemPrompt',
    'safetySettings',
    'messages',
    'userId',
  ]) {
    rejects({ threadId: null, partnerId: PARTNER, text: 'hi', [field]: 'x' }, field);
  }
});

// ── Shape ───────────────────────────────────────────────────────────────────

Deno.test('partnerId must be a uuid', () => {
  rejects({ threadId: null, partnerId: 'not-a-uuid', text: 'hi' }, 'partnerId');
  rejects({ threadId: null, partnerId: '', text: 'hi' }, 'partnerId');
  rejects({ threadId: null, partnerId: 42, text: 'hi' }, 'partnerId');
  rejects({ threadId: null, text: 'hi' }, 'partnerId');
  // SQL in a uuid slot has nowhere to go, but it must not reach the query at
  // all — PostgREST parameterises, and this is the belt.
  rejects({ threadId: null, partnerId: "' or 1=1 --", text: 'hi' }, 'partnerId');
});

Deno.test('threadId must be a uuid when present', () => {
  rejects({ threadId: 'nope', partnerId: PARTNER, text: 'hi' }, 'threadId');
  rejects({ threadId: 7, partnerId: PARTNER, text: 'hi' }, 'threadId');
});

Deno.test('empty and whitespace-only text is refused', () => {
  rejects({ threadId: null, partnerId: PARTNER, text: '' }, 'text');
  rejects({ threadId: null, partnerId: PARTNER, text: '   \n\t ' }, 'text');
});

Deno.test('oversized text is refused before it reaches the model', () => {
  // The point of the cap is cost, not tidiness: one hostile request must not
  // be able to eat a meaningful share of a 12K tokens-per-minute free tier.
  const justUnder = 'a'.repeat(MAX_TEXT_LENGTH);
  const justOver = 'a'.repeat(MAX_TEXT_LENGTH + 1);
  assertEquals(validateRequest({ partnerId: PARTNER, text: justUnder }).ok, true);
  rejects({ partnerId: PARTNER, text: justOver }, 'text');
});

Deno.test('non-object bodies are refused', () => {
  rejects(null, 'body');
  rejects('a string', 'body');
  rejects(42, 'body');
  rejects([{ partnerId: PARTNER, text: 'hi' }], 'body');
});

// ── Titles ──────────────────────────────────────────────────────────────────

Deno.test('a short first message becomes the title verbatim', () => {
  assertEquals(deriveTitle('Interview practice'), 'Interview practice');
});

Deno.test('a long first message is cut at a word boundary', () => {
  const title = deriveTitle(
    'I have a frontend interview on Tuesday and I am nervous about the system design part',
  );
  assertEquals(title.endsWith('...'), true);
  assertEquals(title.length <= 51, true);
  // Cut between words, never mid-word — a title reading "system desi..." looks
  // like a bug to the person whose conversation it names.
  assertEquals(title.slice(0, -3).endsWith(' '), false);
  assertEquals(title, 'I have a frontend interview on Tuesday and I am...');
});

Deno.test('whitespace and newlines collapse', () => {
  assertEquals(deriveTitle('\n\n  Hello   there \n more'), 'Hello there');
});

Deno.test('a single long word still produces a usable title', () => {
  const title = deriveTitle('a'.repeat(200));
  assertEquals(title.length, 51);
  assertEquals(title.endsWith('...'), true);
});
