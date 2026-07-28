/// Filler-word detection (PRD R4.3.1).
///
/// R4.3.1 asks for "filler-word count and breakdown (um, uh, like, you know,
/// actually, basically, plus configurable per locale)". Two of those words are
/// the whole problem.
///
/// ## Why this is not a word list and a `contains`
///
/// "um" and "uh" are hesitation sounds and are never anything else. "like",
/// "actually" and "basically" are ordinary English words that are *sometimes*
/// discourse fillers, and a naive count reports the user as a much worse
/// speaker than they are:
///
/// * "I like coffee" — a verb.
/// * "it sounds like rain" — a preposition.
/// * "would you like to start" — a verb.
/// * "the numbers actually went up" — an adverb doing real work.
///
/// A filler counter that scores those is worse than no filler counter, because
/// the number appears on a report card, feeds a trend chart (R4.3.5), and is
/// one of the things a user is being asked to improve. Telling somebody to say
/// "like" less when they were using it as a verb is advice that cannot be
/// followed.
///
/// So each filler carries the contexts that *disqualify* it. The rules are
/// cheap surface patterns, not grammar — there is no part-of-speech tagger on
/// the device and R4.3.1 requires this to run locally with no model call. They
/// are tuned to under-report rather than over-report: a missed filler costs the
/// user nothing, and a phantom one costs them trust in every other number on
/// the page.
library;

/// One filler and the rules for when it does not count.
class FillerRule {
  const FillerRule(
    this.phrase, {
    this.notPrecededBy = const [],
    this.notFollowedBy = const [],
    this.clauseInitialOnly = false,
  });

  /// The filler itself, lowercase. May be several words ("you know").
  final String phrase;

  /// Words that, immediately before [phrase], mean it is doing real work.
  final List<String> notPrecededBy;

  /// Words that, immediately after [phrase], mean the same.
  final List<String> notFollowedBy;

  /// Count only when the phrase opens a clause.
  ///
  /// For "actually" the disqualifier lists cannot help: as a filler it opens a
  /// clause ("actually, I think…") and as an adverb it sits inside one ("the
  /// numbers actually went up"), and both can follow any word at all. Position
  /// separates them where a preceding-word list cannot.
  ///
  /// "Opens a clause" is approximated as: the first word of the turn, or
  /// immediately after a coordinating conjunction or a discourse opener. That
  /// is a heuristic, and it errs toward not counting.
  final bool clauseInitialOnly;
}

/// Words that, when they immediately precede a phrase, leave that phrase at the
/// start of a clause. Used by [FillerRule.clauseInitialOnly].
///
/// A recogniser does not reliably emit punctuation, so a comma cannot be part
/// of this test.
const clauseOpeners = <String>{
  'and', 'but', 'so', 'or', 'because', 'well', 'yeah', 'yes', 'no',
  'ok', 'okay', 'right', 'now', 'then', 'um', 'uh', 'erm', 'er',
};

/// The fillers for one locale.
///
/// R4.3.1 says "configurable per locale" — Urdu's fillers are not English's,
/// and the first follow-up locale is Urdu (R11.7). A locale with no entry
/// scores zero fillers rather than scoring English ones against it, because
/// counting English hesitation sounds in Urdu speech would be a number that
/// means nothing presented as if it meant something.
class FillerLexicon {
  const FillerLexicon({required this.locale, required this.rules});

  final String locale;
  final List<FillerRule> rules;

  /// English (R4.3.1's named set, plus the hesitation sounds it implies).
  ///
  /// Order does not matter; matching is longest-phrase-first so "you know"
  /// is never also counted as two separate words.
  static const en = FillerLexicon(
    locale: 'en',
    rules: [
      // ── Unambiguous hesitation sounds ──────────────────────────────────
      // These are not words. Nothing disqualifies them, and they are the
      // measurement a user can act on most directly.
      FillerRule('um'),
      FillerRule('uh'),
      FillerRule('erm'),
      FillerRule('er'),
      FillerRule('hmm'),
      FillerRule('mhm'),

      // ── Discourse markers ──────────────────────────────────────────────
      // Named by R4.3.1, and every one of them has an honest use.
      FillerRule(
        'like',
        // "I/we/you/they like", "would like", "don't like", "really like" —
        // verb. "looks/sounds/feels/seems like" — preposition.
        notPrecededBy: [
          'i', 'we', 'you', 'they', 'he', 'she', 'it', 'who',
          'would', 'wouldn\'t', 'do', 'don\'t', 'does', 'doesn\'t',
          'did', 'didn\'t', 'really', 'not', 'also', 'both',
          'looks', 'look', 'looked', 'sounds', 'sound', 'sounded',
          'feels', 'feel', 'felt', 'seems', 'seem', 'seemed',
          'tastes', 'taste', 'smells', 'smell', 'acts', 'act',
        ],
        // "like to do", "like this/that" as a demonstrative comparison.
        notFollowedBy: ['to'],
      ),
      FillerRule(
        'you know',
        // "you know that", "you know what", "you know how" introduce a real
        // clause; bare "you know" at a boundary is the filler.
        notFollowedBy: ['that', 'what', 'how', 'when', 'where', 'why', 'who', 'if'],
      ),
      FillerRule('i mean'),
      // Scored on position rather than on neighbours — see [clauseInitialOnly].
      FillerRule('actually', clauseInitialOnly: true),
      FillerRule('basically'),
      FillerRule('literally'),
      FillerRule(
        'sort of',
        // "sort of thing", "a sort of X" — noun.
        notPrecededBy: ['a', 'the', 'this', 'that', 'some', 'any', 'what'],
      ),
      FillerRule(
        'kind of',
        notPrecededBy: ['a', 'the', 'this', 'that', 'some', 'any', 'what'],
      ),
    ],
  );

  /// Every lexicon the app knows, by locale code.
  ///
  /// Urdu is absent on purpose rather than by omission: R11.7 ships English
  /// only in v1, and inventing an Urdu filler list without a speaker to check
  /// it against would be a fabricated metric.
  static const Map<String, FillerLexicon> byLocale = {'en': en};

  /// The lexicon for [locale], or null when the app has none.
  ///
  /// Null is meaningful and must not be silently replaced with [en]. The caller
  /// reports "not measured for this language", which is true, instead of a
  /// number that is false.
  static FillerLexicon? forLocale(String locale) {
    final code = locale.split(RegExp('[-_]')).first.toLowerCase();
    return byLocale[code];
  }
}
