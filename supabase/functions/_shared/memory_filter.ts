// The server-side half of R5.2.4 — PRD §5.2, §0.5.2.
//
// "Never store, and actively filter out of extraction: health conditions,
//  religion, political views, sexual orientation, financial details, government
//  ID numbers, exact addresses, or anything about third parties. Implement as
//  an explicit deny-instruction in the extraction prompt PLUS a server-side
//  keyword filter, and document both."
//
// The requirement asks for both halves on purpose, and the reason is worth
// stating: a prompt is a request and a filter is a control. A model told not to
// extract health information will usually comply, and "usually" is not a
// privacy guarantee. §0.5.2 puts these categories on the closed list — the one
// place where exceeding the spec is a failure rather than initiative — so the
// deterministic half has to exist even though the probabilistic half is better
// at nuance.
//
// ## What this filter is, and what it is not
//
// It is a blunt keyword reject over the *candidate* facts, applied before
// anything is written. It is not a classifier and does not try to be: a
// classifier that is right 95% of the time still writes a stranger's religion
// into a database once in twenty times, and there is no threshold at which
// that becomes acceptable for the categories §0.5.2 closes.
//
// It over-rejects. "I want to talk about my finances in the interview" is a
// legitimate practice goal and this drops it. That trade is deliberate and is
// the correct direction: the cost of over-rejecting is a memory the app did not
// keep, and the cost of under-rejecting is a category the PRD says must never
// be stored.

/// Categories from R5.2.4, each with the words that indicate it.
///
/// Kept as a labelled map rather than one flat list so a rejection can be
/// logged with the reason — an `abuse_events` row reading "memory_rejected:
/// health" is reviewable, while "memory_rejected" is not.
// Stems, not whole words. `\bpray\b` does not match "prayers", which is how
// the first version of this file passed its own review and then let
// "They practise their prayers five times a day" straight through. Every entry
// below is a prefix followed by `\w*`, so a plural or an inflection cannot slip
// under a word boundary.
const stems = (...words: string[]) =>
  new RegExp(String.raw`\b(${words.join('|')})\w*`, 'i');

export const SENSITIVE_PATTERNS: Record<string, RegExp> = {
  health: stems(
    'diagnos', 'symptom', 'illness', 'disease', 'disorder', 'depress',
    'anxiet', 'anxious', 'therap', 'psychiatr', 'psycholog', 'medicat',
    'medicine', 'prescri', 'surger', 'cancer', 'diabet', 'asthma', 'adhd',
    'autis', 'disabilit', 'disabled', 'pregnan', 'hospital', 'clinic',
    'doctor', 'chronic', 'insomnia', 'migraine', 'stutter', 'stammer',
  ),
  religion: stems(
    'muslim', 'islam', 'christian', 'catholic', 'protestant', 'hindu', 'sikh',
    'buddhis', 'jewish', 'judaism', 'jain', 'atheis', 'agnostic', 'church',
    'mosque', 'masjid', 'synagogue', 'gurdwara', 'pray', 'namaz', 'salah',
    'ramadan', 'ramzan', 'diwali', 'shabbat', 'religio', 'worship', 'scriptur',
  ),
  politics: stems(
    'politic', 'vote', 'voting', 'voted', 'election', 'conservative',
    'liberal', 'socialis', 'communis', 'republican', 'democrat', 'activis',
    'protest', 'left-wing', 'right-wing',
  ),
  sexualOrientation: stems(
    'gay', 'lesbian', 'bisexual', 'bi-sexual', 'queer', 'lgbt', 'transgender',
    'nonbinary', 'non-binary', 'asexual', 'heterosexual', 'homosexual',
    'closeted', 'coming out', 'came out to', 'sexual orientation',
    'gender identity',
    // "straight" is deliberately absent. It is far more often an adverb
    // ("They answered straight away") than a disclosure, and a rule that fires
    // on ordinary English is a rule someone turns off.
  ),
  finances: new RegExp(
    // Currency amounts have no useful stem, so this one keeps an explicit
    // alternation alongside the stems.
    String.raw`\b(salar|salaries|wage|income|debt|loan|mortgage|bank|saving|` +
      String.raw`invest|bankrupt|paycheck|pay ?slip|bonus|earn|afford|` +
      String.raw`credit card|net worth)\w*` +
      String.raw`|\$\s?\d|₹\s?\d|£\s?\d|€\s?\d|\brs\.? ?\d|\b\d[\d,]{3,}\s*(dollars|rupees|pounds|euros)\b`,
    'i',
  ),
  governmentId: new RegExp(
    String.raw`\b(passport|national id|nic|cnic|aadhaar|aadhar|ssn|social security|` +
      String.raw`driver'?s licen[cs]e|licen[cs]e number|tax id|visa number)\w*`,
    'i',
  ),
  address: new RegExp(
    String.raw`\b(\d+\s+[a-z]+\s+(street|st\.|road|rd\.|avenue|ave\.|lane|ln\.|drive|dr\.|block|sector)` +
      String.raw`|apartment \d|flat \d|house (number|no\.?) ?\d|postcode|post code|zip ?code|pin ?code)`,
    'i',
  ),
  // "anything about third parties".
  //
  // A possessive naming another person is the reachable signal. Note the
  // determiner list: the first version matched only "my wife", which is the
  // form a *user* uses — but the extraction prompt asks for third-person facts,
  // so what actually reaches this filter is "Their wife thinks...". The rule
  // was written against the wrong speaker and would have stored every one of
  // these. Caught by a test, not by reading it back.
  thirdParty: new RegExp(
    String.raw`\b(my|their|his|her|our|your)\s+` +
      String.raw`(wife|husband|partner|girlfriend|boyfriend|fianc|son|daughter|child|children|` +
      String.raw`kid|kids|mother|father|mom|mum|dad|parent|parents|brother|sister|sibling|` +
      String.raw`friend|colleague|coworker|co-worker|boss|manager|teacher|neighbou?r|family)\w*`,
    'i',
  ),
};

