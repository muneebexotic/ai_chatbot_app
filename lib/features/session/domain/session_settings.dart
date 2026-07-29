/// Session preferences (PRD R4.2.2, §5.5).
///
/// `shared_preferences`, not Drift. §9.4 is explicit: "Drift (SQLite) for
/// threads, messages, sessions, and reports... `shared_preferences` for
/// settings only."
class SessionSettings {
  const SessionSettings({
    this.inputMode = SessionInputMode.handsFree,
    this.silenceThreshold = defaultSilence,
    this.haptics = true,
    this.hasCompletedFirstRun = false,
    this.preferredLength,
  });

  /// R4.2.2: "Two input modes, switchable mid-session, **remembered per
  /// user**." Hands-free is the default because §4 is a hands-free product —
  /// §3's secondary user is "someone who just wants a good AI to talk to
  /// hands-free while commuting, cooking, or walking".
  final SessionInputMode inputMode;

  /// R4.2.2: "default 1.2s of silence ends the user's turn, tunable in
  /// settings."
  ///
  /// The tuning matters more than it looks. Too short and the app interrupts
  /// anyone who pauses to think, which is precisely the user practising a
  /// difficult answer. Too long and every exchange feels laggy. 1.2s is the
  /// PRD's number and the range below is what §5.5's "turn-detection
  /// sensitivity" control offers.
  final Duration silenceThreshold;

  static const defaultSilence = Duration(milliseconds: 1200);
  static const minSilence = Duration(milliseconds: 600);
  static const maxSilence = Duration(milliseconds: 2500);

  /// R7.7.3: haptics carry meaning and must respect a settings toggle.
  final bool haptics;

  /// R4.1.2's "before the first session only" flow. Once true, the permission
  /// and calibration steps are not shown again.
  final bool hasCompletedFirstRun;

  /// R4.1.2's session length choice. Null means open-ended.
  final Duration? preferredLength;

  SessionSettings copyWith({
    SessionInputMode? inputMode,
    Duration? silenceThreshold,
    bool? haptics,
    bool? hasCompletedFirstRun,
    Duration? preferredLength,
    bool clearPreferredLength = false,
  }) => SessionSettings(
    inputMode: inputMode ?? this.inputMode,
    silenceThreshold: silenceThreshold ?? this.silenceThreshold,
    haptics: haptics ?? this.haptics,
    hasCompletedFirstRun: hasCompletedFirstRun ?? this.hasCompletedFirstRun,
    preferredLength: clearPreferredLength
        ? null
        : (preferredLength ?? this.preferredLength),
  );
}

enum SessionInputMode {
  /// Continuous listening with silence-based turn detection.
  handsFree,

  /// Hold the waveform to speak, release to send.
  ///
  /// R4.2.2 makes this the automatic *suggestion* in a noisy room, "with a
  /// non-blocking suggestion, never a forced switch". The distinction is the
  /// requirement: an app that takes the microphone away from someone mid-answer
  /// because it decided the room was loud is worse than one that asks.
  pushToTalk,
}
