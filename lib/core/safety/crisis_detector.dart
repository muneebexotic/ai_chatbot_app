/// Client-side crisis detection — PRD R10.6.
///
/// R10.6: "If a user's speech indicates crisis or self-harm, the partner must
/// not continue a practice exercise. The system prompt for every partner MUST
/// include an instruction to break character, respond with care, and surface
/// locale-appropriate help resources, **and the client MUST render a persistent
/// card offering those resources**. Implement and test this before launch, not
/// after."
///
/// ## Which half this is
///
/// The server half already exists and is not touched by this file: the crisis
/// instruction lives in `gateway_config.safety_preamble` and is prepended to
/// every partner prompt at request time, before the partner's own text, so a
/// new built-in or a user-authored custom partner (§5.3.2, §6.2) cannot omit or
/// override it.
///
/// This is the client half. It exists separately for three reasons:
///
/// 1. **R10.6's trigger is the user's speech**, not the model's reply. The
///    requirement is about what the person said.
/// 2. **It works offline.** R11.5 allows a session with no network at all, and
///    a crisis does not wait for connectivity.
/// 3. **It does not depend on the model complying.** A model that stays in
///    character is a model that failed the safety instruction; the card must
///    still appear.
///
/// ## Why this is phrases and exclusions rather than a word list
///
/// English is full of idioms that use the vocabulary of death and self-harm to
/// mean nothing of the kind: "I'm dying to know", "this is killing me", "I
/// could kill for a coffee", "dead tired", "career suicide". A substring match
/// on "kill", "die" or "suicide" fires on all of them.
///
/// A false positive here is not a cosmetic bug. It interrupts a practice
/// session to tell somebody that help is available for a problem they do not
/// have, which is alarming, faintly insulting, and teaches them that the app's
/// safety behaviour is noise. Once it is noise it is ignored, which is the
/// precise failure the requirement exists to prevent.
///
/// So the patterns are multi-word and specific, and the idioms that overlap
/// them are excluded explicitly. It is tuned to be quiet rather than eager —
/// with the server-side instruction as the second layer, and a
/// [CrisisSensitivity] the user never sees because R10.6 is not a preference.
library;

/// What a detection matched, so the UI can be tested and logged without storing
/// the sentence.
///
/// **Nothing here carries the user's words.** R5.2.4 forbids storing health
/// information, and a transcript line that triggered this is health information
/// about the most sensitive thing a person can disclose. The category is enough
/// to render the card.
enum CrisisSignal {
  /// Statements of intent or desire to end one's life.
  suicidalIntent,

  /// Statements about hurting oneself without stated lethal intent.
  selfHarm,

  /// Hopelessness severe enough that R10.6's "crisis" applies even without an
  /// explicit statement of intent.
  hopelessness,
}

class CrisisMatch {
  const CrisisMatch(this.signal);

  final CrisisSignal signal;
}

class _Pattern {
  const _Pattern(this.regex, this.signal);
  final RegExp regex;
  final CrisisSignal signal;
}

/// Detects crisis language in what the user said.
///
/// Stateless and pure, like `MetricsEngine` and for the same reasons: it must
/// be testable against a scripted transcript (§14 names exactly that), runnable
/// offline, and free of any dependency on a session being in progress.
class CrisisDetector {
  const CrisisDetector();

  /// Idioms that contain crisis vocabulary and mean nothing of the kind.
  ///
  /// Checked first and applied by *removing* the idiom from the text before the
  /// patterns run, so "I'm dying to know whether I should kill myself" is still
  /// caught — a blanket "contains an idiom, therefore safe" rule would be an
  /// exploit of the safety feature by ordinary English.
  /// Every pattern here is **bounded**. None may consume the rest of the
  /// sentence.
  ///
  /// The first draft ended two of them with `[^.!?]*`, and the test
  /// "I'm dying to know whether I should just kill myself" went silent: the
  /// idiom ate the disclosure that followed it. That is the exploit the note
  /// above this list warns about, reintroduced by the code meant to prevent it.
  /// A trailing wildcard in an exclusion rule is a hole shaped like whatever
  /// comes after the idiom.
  static final _idioms = <RegExp>[
    // "dying to know", "dying to see", "dying for a coffee"
    RegExp(r'\bdying\s+(to|for)\b', caseSensitive: false),
    // "this is killing me", "my back is killing me"
    RegExp(r'\b(is|was|are|were)\s+killing\s+me\b', caseSensitive: false),
    // "I could kill for", "I'd kill for"
    RegExp(r"\b(could|would|'d)\s+kill\s+for\b", caseSensitive: false),
    // "dead tired", "dead serious", "dead easy", "drop dead gorgeous"
    RegExp(
      r'\b(dead\s+(tired|serious|easy|simple|right|wrong|certain|sure|centre|center|end|line|weight)'
      r'|drop\s+dead)\b',
      caseSensitive: false,
    ),
    // "career suicide", "political suicide", "suicide mission/squad/pass"
    RegExp(
      r'\b((career|political|financial|electoral|professional|commercial)\s+suicide'
      r'|suicide\s+(mission|squad|pass|note\s+in\s+a\s+film))\b',
      caseSensitive: false,
    ),
    // "killed it", "killing it" — praise.
    RegExp(r'\b(killed|killing|smashed|nailed)\s+it\b', caseSensitive: false),
    // "died laughing", "I'm dead" as amusement.
    RegExp(r'\bdi(ed|e)\s+laughing\b', caseSensitive: false),
    // Talking ABOUT the topic rather than from inside it — a presentation or an
    // interview answer. "a talk about suicide prevention", "research on
    // self-harm". Narrow on purpose: it requires an explicit framing word.
    //
    // The subject is capped at four words rather than run to the end of the
    // sentence. Long enough for "suicide prevention at my last company", short
    // enough that a disclosure later in the same breath is not swallowed with
    // it — and it stops dead at any punctuation, because `[\w'-]` excludes it.
    RegExp(
      r'\b(presentation|talk|essay|article|paper|research|report|documentary|campaign|'
      r"thesis|dissertation|module|lecture)\s+(on|about)\s+([\w'-]+\s*){0,4}",
      caseSensitive: false,
    ),
  ];