export interface FilterResult {
  kept: string[];
  rejected: { content: string; category: string }[];
}

/// Length bounds for a "short string" (R5.2.1).
///
/// The upper bound is not tidiness. A model that ignores the instruction to
/// produce a short fact usually does so by returning a paragraph of the
/// transcript, and a paragraph is far more likely to carry something the
/// categories above forbid than a nine-word fact is.
const MIN_LENGTH = 8;
const MAX_LENGTH = 160;

/// Applies R5.2.4 to a list of candidate facts.
export function filterMemories(candidates: string[]): FilterResult {
  const kept: string[] = [];
  const rejected: { content: string; category: string }[] = [];

  for (const raw of candidates) {
    const content = raw.trim().replace(/\s+/g, ' ');

    if (content.length < MIN_LENGTH || content.length > MAX_LENGTH) {
      rejected.push({ content, category: 'length' });
      continue;
    }

    let matched: string | null = null;
    for (const [category, pattern] of Object.entries(SENSITIVE_PATTERNS)) {
      if (pattern.test(content)) {
        matched = category;
        break;
      }
    }

    if (matched) {
      rejected.push({ content, category: matched });
      continue;
    }

    // Case-insensitive de-duplication within one extraction. The model is
    // asked for three facts and will sometimes return the same one twice in
    // different words; exact-match is all this can catch, and the caller
    // de-duplicates against stored rows separately.
    if (kept.some((k) => k.toLowerCase() === content.toLowerCase())) continue;

    kept.push(content);
  }

  return { kept, rejected };
}

/// The prompt half of R5.2.4.
///
/// Exported so the deny-instruction and the keyword filter can be read side by
/// side, and so a test can assert the two name the same categories. They drift
/// otherwise: someone adds a category to one list and not the other, and the
/// gap is invisible until it is a stored fact.
export const EXTRACTION_PROMPT = `You extract durable facts a speaking-practice app should remember about a user.

Read the conversation and return at most 3 facts the user stated about THEMSELVES that would still be true and useful next week. Good facts: their goal, their level, what they are preparing for, how they like to practise, what they find hard.

NEVER extract, in any form, even if the user volunteers it:
- health conditions, symptoms, diagnoses, medication, or disability
- religion, religious practice, or observance
- political views, party, or voting
- sexual orientation or gender identity
- financial details: salary, income, debt, savings, or any amount of money
- government identifiers: passport, national id, tax, licence numbers
- exact addresses or postcodes
- anything about another person, including family and colleagues

If a fact would require one of the above to make sense, leave it out entirely rather than rephrasing it.

Write each fact as one short sentence in the third person, starting with "They". No names. No dates. No quotes from the conversation.

Return only a JSON object of the form {"facts": ["...", "..."]}. Return {"facts": []} if there is nothing durable to remember, which is the normal outcome for a short conversation.`;
