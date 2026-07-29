import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/features/partners/domain/partner.dart';
import 'package:speakwise/features/partners/presentation/partner_picker.dart';
import 'package:speakwise/features/session/application/session_providers.dart';
import 'package:speakwise/features/session/presentation/live_session_screen.dart';
import 'package:speakwise/features/session/presentation/session_setup_screen.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// R4.1.3: "Selecting a partner opens a short brief screen: what this partner
/// does, an example opening line, and an optional one-line goal from the user
/// ('I have a frontend interview on Tuesday'). The goal is passed into the
/// session prompt and stored on the session record."
///
/// The opening line is a column on `partners`, not a constant here (§5.3.2:
/// "Built-in partners ship as data, not code, so they can be edited without a
/// release"). A line hardcoded in Dart would go stale the first time somebody
/// edited that partner's prompt, and the mismatch would be invisible.
///
/// It first shipped derived from `description`, which meant the brief showed
/// the same sentence twice — once as the summary and once under "How it opens".
/// Found by looking at the screen; it read as a bug because it was one.
class SessionBriefScreen extends ConsumerStatefulWidget {
  const SessionBriefScreen({super.key, required this.partner});

  final Partner partner;

  @override
  ConsumerState<SessionBriefScreen> createState() => _SessionBriefScreenState();
}

class _SessionBriefScreenState extends ConsumerState<SessionBriefScreen> {
  final _goal = TextEditingController();
  bool _starting = false;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);

    final settings = ref.read(sessionSettingsProvider);

    // R4.1.2: "Before the first session **only**". After that, tapping Start
    // goes straight to the session — a permission screen on every launch is the
    // fastest way to make people stop launching.
    final needsSetup =
        !settings.hasCompletedFirstRun ||
        !(await Permission.microphone.isGranted);

    // The permission check is an await, so the widget may be gone by now — the
    // user can leave while a system dialog is deciding. Checked rather than
    // assumed; this is the same class of mistake as F3, one layer up.
    if (!mounted) return;

    if (needsSetup) {
      final navigator = Navigator.of(context);
      final completed = await navigator.push<bool>(
        MaterialPageRoute(builder: (_) => const SessionSetupScreen()),
      );
      if (completed != true) {
        if (mounted) setState(() => _starting = false);
        return;
      }
    }

    if (!mounted) return;

    final goal = _goal.text.trim();
    await ref
        .read(sessionControllerProvider.notifier)
        .start(
          partnerId: widget.partner.id,
          partnerName: widget.partner.name,
          voiceRate: widget.partner.voiceRate,
          voicePitch: widget.partner.voicePitch,
          goal: goal.isEmpty ? null : goal,
        );

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LiveSessionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final partner = widget.partner;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            PartnerMark(partner: partner, width: 72),
            const SizedBox(height: Space.md),
            Text(
              partner.name,
              style: AppTypography.display3.copyWith(color: colors.ink),
            ),
            const SizedBox(height: Space.xs),
            Text(
              partner.description,
              style: AppTypography.body2.copyWith(color: colors.muted),
            ),

            const SizedBox(height: Space.xl),

            Text(
              l10n.sessionBriefExample,
              style: AppTypography.label.copyWith(
                color: colors.muted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: Space.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: Space.sm),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: colors.signal, width: 2)),
              ),
              child: Text(
                // Serif, like every other partner utterance in the app (§7.2).
                // The transcript's typography starts before the session does.
                partner.openingLine ?? partner.description,
                style: AppTypography.transcriptAi.copyWith(color: colors.ink),
              ),
            ),

            const SizedBox(height: Space.xl),

            Text(
              l10n.sessionBriefGoalLabel,
              style: AppTypography.title2.copyWith(color: colors.ink),
            ),
            const SizedBox(height: Space.xs),
            TextField(
              controller: _goal,
              // One line. The server collapses newlines and caps the length
              // anyway — this is free text that reaches a model prompt, which
              // makes it the one prompt-injection surface a session has.
              maxLines: 1,
              maxLength: 200,
              style: AppTypography.body2.copyWith(color: colors.ink),
              decoration: InputDecoration(
                hintText: l10n.sessionBriefGoalHint,
                hintStyle: AppTypography.body2.copyWith(color: colors.muted),
                helperText: l10n.sessionBriefGoalOptional,
                helperStyle: AppTypography.micro.copyWith(color: colors.muted),
              ),
            ),

            const SizedBox(height: Space.xl),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _starting ? null : _start,
                child: Text(l10n.sessionStartSpeaking),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
