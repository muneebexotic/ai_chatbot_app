/// The input to the metrics engine (PRD R4.3.1).
///
/// Deliberately not the app's `ChatMessage`, and deliberately not a Drift row.
/// DECISIONS D2 requires the metrics engine to be "a standalone, independently
/// testable module with Drill Mode as a known consumer", and a module that
/// takes a persistence type as its input is neither standalone nor usable by a
/// second feature without dragging that feature's storage in with it.
///
/// So this file defines the smallest thing the maths actually needs: who spoke,
/// what was recognised, when it started, and how long it lasted. A Session
/// builds it from its live turns; Drill Mode (Milestone 5) will build it from a
/// drill attempt; a test builds it from three lines of Dart.
library;

/// Who produced a turn.
///
/// `partner` rather than `assistant` or `ai`: the metrics are about a
/// conversation, and §5.3 calls the other side a partner everywhere else.
enum Speaker { user, partner }

/// One continuous turn of speech.
class TranscriptTurn {
  const TranscriptTurn({
    required this.speaker,
    required this.text,
    required this.startOffset,
    required this.duration,
  });

  final Speaker speaker;

  /// What was said. For a user turn this is what the on-device recogniser
  /// heard, which is not always what was said — R4.2.5 exposes exactly this by
  /// letting the user tap their own line to see it.
  final String text;

  /// When this turn began, measured from the start of the session.
  final Duration startOffset;

  /// How long the turn's audio lasted.
  ///
  /// For a user turn in hands-free mode this ends at the silence threshold
  /// (R4.2.2, 1.2s by default), so it excludes the trailing silence that
  /// *detected* the end. For push to talk it is the hold. For a partner turn it
  /// is how long text-to-speech actually spoke, which is shorter than expected
  /// whenever the user barged in (R4.2.3).
  final Duration duration;

  Duration get endOffset => startOffset + duration;

  TranscriptTurn copyWith({
    Speaker? speaker,
    String? text,
    Duration? startOffset,
    Duration? duration,
  }) => TranscriptTurn(
    speaker: speaker ?? this.speaker,
    text: text ?? this.text,
    startOffset: startOffset ?? this.startOffset,
    duration: duration ?? this.duration,
  );
}
