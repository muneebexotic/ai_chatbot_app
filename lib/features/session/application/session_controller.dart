import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/core/safety/crisis_detector.dart';
import 'package:speakwise/core/speech_metrics/metrics_engine.dart';
import 'package:speakwise/core/speech_metrics/transcript.dart';
import 'package:speakwise/design/waveform/amplitude_window.dart';
import 'package:speakwise/features/chat/application/chat_providers.dart';
import 'package:speakwise/features/chat/data/gateway_client.dart';
import 'package:speakwise/features/chat/domain/gateway_event.dart';
import 'package:speakwise/features/session/application/session_providers.dart';
import 'package:speakwise/features/session/data/speech_recognition_service.dart';
import 'package:speakwise/features/session/domain/session_record.dart';
import 'package:speakwise/features/session/domain/session_settings.dart';
import 'package:speakwise/features/session/domain/session_state.dart';
import 'package:speakwise/features/session/domain/sentence_segmenter.dart';

/// The live session (PRD §4.2). The centre of the product.
///
/// §15.4 calls Milestone 4 "the milestone the product lives or dies on", and
/// this class is where most of that lives. It owns one state machine —
/// listening → thinking → speaking → listening — and the interruptions that cut
/// across it.
///
/// ## The three requirements that shape every decision here
///
/// **R4.2.3, barge-in within 200ms.** "An AI that cannot be interrupted does
/// not feel like a conversation." The recogniser therefore stays open *during*
/// text-to-speech, and the moment it hears the user the synthesiser is stopped
/// — before any state update, before any await that could be scheduled behind
/// something else. See [_onLevel].
///
/// **R4.2.4, under 1.5s from end-of-speech to first spoken word.** The reply is
/// streamed and [SentenceSegmenter] hands the first complete sentence to
/// text-to-speech while the rest is still being generated. The stopwatch starts
/// when the user's turn is final and stops in the synthesiser's own start
/// callback, which is the only honest end point.
///
/// **R4.2.6, nothing is lost.** Every finalised turn is written to local
/// storage *before* it enters [state], so a force-kill cannot produce a screen
/// the report does not have.
class SessionController extends Notifier<SessionState> {
  StreamSubscription<RecognitionEvent>? _recognition;
  StreamSubscription<GatewayEvent>? _reply;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  AppLifecycleListener? _lifecycle;
  Timer? _ticker;
  Timer? _heartbeat;

  final _segmenter = SentenceSegmenter();
  final _amplitudes = AmplitudeWindow();

  /// The live microphone level, for the waveform. Exposed as a listenable so
  /// the painter can read it without a widget rebuild (R11.2).
  AmplitudeWindow get amplitudes => _amplitudes;

  DateTime? _startedAt;
  DateTime? _turnStartedAt;
  DateTime? _endOfSpeechAt;
  String _heardSoFar = '';
  double _lastConfidence = 1;

  /// Rolling ambient level while the partner speaks, used to tell the user's
  /// voice from the synthesiser's own echo. See [_onLevel].
  double _echoFloor = 0;
  int _loudFrames = 0;
  int _noisyFrames = 0;

  static const _bargeInFramesRequired = 2;
  static const _bargeInMargin = 0.18;
  static const _noisyThreshold = 0.35;

  /// R4.2.2: "ambient level above threshold for 5 consecutive seconds". Level
  /// callbacks arrive roughly ten times a second on Android.
  static const _noisyFramesRequired = 50;

  @override
  SessionState build() {
    ref.onDispose(_teardown);
    return const SessionState(phase: SessionPhase.ended);
  }

  // ── Starting ───────────────────────────────────────────────────────────────

