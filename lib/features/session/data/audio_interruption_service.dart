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
/// See `MainActivity.kt` for why an incoming call is detected through audio
/// focus rather than `READ_PHONE_STATE`: same signal, no runtime permission, no
/// entry on the Play data-safety form, and it additionally covers alarms,
/// navigation prompts, and any other app that takes the audio.
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

  /// Starts watching. [onInterrupted] fires when the session should pause;
  /// [onResumable] when the audio comes back and resuming is possible.
  void start({
    required void Function(InterruptionReason) onInterrupted,
    required void Function() onResumable,
  }) {
    if (!Platform.isAndroid) return;

    _subscription?.cancel();
    _subscription = _channel.receiveBroadcastStream().listen(
      (dynamic event) {
        switch (event) {
          case 'audio_focus_lost':
            onInterrupted(InterruptionReason.incomingCall);
          case 'headphones_disconnected':
            onInterrupted(InterruptionReason.headphonesDisconnected);
          case 'audio_focus_regained':
            onResumable();
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
