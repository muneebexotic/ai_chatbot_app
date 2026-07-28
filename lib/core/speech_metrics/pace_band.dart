/// The "healthy band" R4.3.1 attaches to speaking pace.
///
/// R4.3.1 asks for "speaking pace in words per minute with a healthy band". A
/// bare number is not actionable — nobody knows whether 138 wpm is good — and a
/// single target would be worse, because there is no single correct speaking
/// rate. A band says "you are inside the range where listeners follow you
/// comfortably" and leaves everything inside it equally fine.
///
/// ## Where the numbers come from
///
/// Conversational English sits around 140–160 wpm; deliberate presentation
/// delivery is slower, around 120–150. The band below spans both because a
/// single session may be either — Free Talk and Presentation Coach are the same
/// screen — and because the cost of a false "too fast" is a user slowing down
/// past the point of sounding natural.
///
/// These are guidance figures, not a measured population for this app's users.
/// When there is real session data, this is the first thing that should be
/// re-derived from it, and [SpeechPaceBand.conversational] is the only place
/// that would change.
library;

/// Where a measured pace falls.
enum PaceBand {
  /// Below the band. Deliberate; can read as hesitant if it is very low.
  slow,

  /// Inside the band.
  comfortable,

  /// Above the band. The most common finding in interview practice, and the
  /// one users can act on fastest.
  fast,

  /// Not enough speech to compute a rate at all.
  ///
  /// Distinct from [slow] on purpose: "you spoke too slowly" is a judgement,
  /// and applying it to somebody who said four words would be a fabricated
  /// finding. The UI must say "not enough speech yet" instead.
  noData,
}

/// The band itself, so a locale or a partner can carry a different one later.
class SpeechPaceBand {
  const SpeechPaceBand({required this.lower, required this.upper});

  final double lower;
  final double upper;

  /// The default band. See the library comment for provenance.
  static const conversational = SpeechPaceBand(lower: 120, upper: 165);

  /// Below this many words there is no honest rate to report. A four-word
  /// answer timed over 1.2s extrapolates to 200 wpm, which is arithmetic
  /// rather than information.
  static const minimumWordsForPace = 25;

  PaceBand classify(double wordsPerMinute, {required int wordsSpoken}) {
    if (wordsSpoken < minimumWordsForPace || wordsPerMinute <= 0) {
      return PaceBand.noData;
    }
    if (wordsPerMinute < lower) return PaceBand.slow;
    if (wordsPerMinute > upper) return PaceBand.fast;
    return PaceBand.comfortable;
  }
}
