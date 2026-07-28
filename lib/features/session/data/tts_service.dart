import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/result/result.dart';

/// On-device text-to-speech (PRD §3, R4.2.3, R4.2.4).
///
/// Replaces `lib/services/voice_service.dart`, which was 15 lines and set the
/// language and pitch on every utterance — three platform round trips before
/// the first phoneme, inside the 1.5s budget R4.2.4 sets.
///
/// ## The two requirements that shape this file
///
/// **R4.2.3 — barge-in.** "If the user starts speaking while the AI is
/// speaking, text-to-speech stops within 200ms." [stop] is therefore the most
/// latency-sensitive method here: it must not await a queue drain, must be safe
/// to call when nothing is speaking, and must leave no queued sentence behind
/// that would start playing a moment later. A stop that silences the current
/// sentence and then speaks the next one is not a stop.
///
/// **R4.2.4 — first audible word.** [onSpeechStarted] fires when the engine
/// actually begins producing audio, which is the only honest end point for the
/// measurement. Timing to when `speak()` returns would measure the method call,
/// not the user's experience, and would report a budget that is met when it is
/// not.
class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  bool _configured = false;
  Completer<void>? _utterance;

  /// Fires when audio actually starts for an utterance.
  ///
  /// The R4.2.4 stopwatch stops here. Nowhere else is defensible.
  void Function()? onSpeechStarted;

  /// Fires when an utterance finishes on its own (not when it is stopped).
  void Function()? onSpeechCompleted;

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  /// Android's speech-rate scale is not the same number as a partner's
  /// `voice_rate`.
  ///
  /// `partners.voice_rate` is 1.0 for "normal" (§9.5, and all five built-ins
  /// ship 1.0). Android's `setSpeechRate` takes 0.0–1.0 where roughly 0.5 is
  /// normal conversational speed and 1.0 is comically fast. Passing the
  /// partner's 1.0 straight through would make every partner sound like a
  /// disclaimer read at the end of a radio advert.
  static const _androidNormalRate = 0.5;
  static const _iosNormalRate = 0.5;

  Future<Result<void>> initialize({required String language}) async {
    try {
      // Fail loudly here rather than producing silence later. A device with no
      // voice for the locale is a DeviceFailure the UI must name, because the
      // fix is installing a voice in system settings and no amount of retrying
      // in the app will do it.
      final available = await _tts.isLanguageAvailable(language);
      if (available != true) {
        Log.w('tts: no voice for $language');
        return const Err(DeviceFailure(capability: 'text_to_speech'));
      }

      await _tts.setLanguage(language);
      // Sentences are queued as they stream in (R4.2.4), so the engine must add
      // to the queue rather than flush it — flushing would mean each new
      // sentence cut off the one before, and the user would hear only the last.
      await _tts.setQueueMode(1);
      // Required for the completion handler to fire per utterance rather than
      // per batch, which is what lets a turn know when it has finished
      // speaking.
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() {
        _speaking = true;
        onSpeechStarted?.call();
      });
      _tts.setCompletionHandler(() {
        _speaking = false;
        _utterance?.complete();
        _utterance = null;
        onSpeechCompleted?.call();
      });
      _tts.setCancelHandler(() {
        _speaking = false;
        _utterance?.complete();
        _utterance = null;
      });
      // `dynamic` because that is the plugin's own `ErrorHandler` typedef, not
      // a loosening of this file's typing. It is logged and never displayed.
      _tts.setErrorHandler((dynamic message) {
        Log.w('tts: $message');
        _speaking = false;
        _utterance?.complete();
        _utterance = null;
      });

      _configured = true;
      return const Ok(null);
    } on Object catch (error, stack) {
      Log.w('tts: initialize threw', error: error);
      return Err(
        DeviceFailure(
          capability: 'text_to_speech',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  /// Applies a partner's voice (R5.3.1).
  ///
  /// Called once when a session opens rather than per utterance: each of these
  /// is a platform channel round trip, and doing them before every sentence
  /// spends the R4.2.4 budget on configuration that has not changed.
  Future<void> applyVoice({required double rate, required double pitch}) async {
    if (!_configured) return;
    try {
      final normal = Platform.isIOS ? _iosNormalRate : _androidNormalRate;
      await _tts.setSpeechRate((rate * normal).clamp(0.0, 1.0));
      await _tts.setPitch(pitch.clamp(0.5, 2.0));
    } on Object catch (error) {
      Log.w('tts: applyVoice threw', error: error);
    }
  }

  /// Speaks one sentence, queued behind anything already speaking.
  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !_configured) return;

    try {
      _utterance = Completer<void>();
      await _tts.speak(trimmed);
    } on Object catch (error) {
      Log.w('tts: speak threw', error: error);
      _speaking = false;
      _utterance?.complete();
      _utterance = null;
    }
  }

  /// Stops immediately and drops anything queued — R4.2.3's 200ms path.
  ///
  /// Deliberately does not await the completion handler. The requirement is
  /// that sound stops, and `FlutterTts.stop` reaches the platform engine
  /// directly; waiting for the cancel callback to come back through the channel
  /// would add a round trip to the one measurement that is not allowed to have
  /// one.
  Future<void> stop() async {
    if (!_configured) return;
    _speaking = false;
    try {
      await _tts.stop();
    } on Object catch (error) {
      Log.w('tts: stop threw', error: error);
    } finally {
      // Release anyone awaiting the utterance. Without this a turn that is
      // barged in on waits forever for a completion that will never arrive.
      if (_utterance?.isCompleted == false) _utterance?.complete();
      _utterance = null;
    }
  }

  /// Resolves when the current utterance finishes, or immediately if none.
  Future<void> get currentUtterance => _utterance?.future ?? Future.value();

  Future<void> dispose() => stop();
}