  /// Opens a session with [partnerId] and begins listening.
  ///
  /// The local row is created before the server is called, deliberately.
  /// `open_voice_session` can be slow, refused on quota, or unreachable, and in
  /// all three cases the user is already looking at a live screen. A session
  /// that only exists once the server agrees is a session that loses its first
  /// turns (R11.5 requires an offline session to record locally regardless).
  Future<void> start({
    required String partnerId,
    required String partnerName,
    required double voiceRate,
    required double voicePitch,
    String? goal,
    String? threadId,
  }) async {
    final settings = ref.read(sessionSettingsProvider);
    final localId = 'session-${DateTime.now().microsecondsSinceEpoch}';
    _startedAt = DateTime.now();

    state = SessionState(
      phase: SessionPhase.starting,
      inputMode: settings.inputMode,
      localId: localId,
      partnerName: partnerName,
    );

    final repository = ref.read(sessionRepositoryProvider);
    await repository.createSession(
      SessionRecord(
        localId: localId,
        partnerId: partnerId,
        partnerName: partnerName,
        threadId: threadId,
        goal: goal,
        startedAt: _startedAt!,
      ),
    );

    final speech = ref.read(speechRecognitionServiceProvider);
    final ready = await speech.initialize();
    if (ready case Err(:final failure)) {
      state = state.copyWith(phase: SessionPhase.ended, failure: failure);
      return;
    }

    final tts = ref.read(ttsServiceProvider);
    final voiceReady = await tts.initialize(language: 'en-US');
    if (voiceReady case Err(:final failure)) {
      // Not fatal. A session with no voice is still a session that records a
      // transcript and produces a report (R4.3.1 needs no audio at all), and
      // R8.0's principle — the product must stay usable when a piece of it is
      // unavailable — applies to a missing system voice as much as to a
      // missing model.
      Log.w('session: no voice available, continuing muted');
      state = state.copyWith(failure: failure);
    }
    await tts.applyVoice(rate: voiceRate, pitch: voicePitch);
    tts.onSpeechStarted = _onSpeechStarted;
    tts.onSpeechCompleted = _onSpeechCompleted;

    // The server call. A failure here does NOT end the session — it means the
    // seconds are not being metered and the reply will fail when it is tried,
    // both of which the user finds out about in the ordinary way.
    final token = ref.read(accessTokenProvider);
    if (token != null) {
      final opened = await ref
          .read(sessionClientProvider)
          .open(accessToken: token, partnerId: partnerId, threadId: threadId, goal: goal);

      switch (opened) {
        case Ok(:final value):
          await repository.attachServerIds(localId, serverId: value.sessionId);
          state = state.copyWith(
            serverSessionId: value.sessionId,
            usage: value.usage,
          );
        case Err(:final failure):
          // Quota is the one refusal that must stop the session before it
          // starts: R8.3 puts the paywall at the cap, and letting somebody
          // speak for ten minutes into a session the server refused would be
          // worse than saying so now.
          if (failure is QuotaExceededFailure) {
            state = state.copyWith(
              phase: SessionPhase.ended,
              failure: failure,
            );
            return;
          }
          state = state.copyWith(failure: failure);
      }
    }

    _watchInterruptions();
    _startTimers();
    await _listen();
  }

  // ── Listening ──────────────────────────────────────────────────────────────

  Future<void> _listen() async {
    if (state.isMuted || state.isTypingFallback) return;

    _heardSoFar = '';
    _turnStartedAt = DateTime.now();
    _amplitudes.reset();
    state = state.copyWith(phase: SessionPhase.listening, partialText: '');

    _recognition?.cancel();
    final speech = ref.read(speechRecognitionServiceProvider);
    _recognition = speech.events.listen(_onRecognition);

    final settings = ref.read(sessionSettingsProvider);
    final result = await speech.listen(
      localeId: 'en_US',
      // R4.2.2. Push to talk passes null: the release of the control ends the
      // turn, and a silence timer would cut the user off while they gathered a
      // difficult thought — which is exactly the user this app is for.
      pauseFor: state.inputMode == SessionInputMode.handsFree
          ? settings.silenceThreshold
          : null,
    );

    if (result case Err(:final failure)) {
      state = state.copyWith(
        phase: SessionPhase.paused,
        interruption: InterruptionReason.microphoneLost,
        failure: failure,
      );
    }
  }

  void _onRecognition(RecognitionEvent event) {
    switch (event) {
      case RecognitionLevel(:final amplitude):
        _onLevel(amplitude);

      case RecognitionWords(:final text, :final isFinal, :final confidence):
        _lastConfidence = confidence;
        if (text.trim().isNotEmpty) {
          _heardSoFar = text;
          // A partial arriving while the partner speaks is the strongest
          // possible barge-in signal — the recogniser produced words, not just
          // a level. Acted on immediately (R4.2.3).
          if (state.phase == SessionPhase.speaking) {
            _bargeIn();
          } else {
            state = state.copyWith(partialText: text);
          }
        }
        if (isFinal) unawaited(_finishUserTurn());

      case RecognitionTurnEnded(:final cancelled):
        if (!cancelled && state.phase == SessionPhase.listening) {
          unawaited(_finishUserTurn());
        }

      case RecognitionFailed(:final code, :final permanent):
        Log.w('session: recogniser failed ($code)');
        if (permanent) {
          state = state.copyWith(
            phase: SessionPhase.paused,
            interruption: InterruptionReason.microphoneLost,
          );
        } else if (state.phase == SessionPhase.listening) {
          unawaited(_listen());
        }
    }
  }

