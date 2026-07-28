import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/result/result.dart';

/// On-device speech recognition (PRD §3, R4.2.7).
///
/// Replaces `lib/services/speech_service.dart`, which was 42 lines, returned
/// `bool` for failure, re-ran `initialize()` on every listen, and had no
/// amplitude, no turn detection, and no way to distinguish "permission denied"
/// from "no recogniser installed" from "the user said nothing".
///
/// ## The requirement this exists to satisfy
///
/// R4.2.7: "Session audio is NOT uploaded or stored. Recognition happens
/// on-device; only text transcripts leave the device." Nothing in this file
/// opens a socket, writes a file, or holds a buffer of samples. What leaves is
/// a `String` of recognised words, and it leaves through the gateway with the
/// rest of the turn.
///
/// §3 puts it in commercial terms: "the marginal cost of a spoken minute is
/// zero. That is the structural advantage: the expensive feature for a funded
/// competitor is free for a solo developer." Replacing this with a cloud
/// recogniser would delete the business model, which is why CLAUDE.md says
/// never to.
class SpeechRecognitionService {
  SpeechRecognitionService({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  bool _initialised = false;
  bool _stopping = false;

  final _events = StreamController<RecognitionEvent>.broadcast();

  /// Recognition events. Broadcast: the session controller consumes turns and
  /// the waveform consumes levels, and neither should be able to starve the
  /// other by being the only listener.
  Stream<RecognitionEvent> get events => _events.stream;

  bool get isListening => _speech.isListening;

  /// Prepares the recogniser. Safe to call repeatedly.
  ///
  /// Separated from [listen] because it is slow — it binds to the system
  /// recognition service — and because R4.1.2's calibration step needs to know
  /// the microphone works *before* the first session, not at the first word of
  /// it.
  Future<Result<void>> initialize() async {
    if (_initialised) return const Ok(null);

    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        // The plugin's own logging is noisy and unconditional. §16 bans
        // print() in release and Log no-ops there; this is the plugin's
        // equivalent switch.
        debugLogging: false,
      );

      if (!available) {
        // Reached when the device has no recognition service at all, or the
        // user refused the microphone. Both are DeviceFailure and the UI must
        // say which — R11.5 requires a specific message, and "try again" is
        // useless advice for a phone with no recogniser installed.
        return const Err(DeviceFailure(capability: 'speech_recognition'));
      }

      _initialised = true;
      return const Ok(null);
    } on Object catch (error, stack) {
      Log.w('speech: initialize threw', error: error);
      return Err(
        DeviceFailure(
          capability: 'speech_recognition',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  /// Starts listening for one turn.
  ///
  /// [pauseFor] is R4.2.2's silence-based turn detection — "default 1.2s of
  /// silence ends the user's turn, tunable in settings". Pass null for push to
  /// talk, where the release of the control ends the turn and a silence timer
  /// would cut the user off mid-thought while they gathered it.
  ///
  /// [listenFor] is a hard ceiling. Android's recogniser will run indefinitely
  /// otherwise, and a session left face-down on a table would hold the
  /// microphone open until the battery ran out (R11.4).
  Future<Result<void>> listen({
    required String localeId,
    Duration? pauseFor,
    Duration listenFor = const Duration(minutes: 2),
  }) async {
    final ready = await initialize();
    if (ready case Err()) return ready;

    if (_speech.isListening) return const Ok(null);

    _stopping = false;
    try {
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: _onSoundLevel,
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: SpeechListenOptions(
          // R4.2.5 shows a live transcript that scrolls, so partials are the
          // feature, not a debugging aid.
          partialResults: true,
          // Level callbacks are what drive the waveform at R7.5.1's "live
          // microphone amplitude". Without this the signature element of the
          // app has nothing to draw.
          enableHapticFeedback: false,
          cancelOnError: true,
          // `dictation` keeps the recogniser open across short pauses instead
          // of closing on the first gap, which is what makes a 1.2s threshold
          // ours to choose rather than the platform's.
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
        ),
      );
      return const Ok(null);
    } on Object catch (error, stack) {
      Log.w('speech: listen threw', error: error);
      return Err(
        DeviceFailure(
          capability: 'speech_recognition',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  /// Ends the turn and keeps what was heard.
  Future<void> stop() async {
    if (!_speech.isListening) return;
    _stopping = true;
    try {
      await _speech.stop();
    } on Object catch (error) {
      Log.w('speech: stop threw', error: error);
    }
  }

  /// Ends the turn and discards what was heard.
  ///
  /// Used when the session is interrupted (R4.2.6): a half-heard sentence
  /// captured while the user answered a phone call is not something they said
  /// to their practice partner, and putting it in the transcript would corrupt
  /// both the report and the next model turn.
  Future<void> cancel() async {
    if (!_speech.isListening) return;
    _stopping = true;
    try {
      await _speech.cancel();
    } on Object catch (error) {
      Log.w('speech: cancel threw', error: error);
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    _events.add(
      RecognitionEvent.words(
        text: result.recognizedWords,
        isFinal: result.finalResult,
        confidence: result.confidence,
      ),
    );
  }

  /// Normalises the platform's level into `0.0..1.0` for the waveform.
  ///
  /// Android reports roughly -2..10 through `onSoundLevelChange`; iOS reports a
  /// different range again. The mapping lives here rather than in
  /// `WaveformPainter` because it is platform-specific and the painter is
  /// documented as pure — see the amplitude-source note in that file.
  void _onSoundLevel(double level) {
    const min = -2.0;
    const max = 10.0;
    final normalised = ((level - min) / (max - min)).clamp(0.0, 1.0);
    _events.add(RecognitionEvent.level(normalised));
  }

  void _onStatus(String status) {
    // 'done' and 'notListening' both mean the recogniser closed. Emitting the
    // end of turn on either lets the controller move on without polling.
    if (status == 'done' || status == 'notListening') {
      _events.add(RecognitionEvent.turnEnded(cancelled: _stopping));
      _stopping = false;
    }
  }

  void _onError(SpeechRecognitionError error) {
    // `error_no_match` and `error_speech_timeout` are not failures. They mean
    // the user did not say anything, which happens constantly in hands-free
    // mode — every pause longer than the platform's own patience produces one.
    // Surfacing them as errors would put a red bar on screen for silence.
    if (error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout') {
      _events.add(const RecognitionEvent.turnEnded(cancelled: false));
      return;
    }

    Log.w('speech: ${error.errorMsg} (permanent: ${error.permanent})');
    _events.add(RecognitionEvent.failed(error.errorMsg, error.permanent));
  }

  Future<void> dispose() async {
    await cancel();
    await _events.close();
  }
}

/// What the recogniser reports.
sealed class RecognitionEvent {
  const RecognitionEvent();

  const factory RecognitionEvent.words({
    required String text,
    required bool isFinal,
    required double confidence,
  }) = RecognitionWords;

  const factory RecognitionEvent.level(double amplitude) = RecognitionLevel;

  const factory RecognitionEvent.turnEnded({required bool cancelled}) =
      RecognitionTurnEnded;

  const factory RecognitionEvent.failed(String code, bool permanent) =
      RecognitionFailed;
}

final class RecognitionWords extends RecognitionEvent {
  const RecognitionWords({
    required this.text,
    required this.isFinal,
    required this.confidence,
  });

  final String text;
  final bool isFinal;

  /// The recogniser's own confidence, `0.0..1.0`. R4.2.5 lets the user tap
  /// their line to see what was heard; a low number here is why they would.
  final double confidence;
}

final class RecognitionLevel extends RecognitionEvent {
  const RecognitionLevel(this.amplitude);

  /// Normalised `0.0..1.0`.
  final double amplitude;
}

final class RecognitionTurnEnded extends RecognitionEvent {
  const RecognitionTurnEnded({required this.cancelled});

  /// True when the app stopped it, false when silence or the platform did.
  final bool cancelled;
}

final class RecognitionFailed extends RecognitionEvent {
  const RecognitionFailed(this.code, this.permanent);

  final String code;

  /// Permanent errors do not resolve by listening again.
  final bool permanent;
}
