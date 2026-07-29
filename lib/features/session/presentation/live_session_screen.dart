import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/design/waveform/waveform.dart';
import 'package:speakwise/features/session/application/session_providers.dart';
import 'package:speakwise/features/session/domain/session_settings.dart';
import 'package:speakwise/features/session/domain/session_state.dart';
import 'package:speakwise/features/session/presentation/widgets/crisis_card.dart';
import 'package:speakwise/features/session/presentation/widgets/session_controls.dart';
import 'package:speakwise/features/session/presentation/widgets/session_notices.dart';
import 'package:speakwise/features/session/presentation/widgets/session_transcript.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// The live session (PRD R4.2.1). The app's highest-value screen.
///
/// R4.2.1: "Full-screen, single-purpose, no navigation chrome. Contents:
/// partner name and state (listening / thinking / speaking), the Waveform
/// (§7.5) as the central element reacting to live mic amplitude, an elapsed
/// timer in mono type, a live transcript that scrolls, and three controls:
/// mute, mode toggle, end session."
///
/// ## The anti-generic check (R0.5.6)
///
/// "Would this screen be indistinguishable from any other AI app's version of
/// it?" Every voice assistant on the store draws a pulsing circle or an orb.
/// This draws the app's waveform — the same painter as the chat loading state,
/// the partner marks, and the report timeline (R7.5.3) — with a mono timer, a
/// red record dot that appears only while the microphone is genuinely hot
/// (R7.1.1), and a serif transcript that reads like an interview in print
/// rather than a column of chat bubbles (§7.2).
///
/// There is no `AppBar`. "No navigation chrome" is a requirement, and it is
/// also the point: nothing here competes with the conversation.
class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = ref.watch(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);
    final settings = ref.watch(sessionSettingsProvider);

    // R7.7.3: haptics carry meaning, and respect the settings toggle. A light
    // impact when the microphone opens is the one cue a user walking with the
    // phone in their hand can act on without looking.
    ref.listen(sessionControllerProvider, (previous, next) {
      if (!settings.haptics) return;
      if (previous?.phase == next.phase) return;
      switch (next.phase) {
        case SessionPhase.listening:
          HapticFeedback.lightImpact();
        case SessionPhase.ended:
          HapticFeedback.mediumImpact();
        case _:
          break;
      }
    });

    return PopScope(
      // Leaving by the back gesture must end the session properly rather than
      // abandoning a metering server row and a half-written transcript. The
      // sweep in `open_voice_session` would recover it, but recovering is not
      // the same as behaving.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await controller.end();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _Header(state: state),

              // R10.6: persistent, and above the transcript rather than below
              // it, because the transcript scrolls and this must not scroll
              // away.
              if (state.crisis != null) ...[
                const SizedBox(height: Space.sm),
                const CrisisCard(locale: 'en'),
              ],

              Expanded(
                child: SessionTranscript(
                  turns: state.turns,
                  partialText: state.partialText,
                ),
              ),

              SessionNotices(
                state: state,
                onSwitchToPushToTalk: () =>
                    controller.setInputMode(SessionInputMode.pushToTalk),
                onUseTyping: controller.useTypingFallback,
                onDismissNoise: controller.dismissNoiseSuggestion,
                onResume: controller.resume,
                onDismissFailure: controller.dismissFailure,
              ),

              _WaveformStage(state: state, controller: controller),

              SessionControls(
                state: state,
                onToggleMute: controller.toggleMute,
                onToggleMode: () => controller.setInputMode(
                  state.inputMode == SessionInputMode.handsFree
                      ? SessionInputMode.pushToTalk
                      : SessionInputMode.handsFree,
                ),
                onEnd: () async {
                  await controller.end();
                  if (context.mounted) Navigator.of(context).pop();
                },
                onSendTyped: controller.sendTyped,
                onBackToSpeaking: controller.returnToSpeaking,
              ),

              const SizedBox(height: Space.sm),
            ],
          ),
        ),
      ),
    );
  }
}

/// Partner name, state, and the elapsed timer (R4.2.1).
class _Header extends StatelessWidget {
  const _Header({required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final label = switch (state.phase) {
      SessionPhase.starting => l10n.sessionStateStarting,
      SessionPhase.listening => l10n.sessionStateListening,
      SessionPhase.thinking => l10n.sessionStateThinking,
      SessionPhase.speaking => l10n.sessionStateSpeaking,
      SessionPhase.paused => l10n.sessionStatePaused,
      SessionPhase.ended => l10n.sessionEnd,
    };

    final minutes = state.elapsed.inMinutes;
    final seconds = state.elapsed.inSeconds % 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.partnerName,
                  style: AppTypography.title2.copyWith(color: colors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.xxs),
                Semantics(
                  // §11.6: "the session screen announces state changes to
                  // screen readers". This is that announcement.
                  liveRegion: true,
                  child: Text(
                    label,
                    style: AppTypography.label.copyWith(
                      color: state.phase == SessionPhase.listening
                          ? colors.live
                          : colors.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // §7.2: Geist Mono for "timers, durations, word counts, pace, dates".
          Semantics(
            label: l10n.sessionElapsedSemantics(minutes, seconds),
            // A screen reader would otherwise read "zero four colon two zero"
            // character by character out of the mono digits.
            excludeSemantics: true,
            child: Text(
              '${minutes.toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')}',
              style: AppTypography.dataMedium.copyWith(color: colors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The waveform, as the central element and as the push-to-talk control
/// (R4.2.1, R7.5.1, R7.5.2).
class _WaveformStage extends ConsumerWidget {
  const _WaveformStage({required this.state, required this.controller});

  final SessionState state;
  final dynamic controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(sessionControllerProvider.notifier);

    if (state.isTypingFallback) return const SizedBox.shrink();

    final mode = switch (state.phase) {
      // The ONLY mode that paints `live` red, and only while the microphone is
      // genuinely capturing (R7.1.1). Muted is not capturing.
      SessionPhase.listening when !state.isMuted => WaveformMode.capturing,
      SessionPhase.speaking => WaveformMode.speaking,
      SessionPhase.paused => WaveformMode.static_,
      _ => WaveformMode.idle,
    };

    final waveform = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Waveform(
        // The live buffer. Read by the painter through its repaint listenable,
        // so none of this rebuilds per frame (R11.2).
        amplitudes: notifier.amplitudes,
        mode: mode,
        height: 96,
        barCount: 48,
        semanticLabel: state.partnerName,
      ),
    );

    if (state.inputMode != SessionInputMode.pushToTalk) return waveform;

    // R4.2.2: "hold the waveform to speak, release to send". §7.5.2 already
    // makes the waveform the record button; this is that use.
    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => notifier.pressToTalk(),
          onTapUp: (_) => notifier.releaseToTalk(),
          onTapCancel: notifier.releaseToTalk,
          behavior: HitTestBehavior.opaque,
          child: Semantics(
            button: true,
            label: l10n.sessionHoldToSpeak,
            child: waveform,
          ),
        ),
        const SizedBox(height: Space.xxs),
        Text(
          l10n.sessionHoldToSpeak,
          style: AppTypography.micro.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}
