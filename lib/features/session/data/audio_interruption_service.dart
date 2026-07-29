import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/features/session/domain/session_state.dart';

/// The Dart side of R4.2.6's audio interruptions.
///
/// R4.2.6 names four: "incoming phone call, app backgrounded, headphones
/// disconnected, network loss". This covers the two that are Android audio
/// concepts with no Flutter equivalent; the app lifecycle and connectivity are
/// handled in the controller with `AppLifecycleListener` and
/// `connectivity_plus`.
///
/// See `MainActivity.kt` for why this does NOT hold audio focus. The first
/// version did, and the app lost focus to its own recogniser — every session
/// paused with "Something else took the audio" before a word was spoken. A call
/// is now detected from the audio mode (API 31+) and headphones from
/// ACTION_AUDIO_BECOMING_NOISY, neither of which needs focus or a permission.
///
/// Returns nothing on iOS. §9.1 says "Android first, iOS kept building", and a
/// stream that never fires is the correct iOS behaviour for now — the session
/// still pauses on backgrounding, which is the interruption iOS surfaces
/// through the lifecycle anyway.
class AudioInterruptionService {
  static const _channel = EventChannel(
    'com.muscodes.speakwise/audio_interruptions',
  );

  StreamSubscription<dynamic>? _subscription;

  /// Starts watching. [onInterrupted] fires when the session should pause.
  ///
  /// There is deliberately no "resumable" callback. R4.2.6 says the session
  /// "offers resume", and an app that reopens the microphone by itself when a
  /// call ends is an app with a hot microphone the user did not ask for.
  void start({required void Function(InterruptionReason) onInterrupted}) {
    if (!Platform.isAndroid) return;

    _subscription?.cancel();
    _subscription = _channel.receiveBroadcastStream().listen(
      (dynamic event) {
        switch (event) {
          case 'call_started':
            onInterrupted(InterruptionReason.incomingCall);
          case 'headphones_disconnected':
            onInterrupted(InterruptionReason.headphonesDisconnected);
          default:
            Log.w('audio: unknown interruption "$event"');
        }
      },
      onError: (Object error) {
        // A failed channel must not take the session with it. Losing
        // interruption detection degrades the experience; throwing here would
        // end a session the user is in the middle of.
        Log.w('audio: interruption channel failed', error: error);
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
