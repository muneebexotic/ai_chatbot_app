import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/features/session/application/session_controller.dart';
import 'package:speakwise/features/session/data/audio_interruption_service.dart';
import 'package:speakwise/features/session/data/local/session_database.dart';
import 'package:speakwise/features/session/data/session_client.dart';
import 'package:speakwise/features/session/data/session_repository.dart';
import 'package:speakwise/features/session/data/speech_recognition_service.dart';
import 'package:speakwise/features/session/data/tts_service.dart';
import 'package:speakwise/features/session/domain/session_record.dart';
import 'package:speakwise/features/session/domain/session_settings.dart';
import 'package:speakwise/features/session/domain/session_state.dart';

/// The session feature's slice of the graph (PRD F5, §9.1).
///
/// Declared by hand, like every other provider in this project — see
/// DECISIONS.md D10 for why the code generator is not a dependency.

final sessionDatabaseProvider = Provider<SessionDatabase>((ref) {
  final db = SessionDatabase();
  ref.onDispose(db.close);
  return db;
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(sessionDatabaseProvider));
});

final sessionClientProvider = Provider<SessionClient>((ref) {
  final client = SessionClient();
  ref.onDispose(client.dispose);
  return client;
});

/// One recogniser for the app, not one per screen.
///
/// Binding to the system recognition service is slow, and R4.1.2's calibration
/// step needs a working microphone *before* the first session — so the object
/// that proved it works is the object the session then uses.
final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((
  ref,
) {
  final service = SpeechRecognitionService();
  ref.onDispose(service.dispose);
  return service;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

final audioInterruptionServiceProvider = Provider<AudioInterruptionService>((
  ref,
) {
  final service = AudioInterruptionService();
  ref.onDispose(service.dispose);
  return service;
});

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Local session history — works with no network at all (R11.5).
final sessionHistoryProvider = FutureProvider<List<SessionRecord>>((ref) async {
  return ref.watch(sessionRepositoryProvider).history();
});

/// Sessions whose app died while they were open (R4.2.6).
///
/// Read on the session home so the user is offered the report from the session
/// they lost, rather than discovering that it silently vanished.
final unfinishedSessionsProvider = FutureProvider<List<SessionRecord>>((
  ref,
) async {
  return ref.watch(sessionRepositoryProvider).unfinished();
});

/// R4.2.2 and §5.5. `shared_preferences`, because §9.4 says settings only.
class SessionSettingsNotifier extends Notifier<SessionSettings> {
  static const _inputMode = 'session.input_mode';
  static const _silence = 'session.silence_ms';
  static const _haptics = 'session.haptics';
  static const _firstRun = 'session.first_run_done';
  static const _length = 'session.preferred_length_s';

  @override
  SessionSettings build() {
    // Synchronous default, then loaded. The session screen must be able to
    // start without awaiting a disk read, and every value here has a sane
    // default — the stored ones arrive a frame later.
    unawaitedLoad();
    return const SessionSettings();
  }

  void unawaitedLoad() {
    SharedPreferences.getInstance()
        .then((prefs) {
          state = SessionSettings(
            inputMode:
                SessionInputMode.values.asNameMap()[prefs.getString(_inputMode)] ??
                SessionInputMode.handsFree,
            silenceThreshold: Duration(
              milliseconds:
                  prefs.getInt(_silence) ??
                  SessionSettings.defaultSilence.inMilliseconds,
            ),
            haptics: prefs.getBool(_haptics) ?? true,
            hasCompletedFirstRun: prefs.getBool(_firstRun) ?? false,
            preferredLength: switch (prefs.getInt(_length)) {
              final int s when s > 0 => Duration(seconds: s),
              _ => null,
            },
          );
        })
        .catchError((Object error) {
          // Defaults are correct behaviour, not a fallback. Failing to read a
          // preference must never stop a session starting.
          Log.w('session settings: load failed', error: error);
        });
  }

  Future<void> setInputMode(SessionInputMode mode) async {
    state = state.copyWith(inputMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inputMode, mode.name);
  }

  Future<void> setSilenceThreshold(Duration value) async {
    final clamped = Duration(
      milliseconds: value.inMilliseconds.clamp(
        SessionSettings.minSilence.inMilliseconds,
        SessionSettings.maxSilence.inMilliseconds,
      ),
    );
    state = state.copyWith(silenceThreshold: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_silence, clamped.inMilliseconds);
  }

  Future<void> setHaptics(bool value) async {
    state = state.copyWith(haptics: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_haptics, value);
  }

  Future<void> completeFirstRun({Duration? preferredLength}) async {
    state = state.copyWith(
      hasCompletedFirstRun: true,
      preferredLength: preferredLength,
      clearPreferredLength: preferredLength == null,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstRun, true);
    if (preferredLength == null) {
      await prefs.remove(_length);
    } else {
      await prefs.setInt(_length, preferredLength.inSeconds);
    }
  }
}

final sessionSettingsProvider =
    NotifierProvider<SessionSettingsNotifier, SessionSettings>(
      SessionSettingsNotifier.new,
    );
