/// Turns a stream of model tokens into speakable sentences (PRD R4.2.4).
///
/// R4.2.4: "from end-of-user-speech to first audible AI word, target under 1.5s
/// on a mid-range Android on 4G. Achieve it by streaming the model response and
/// beginning text-to-speech on the first complete sentence rather than waiting
/// for the full response."
///
/// That sentence is the entire justification for this class. A 70-word reply at
/// Groq's speed takes well over a second to finish generating, and waiting for
/// it spends the whole latency budget before the first phoneme. Speaking the
/// first sentence the moment it is complete moves the budget from "time to
/// generate a reply" to "time to generate eight words", which is where 1.5s is
/// reachable.
///
/// ## Why it is a class and not a regex over the finished text
///
/// It is fed one token at a time and must decide, on each one, whether a
/// speakable unit has closed — without ever emitting the same text twice and
/// without losing a trailing fragment when the stream ends.
///
/// ## The abbreviation problem
///
/// "e.g." and "Dr." end in a period and are not sentences. Splitting there
/// makes text-to-speech stop mid-thought, which sounds worse than a slightly
/// later start. The guard below is a short list of the abbreviations that
/// actually appear in spoken-style model output; it is not a general solution
/// and does not need to be, because a missed split costs a few hundred
/// milliseconds and a wrong split costs the illusion of a conversation.
class SentenceSegmenter {
  SentenceSegmenter({this.softLimit = 180});

  /// Emit at a clause boundary once the buffer passes this many characters
  /// even if no sentence has ended.
  ///
  /// Some models produce long unpunctuated runs, and a reply with no full stop
  /// in it would otherwise never start speaking until the stream closed —
  /// turning the one case this class exists to prevent into the default.
  final int softLimit;

  final StringBuffer _buffer = StringBuffer();

  /// Lowercased tokens that end in '.' without ending a sentence.
  static const _abbreviations = {
    'e.g.', 'i.e.', 'etc.', 'vs.', 'mr.', 'mrs.', 'ms.', 'dr.', 'prof.',
    'st.', 'jr.', 'sr.', 'no.', 'fig.', 'approx.', 'a.m.', 'p.m.', 'u.s.',
  };

  /// Adds streamed text and returns any sentences that are now complete.
  ///
  /// Returns a list rather than a single sentence because one network chunk can
  /// carry several sentence endings, and dropping the extras would silently
  /// truncate the spoken reply while leaving the on-screen transcript correct —
  /// a mismatch that would be very hard to diagnose from a bug report.
  List<String> add(String text) {
    _buffer.write(text);
    final complete = <String>[];

    for (;;) {
      final content = _buffer.toString();
      final cut = _findCut(content) ?? _findClauseCut(content);
      if (cut == null) break;

      final sentence = content.substring(0, cut).trim();
      final rest = content.substring(cut);
      _buffer
        ..clear()
        ..write(rest);

      if (sentence.isNotEmpty) complete.add(sentence);
    }

    return complete;
  }

  /// Whatever is left when the stream ends, or an empty string.
  ///
  /// Always call this. A reply that ends without terminal punctuation — which
  /// includes every reply truncated by `max_tokens` (the gateway reports it as
  /// `truncated`) — leaves its last words here and nowhere else.
  String flush() {
    final rest = _buffer.toString().trim();
    _buffer.clear();
    return rest;
  }

  bool get isEmpty => _buffer.isEmpty;

  /// The index just past a sentence ending, or null if there is not one yet.
  int? _findCut(String text) {
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char != '.' && char != '!' && char != '?' && char != '\n') continue;

      // A terminator only closes a sentence when something follows it, so a
      // reply that currently ends in "." is not emitted until the next token
      // proves the sentence really ended. Without this, "3." at the head of a
      // numbered list is spoken as its own utterance.
      if (i + 1 >= text.length) return null;

      // Run past a group of terminators so "?!" and "..." emit once.
      var end = i;
      while (end + 1 < text.length && '.!?'.contains(text[end + 1])) {
        end++;
      }

      final next = text[end + 1];
      if (char != '\n' && next != ' ' && next != '\n') continue;

      if (char == '.' && _endsWithAbbreviation(text.substring(0, end + 1))) {
        continue;
      }

      return end + 1;
    }
    return null;
  }

  /// A fallback cut for text that has run past [softLimit] with no sentence
  /// ending in it.
  ///
  /// Prefers a clause boundary — comma, semicolon, colon, dash — and falls back
  /// to the last word break. Never cuts mid-word: text-to-speech would
  /// pronounce the fragment, and "the migrat" is worse than a late start.
  ///
  /// Returns null while the buffer is still short, which is the normal case;
  /// this only fires on models that produce long unpunctuated runs.
  int? _findClauseCut(String text) {
    if (text.length < softLimit) return null;

    final window = text.substring(0, softLimit);
    for (final mark in [';', ':', ',', '—', '–']) {
      final at = window.lastIndexOf(mark);
      // Only past the halfway point: a comma in the first few words produces a
      // two-word utterance, which sounds like a stutter rather than a phrase.
      if (at > softLimit ~/ 2) return at + 1;
    }

    final space = window.lastIndexOf(' ');
    return space > softLimit ~/ 2 ? space + 1 : null;
  }

  bool _endsWithAbbreviation(String upToPeriod) {
    final lastSpace = upToPeriod.lastIndexOf(RegExp(r'\s'));
    final word = upToPeriod.substring(lastSpace + 1).toLowerCase();
    if (_abbreviations.contains(word)) return true;

    // A single letter followed by a period is an initial ("J. Smith"), not the
    // end of a sentence.
    return word.length == 2 && RegExp(r'^[a-z]\.$').hasMatch(word);
  }
}