  /// Ordered most specific first. First match wins.
  static final _patterns = <_Pattern>[
    // ── Suicidal intent ────────────────────────────────────────────────────
    _Pattern(
      RegExp(
        r'\bkill(ing)?\s+myself\b'
        r'|\bend(ing)?\s+(my\s+life|it\s+all)\b'
        r'|\btake\s+my\s+own\s+life\b'
        r'|\bi\s+(want|wanna|need|just\s+want)\s+to\s+die\b'
        r'|\bwant\s+to\s+be\s+dead\b'
        // Each of these is complete on its own. An optional "(dead)?" tail
        // would make "I wish I was taller" a crisis disclosure, which is the
        // shape of mistake that trains users to ignore the card.
        r'|\bwish\s+i\s+(was|were)\s+dead\b'
        r"|\bwish\s+i\s+wasn'?t\s+here\b"
        r'|\bwish\s+i\s+had\s+never\s+been\s+born\b'
        r'|\bbetter\s+off\s+dead\b'
        r'|\bbetter\s+off\s+(if\s+i\s+(was|were)\s+)?dead\b'
        r'|\bsuicidal\b'
        r'|\b(commit|committing|attempt(ed|ing)?)\s+suicide\b',
        caseSensitive: false,
      ),
      CrisisSignal.suicidalIntent,
    ),
    // Bare "suicide" survives only after the idiom pass has removed the
    // compound uses ("career suicide", "suicide mission").
    _Pattern(
      RegExp(r'\bsuicide\b', caseSensitive: false),
      CrisisSignal.suicidalIntent,
    ),

    // ── Self-harm ──────────────────────────────────────────────────────────
    _Pattern(
      RegExp(
        r'\bself[\s-]?harm(ing|ed)?\b'
        r'|\bcut(ting)?\s+(myself|my\s+(arms?|wrists?|legs?))\b'
        r'|\bburn(ing|ed|t)?\s+myself\b'
        // "hurt myself" and "harm myself" are self-harm rather than stated
        // suicidal intent, and the distinction is worth keeping: the card is
        // the same, but conflating them would make the signal useless for any
        // later decision that wants to tell them apart.
        r'|\b(hurt(ing)?|harm(ing)?)\s+myself\b'
        r'|\bover\s?dos(e|ing|ed)\b',
        caseSensitive: false,
      ),
      CrisisSignal.selfHarm,
    ),

    // ── Hopelessness ───────────────────────────────────────────────────────
    //
    // R10.6 says "crisis or self-harm", and crisis is broader than a stated
    // plan. These require a first-person subject: "there is no point in
    // anything" from a debate partner rehearsing nihilism is not the same
    // sentence as "I don't see the point in going on".
    _Pattern(
      RegExp(
        r"\b(no|not\s+any)\s+(reason|point)\s+(to|in)\s+(live|living|go(ing)?\s+on|carry(ing)?\s+on)\b"
        r"|\bi\s+(don'?t|do\s+not|can'?t|cannot)\s+(want\s+to\s+|see\s+the\s+point\s+(in|of)\s+)?(live|living|go\s+on|going\s+on|carry\s+on|keep\s+going)\b"
        r"|\bi\s+can'?t\s+(do\s+this|take\s+it)\s+any\s?more\b"
        r"|\bnothing\s+(left\s+)?to\s+live\s+for\b"
        r"|\bi\s+(want|just\s+want)\s+(it|everything)\s+to\s+(stop|end)\b",
        caseSensitive: false,
      ),
      CrisisSignal.hopelessness,
    ),
  ];

  /// Examines one utterance. Returns null when nothing matched.
  CrisisMatch? examine(String text) {
    if (text.trim().isEmpty) return null;

    // Normalise the shapes a recogniser produces: curly apostrophes, repeated
    // whitespace, and no punctuation at all.
    var normalised = text
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'\s+'), ' ');

    // Remove idioms, do not skip the utterance. "I'm dying to know whether I
    // should kill myself" must still be caught.
    for (final idiom in _idioms) {
      normalised = normalised.replaceAll(idiom, ' ');
    }

    for (final pattern in _patterns) {
      if (pattern.regex.hasMatch(normalised)) {
        return CrisisMatch(pattern.signal);
      }
    }
    return null;
  }

  /// Examines a whole transcript, returning the first match.
  ///
  /// Used when a session is recovered from local storage after a force-kill
  /// (R4.2.6): the card must reappear, because the reason for it did not stop
  /// being true when the app died.
  CrisisMatch? examineAll(Iterable<String> utterances) {
    for (final utterance in utterances) {
      final match = examine(utterance);
      if (match != null) return match;
    }
    return null;
  }
}