  /// Every microphone level, in every phase. Three jobs.
  ///
  /// **1. The waveform** (R7.5.1). Pushed into the window, which the painter
  /// reads without a widget rebuild.
  ///
  /// **2. Barge-in** (R4.2.3). The hard part is that the microphone hears the
  /// synthesiser through the speaker, so a fixed threshold either triggers on
  /// the app's own voice or never triggers at all. The first moments of a
  /// partner turn establish an echo floor, and a barge-in needs to exceed that
  /// floor by a margin for two consecutive callbacks — roughly 100-200ms on
  /// Android, which is what the 200ms budget allows. On headphones the floor
  /// settles near zero and it becomes very sensitive, which is correct.
  ///
  /// **3. Noise detection** (R4.2.2). Five consecutive seconds above threshold
  /// suggests push to talk, once.
  void _onLevel(double amplitude) {
    _amplitudes.push(amplitude);

    if (state.phase == SessionPhase.speaking) {
      // Track the quietest recent level as the echo floor: the synthesiser's
      // own output is continuous, so the floor converges to it, while the
      // user's voice arrives on top of it.
      _echoFloor = _echoFloor == 0
          ? amplitude
          : (_echoFloor * 0.9 + amplitude * 0.1);

      if (amplitude > _echoFloor + _bargeInMargin) {
        _loudFrames++;
        if (_loudFrames >= _bargeInFramesRequired) _bargeIn();
      } else {
        _loudFrames = 0;
      }
      return;
    }

    if (state.phase != SessionPhase.listening) return;

    // R4.2.2's noisy environment. Only counted while listening: measuring the
    // room during a partner turn would measure the partner.
    if (amplitude > _noisyThreshold && _heardSoFar.isEmpty) {
      _noisyFrames++;
      if (_noisyFrames >= _noisyFramesRequired &&
          !state.hasSuggestedPushToTalk &&
          state.inputMode == SessionInputMode.handsFree) {
        state = state.copyWith(
          isEnvironmentNoisy: true,
          hasSuggestedPushToTalk: true,
        );
      }
    } else {
      _noisyFrames = 0;
    }
  }

  /// R4.2.3. Stops the synthesiser first and updates state afterwards.
  ///
  /// The order is the requirement. `tts.stop()` reaches the platform engine
  /// directly; anything scheduled ahead of it — a state assignment that
  /// triggers a rebuild, an awaited local write — pushes the moment of silence
  /// past 200ms for no benefit the user can hear.
  void _bargeIn() {
    if (state.phase != SessionPhase.speaking) return;

    unawaited(ref.read(ttsServiceProvider).stop());
    _loudFrames = 0;
    _echoFloor = 0;

    // The partner's turn is cut short. Recording its real duration rather than
    // its intended one is what makes SpeechMetrics.talkTimeRatio honest, and it
    // is how bargeInCount is derived at the end.
    _closePartnerTurn(interrupted: true);

    _turnStartedAt = DateTime.now();
    state = state.copyWith(phase: SessionPhase.listening);
  }

  /// The user stopped speaking. This is where R4.2.4's stopwatch starts.
  Future<void> _finishUserTurn() async {
    if (state.phase != SessionPhase.listening) return;

    final text = _heardSoFar.trim();
    _heardSoFar = '';

    if (text.isEmpty) {
      // Silence. Not an error and not a turn — just listen again. In hands-free
      // mode this happens constantly and must be invisible.
      await _listen();
      return;
    }

    _endOfSpeechAt = DateTime.now();
    await ref.read(speechRecognitionServiceProvider).stop();

    await _appendTurn(
      Speaker.user,
      text,
      startedAt: _turnStartedAt ?? _endOfSpeechAt!,
      endedAt: _endOfSpeechAt!,
      confidence: _lastConfidence,
    );

    // R10.6, on the user's own words, before the reply is requested. The card
    // must appear whether or not the model complies with the safety preamble,
    // and whether or not there is a network at all.
    final crisis = const CrisisDetector().examine(text);
    if (crisis != null && state.crisis == null) {
      state = state.copyWith(crisis: crisis);
    }

    state = state.copyWith(phase: SessionPhase.thinking, partialText: '');
    await _requestReply(text);
  }

