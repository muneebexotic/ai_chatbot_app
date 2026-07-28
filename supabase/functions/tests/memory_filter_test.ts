// The R5.2.4 privacy filter — PRD §5.2, §0.5.2, §14.
//
// Run:  deno test supabase/functions/tests/
//
// R5.2.4 names eight categories that must never be stored and requires two
// mechanisms: a deny-instruction in the extraction prompt and a server-side
// keyword filter. §0.5.2 puts those categories on the closed list, which makes
// this the one file in the project where over-rejection is the correct answer
// and a false negative is a product failure rather than a bug.
//
// A live run against kalaam-dev already showed the prompt half working: a
// transcript mentioning anxiety medication, a spouse, and a salary figure
// produced three clean facts. That is evidence the model complied once. It is
// not evidence the filter would have caught it if the model had not, which is
// the entire reason R5.2.4 asks for both — so the filter is tested here
// against inputs the model is assumed to have already failed on.

import { assertEquals } from 'jsr:@std/assert@1';
import {
  EXTRACTION_PROMPT,
  filterMemories,
  SENSITIVE_PATTERNS,
} from '../_shared/memory_filter.ts';

function assertRejected(fact: string, category: string) {
  const { kept, rejected } = filterMemories([fact]);
  assertEquals(kept, [], `should not have kept: ${fact}`);
  assertEquals(rejected[0]?.category, category, `wrong category for: ${fact}`);
}

function assertKept(fact: string) {
  const { kept } = filterMemories([fact]);
  assertEquals(kept, [fact], `should have kept: ${fact}`);
}

// ── The eight categories in R5.2.4, one test each ───────────────────────────

Deno.test('health conditions are rejected', () => {
  assertRejected('They take medication for anxiety before interviews.', 'health');
  assertRejected('They were diagnosed with ADHD last year.', 'health');
  assertRejected('They are recovering from surgery and speak slowly.', 'health');
});

Deno.test('religion is rejected', () => {
  assertRejected('They practise their prayers five times a day.', 'religion');
  assertRejected('They are fasting during Ramadan this month.', 'religion');
  assertRejected('They attend church every Sunday morning.', 'religion');
});

Deno.test('political views are rejected', () => {
  assertRejected('They voted in the last election and follow politics.', 'politics');
  assertRejected('They hold conservative views on most subjects.', 'politics');
});

Deno.test('sexual orientation is rejected', () => {
  assertRejected('They mentioned coming out to their team recently.', 'sexualOrientation');
  assertRejected('They are bisexual and practising interview answers.', 'sexualOrientation');
});

Deno.test('financial details are rejected', () => {
  assertRejected('They earn 90000 dollars and want a raise.', 'finances');
  assertRejected('Their salary expectation is high for the role.', 'finances');
  assertRejected('They are paying off a student loan.', 'finances');
  assertRejected('They want to negotiate a bonus of $10000.', 'finances');
});

Deno.test('government identifiers are rejected', () => {
  assertRejected('Their passport is being renewed before the trip.', 'governmentId');
  assertRejected('They gave their CNIC number during the call.', 'governmentId');
});

Deno.test('exact addresses are rejected', () => {
  assertRejected('They live at 42 Maple Street near the office.', 'address');
  assertRejected('They asked about the postcode for the venue.', 'address');
});

Deno.test('facts about third parties are rejected', () => {
  // "anything about third parties" is the vaguest clause in R5.2.4 and the
  // easiest to under-implement. Possessives naming another person are the
  // reachable signal: this app has no business remembering someone's spouse.
  assertRejected('Their wife thinks they should skip the interview.', 'thirdParty');
  assertRejected('They practise with my colleague on weekends.', 'thirdParty');
  assertRejected('They are helping my daughter with her homework.', 'thirdParty');
});

// ── What must survive ───────────────────────────────────────────────────────
//
// The other half of the argument. A filter that rejects everything satisfies
// R5.2.4 and destroys R5.2.3, which is what makes the partner feel like it
// remembers anything at all.

Deno.test('durable first-person practice facts are kept', () => {
  assertKept('They are preparing for a frontend interview.');
  assertKept('They have two years of React experience.');
  assertKept('They want to practise thinking out loud.');
  assertKept('They find it hard to speak without filler words.');
  assertKept('They prefer short sessions in the evening.');
  assertKept('They are learning English for university admission.');
});

// ── Shape ───────────────────────────────────────────────────────────────────

Deno.test('a paragraph is rejected on length', () => {
  // A model ignoring "one short sentence" usually does so by returning a slab
  // of the transcript, and a slab is far likelier to carry a banned category
  // than a nine-word fact is. The length bound is a privacy control, not
  // tidiness.
  assertRejected('They said: ' + 'a lot of words '.repeat(20), 'length');
});

Deno.test('a fragment is rejected on length', () => {
  assertRejected('They.', 'length');
});

Deno.test('at most three facts survive, and duplicates collapse', () => {
  const { kept } = filterMemories([
    'They are preparing for a frontend interview.',
    'THEY ARE PREPARING FOR A FRONTEND INTERVIEW.',
    'They have two years of React experience.',
  ]);
  assertEquals(kept.length, 2);
});

Deno.test('whitespace is normalised before matching', () => {
  // Otherwise "their   wife" slips past a pattern written with single spaces.
  assertRejected('Their    wife  thinks   they should skip it.', 'thirdParty');
});

Deno.test('one banned fact does not take the clean ones with it', () => {
  const { kept, rejected } = filterMemories([
    'They are preparing for a frontend interview.',
    'They take medication for anxiety.',
    'They have two years of React experience.',
  ]);
  assertEquals(kept.length, 2);
  assertEquals(rejected.length, 1);
});

// ── The two halves must name the same categories ────────────────────────────

Deno.test('the prompt deny-list covers every filtered category', () => {
  // R5.2.4 requires both mechanisms, and the failure mode is that someone adds
  // a category to one and forgets the other. The gap is invisible until it is
  // a stored fact, so it is asserted here instead.
  const inPrompt: Record<keyof typeof SENSITIVE_PATTERNS, string> = {
    health: 'health conditions',
    religion: 'religion',
    politics: 'political views',
    sexualOrientation: 'sexual orientation',
    finances: 'financial details',
    governmentId: 'government identifiers',
    address: 'exact addresses',
    thirdParty: 'anything about another person',
  };

  for (const category of Object.keys(SENSITIVE_PATTERNS)) {
    const phrase = inPrompt[category as keyof typeof SENSITIVE_PATTERNS];
    assertEquals(
      typeof phrase === 'string' && EXTRACTION_PROMPT.includes(phrase),
      true,
      `the extraction prompt does not mention "${category}"`,
    );
  }

  // And the reverse: every category the filter knows about is one of the eight.
  assertEquals(Object.keys(SENSITIVE_PATTERNS).length, 8);
});