  // ── Thinking and speaking ──────────────────────────────────────────────────

  Future<void> _requestReply(String text) async {
    final token = ref.read(accessTokenProvider);
    final record = await ref
        .read(sessionRepositoryProvider)
        .byLocalId(state.localId!);

    if (token == null || record == null) {
      state = state.copyWith(failure: const UnauthorizedFailure());
      await _listen();
      return;
    }

    var reply = '';
    _turnStartedAt = DateTime.now();
    final completer = Completer<void>();

    _reply?.cancel();
    _reply = ref
        .read(gatewayClientProvider)
        .send(
          accessToken: token,
          partnerId: record.partnerId,
          text: text,
          threadId: record.threadId,
          sessionId: state.serverSessionId,
        )
        .listen(
          (event) {
            switch (event) {
              case GatewayMeta():
                // The gateway creates the thread on the first turn and links it
                // to the session (§5.1: they share one thread).
                if (record.threadId == null) {
                  unawaited(
                    ref
                        .read(sessionRepositoryProvider)
                        .attachServerIds(
                          state.localId!,
                          threadId: event.threadId,
                        ),
                  );
                }

              case GatewayDelta(:final text):
                reply += text;
                // R4.2.4's mechanism: speak the first complete sentence while
                // the rest is still generating.
                for (final sentence in _segmenter.add(text)) {
                  unawaited(_speak(sentence));
                }

              case GatewayDone():
                final tail = _segmenter.flush();
                if (tail.isNotEmpty) unawaited(_speak(tail));
            }
          },
          onError: (Object error, StackTrace stack) {
            final failure = error is GatewayFailure
                ? error.failure
                : UnknownFailure(cause: error, stackTrace: stack);
            state = state.copyWith(failure: failure);
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

    await completer.future;

    if (reply.trim().isNotEmpty) {
      _pendingPartnerText = reply.trim();
    } else {
      // Nothing came back. The transcript keeps the user's turn — they said it
      // — and the session carries on rather than ending on a provider's bad
      // minute (R11.5).
      await _listen();
    }
  }

  String _pendingPartnerText = '';
  DateTime? _partnerStartedAt;

  Future<void> _speak(String sentence) async {
    if (state.phase == SessionPhase.listening) return;
    state = state.copyWith(phase: SessionPhase.speaking);
    await ref.read(ttsServiceProvider).speak(sentence);
  }

  /// The synthesiser has begun producing audio. R4.2.4's stopwatch stops here.
  ///
  /// Timing to when `speak()` returns would measure a method call rather than
  /// the user's experience, and would report a budget as met when it was not.
  void _onSpeechStarted() {
    _partnerStartedAt ??= DateTime.now();

    final startedListening = _endOfSpeechAt;
    if (startedListening != null) {
      final latency = DateTime.now().difference(startedListening);
      _endOfSpeechAt = null;
      Log.d('session: first spoken word in ${latency.inMilliseconds}ms');
      state = state.copyWith(
        turnLatencies: [...state.turnLatencies, latency],
      );
    }
  }

  void _onSpeechCompleted() {
    if (state.phase != SessionPhase.speaking) return;
    _closePartnerTurn(interrupted: false);
    unawaited(_listen());
  }

  void _closePartnerTurn({required bool interrupted}) {
    final text = _pendingPartnerText;
    final startedAt = _partnerStartedAt;
    if (text.isEmpty || startedAt == null) return;

    _pendingPartnerText = '';
    _partnerStartedAt = null;

    unawaited(
      _appendTurn(
        Speaker.partner,
        text,
        startedAt: startedAt,
        endedAt: DateTime.now(),
      ),
    );
  }

  // ── The transcript ─────────────────────────────────────────────────────────

  /// Writes a turn to disk, then to the screen. Never the other way round.
  ///
  /// R4.2.6's force-kill guarantee is only true if the user cannot see a line
  /// the report will not have. The local insert is small and is dwarfed by the
  /// model round trip that follows it.
  Future<void> _appendTurn(
    Speaker speaker,
    String text, {
    required DateTime startedAt,
    required DateTime endedAt,
    double confidence = 1,
  }) async {
    final offset = startedAt.difference(_startedAt ?? startedAt);
    final turn = TranscriptTurn(
      speaker: speaker,
      text: text,
      startOffset: offset.isNegative ? Duration.zero : offset,
      duration: endedAt.difference(startedAt),
    );

    await ref
        .read(sessionRepositoryProvider)
        .appendTurn(state.localId!, turn, confidence: confidence);

    state = state.copyWith(
      turns: [
        ...state.turns,
        SessionTurn(
          id: '${speaker.name}-${startedAt.microsecondsSinceEpoch}',
          speaker: speaker,
          text: text,
          startOffset: turn.startOffset,
          duration: turn.duration,
          confidence: confidence,
        ),
      ],
    );
  }

  // ── Controls (R4.2.1) ──────────────────────────────────────────────────────

  Future<void> toggleMute() async {
    final muted = !state.isMuted;
    state = state.copyWith(isMuted: muted, partialText: '');
    if (muted) {
      await ref.read(speechRecognitionServiceProvider).cancel();
      _amplitudes.reset();
    } else if (state.phase == SessionPhase.listening) {
      await _listen();
    }
  }

  /// R4.2.2: switchable mid-session, and remembered.
  Future<void> setInputMode(SessionInputMode mode) async {
    if (mode == state.inputMode) return;
    state = state.copyWith(inputMode: mode, isEnvironmentNoisy: false);
    await ref.read(sessionSettingsProvider.notifier).setInputMode(mode);

    if (state.phase == SessionPhase.listening) {
      await ref.read(speechRecognitionServiceProvider).cancel();
      await _listen();
    }
  }

  /// Push to talk: the user pressed the waveform.
  Future<void> pressToTalk() async {
    if (state.inputMode != SessionInputMode.pushToTalk) return;
    if (state.phase == SessionPhase.speaking) _bargeIn();
    await _listen();
  }

  /// Push to talk: released. The turn ends here rather than on silence.
  Future<void> releaseToTalk() async {
    if (state.inputMode != SessionInputMode.pushToTalk) return;
    await ref.read(speechRecognitionServiceProvider).stop();
    await _finishUserTurn();
  }

  void dismissNoiseSuggestion() {
    state = state.copyWith(isEnvironmentNoisy: false);
  }

  void dismissFailure() => state = state.copyWith(clearFailure: true);

  // ── P8: keep the session, switch to typing ─────────────────────────────────

  /// PROPOSALS P8, approved for this milestone.
  ///
  /// R4.2.2 already requires detecting a noisy room and suggesting push to
  /// talk. P8 adds the third option, which answers RESEARCH.md §1.3's top
  /// functional complaint across the whole category: recognition failing in
  /// noise. The incumbents leave the user stuck; this keeps the session, the
  /// transcript, and the report intact.
  ///
  /// §5.1 already requires spoken and typed conversations to share one thread,
  /// so a typed turn here is the same turn in the same session.
  Future<void> useTypingFallback() async {
    state = state.copyWith(
      isTypingFallback: true,
      isEnvironmentNoisy: false,
      partialText: '',
    );
    await ref.read(speechRecognitionServiceProvider).cancel();
    _amplitudes.reset();
  }

  Future<void> returnToSpeaking() async {
    state = state.copyWith(isTypingFallback: false);
    await _listen();
  }

  /// A typed turn inside a spoken session (P8).
  Future<void> sendTyped(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.phase == SessionPhase.thinking) return;

    final now = DateTime.now();
    _endOfSpeechAt = now;
    await _appendTurn(Speaker.user, trimmed, startedAt: now, endedAt: now);

    final crisis = const CrisisDetector().examine(trimmed);
    if (crisis != null && state.crisis == null) {
      state = state.copyWith(crisis: crisis);
    }

    state = state.copyWith(phase: SessionPhase.thinking);
    await _requestReply(trimmed);
  }

  // ── Interruptions (R4.2.6) ─────────────────────────────────────────────────

  void _watchInterruptions() {
    ref.read(audioInterruptionServiceProvider).start(
      onInterrupted: (reason) => unawaited(pause(reason)),
      onResumable: () {
        // Focus came back. The session does not resume itself — R4.2.6 says
        // "offers resume", and an app that starts listening again on its own
        // after a phone call is an app with a hot microphone the user did not
        // ask for.
        Log.d('session: audio focus regained');
      },
    );

    _lifecycle = AppLifecycleListener(
      onStateChange: (lifecycle) {
        if (lifecycle == AppLifecycleState.paused ||
            lifecycle == AppLifecycleState.hidden) {
          unawaited(pause(InterruptionReason.backgrounded));
        }
      },
    );

    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      final offline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (offline && state.isLive) {
        unawaited(pause(InterruptionReason.networkLost));
      }
    });
  }

  /// Pauses and keeps everything. R4.2.6: "nothing is lost."
  Future<void> pause(InterruptionReason reason) async {
    if (!state.isLive) return;

    _ticker?.cancel();
    _heartbeat?.cancel();

    // `cancel`, not `stop`. A half-heard sentence captured while the user
    // answered a phone call is not something they said to their practice
    // partner, and putting it in the transcript would corrupt both the report
    // and the next model turn.
    await ref.read(speechRecognitionServiceProvider).cancel();
    await ref.read(ttsServiceProvider).stop();
    _amplitudes.reset();

    state = state.copyWith(
      phase: SessionPhase.paused,
      interruption: reason,
      partialText: '',
    );
  }

  Future<void> resume() async {
    if (state.phase != SessionPhase.paused) return;
    state = state.copyWith(clearInterruption: true, clearFailure: true);
    _startTimers();
    await _listen();
  }

  // ── Timers ─────────────────────────────────────────────────────────────────

  void _startTimers() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt == null) return;
      state = state.copyWith(elapsed: DateTime.now().difference(startedAt));
    });

    // The meter between model turns. The gateway meters every spoken turn on
    // its own, so this only covers the gaps — and the server clamps any single
    // charge, so a missed heartbeat is bounded in both directions.
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_sendHeartbeat());
    });
  }

  Future<void> _sendHeartbeat() async {
    final token = ref.read(accessTokenProvider);
    final sessionId = state.serverSessionId;
    if (token == null || sessionId == null) return;

    final result = await ref
        .read(sessionClientProvider)
        .heartbeat(accessToken: token, sessionId: sessionId);

    switch (result) {
      case Ok(:final value):
        state = state.copyWith(usage: value.usage);
        if (!value.allowed) {
          // R8.3: "never cut them off mid-sentence, finish the exchange, then
          // show it." The allowance is gone, but the current turn finishes.
          if (state.phase == SessionPhase.listening) {
            await end(reason: SessionEndReason.quotaExhausted);
          }
        }
      case Err():
        // A failed heartbeat is not the user's problem and must not interrupt
        // them. The next one, or the next model turn, meters the elapsed time
        // anyway.
        break;
    }
  }

  // ── Ending ─────────────────────────────────────────────────────────────────

  Future<void> end({SessionEndReason reason = SessionEndReason.user}) async {
    if (state.phase == SessionPhase.ended) return;

    _ticker?.cancel();
    _heartbeat?.cancel();
    await _recognition?.cancel();
    await _reply?.cancel();
    await ref.read(speechRecognitionServiceProvider).cancel();
    await ref.read(ttsServiceProvider).stop();
    _closePartnerTurn(interrupted: true);

    final duration = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);

    // R4.3.1, on the device, with no model call — so it works with no network
    // and a free user gets real value (R8.0.1).
    final metrics = const MetricsEngine().compute(
      [for (final turn in state.turns) turn.toTranscriptTurn()],
      locale: 'en',
      sessionDuration: duration,
    );

    final repository = ref.read(sessionRepositoryProvider);
    await repository.closeSession(
      state.localId!,
      duration: duration,
      metrics: metrics,
    );

    state = state.copyWith(
      phase: SessionPhase.ended,
      metrics: metrics,
      elapsed: duration,
    );

    final token = ref.read(accessTokenProvider);
    final sessionId = state.serverSessionId;
    if (token != null && sessionId != null) {
      final closed = await ref
          .read(sessionClientProvider)
          .close(
            accessToken: token,
            sessionId: sessionId,
            duration: duration,
            metrics: metrics,
          );
      if (closed case Ok()) {
        await repository.markSynced(state.localId!);
      }
      // A failed close leaves the row unsynced and the server session open.
      // Both recover: the next `open_voice_session` sweeps the stale row, and
      // `pendingSync` retries the report.
    }

    Log.d(
      'session: ended after ${duration.inSeconds}s, '
      '${state.turns.length} turns, median first-word latency '
      '${state.medianLatency?.inMilliseconds}ms ($reason)',
    );
  }

  void _teardown() {
    _ticker?.cancel();
    _heartbeat?.cancel();
    _recognition?.cancel();
    _reply?.cancel();
    _connectivity?.cancel();
    _lifecycle?.dispose();
    _amplitudes.dispose();
    unawaited(ref.read(audioInterruptionServiceProvider).dispose());
  }
}

enum SessionEndReason { user, quotaExhausted, lengthReached, failure }
