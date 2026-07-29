import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/safety/crisis_resources.dart';
import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// R10.6's persistent resource card.
///
/// "the client MUST render a persistent card offering those resources."
///
/// ## Why it cannot be dismissed
///
/// "Persistent" is the requirement's own word. There is no close button here
/// and the controller never clears `SessionState.crisis` — a card that
/// disappears when the user carries on talking is a card that was shown to
/// nobody. The cost is a permanently visible band for the rest of the session,
/// which is the correct cost.
///
/// ## Why it does not look like an error
///
/// It uses `signal` amber and the ordinary card treatment, not `live` red and
/// not a warning icon. R7.1.1 reserves red for a hot microphone, and more
/// importantly: this is an offer, not an alarm. The app has matched a pattern
/// in a sentence — it has not assessed a person, and it must not present itself
/// as though it has. §7.6's voice is "plain, direct, a little dry", which is
/// also the right register for this.
class CrisisCard extends StatelessWidget {
  const CrisisCard({super.key, required this.locale});

  final String locale;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final resources = CrisisResources.forLocale(locale);

    return Semantics(
      container: true,
      // Announced when it appears, and it appears while the user is mid
      // conversation and probably not looking at the screen (§11.6).
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: Space.md),
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: Radii.cardAll,
          border: Border.all(color: colors.signal),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sessionCrisisTitle,
              style: AppTypography.title2.copyWith(color: colors.ink),
            ),
            const SizedBox(height: Space.xs),
            Text(
              l10n.sessionCrisisBody,
              style: AppTypography.body2.copyWith(color: colors.muted),
            ),
            const SizedBox(height: Space.sm),
            for (final resource in resources)
              _ResourceRow(resource: resource, locale: locale),
          ],
        ),
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.resource, required this.locale});

  final CrisisResource resource;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final label = switch (resource.kind) {
      CrisisResourceKind.emergencyServices => l10n.sessionCrisisEmergency,
      CrisisResourceKind.helplineDirectory => l10n.sessionCrisisDirectory,
    };

    final url = resource.url;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: InkWell(
        borderRadius: Radii.controlAll,
        onTap: url == null ? null : () => _open(url),
        child: Container(
          // §11.6: every touch target at least 48dp. A link somebody reaches
          // for in distress is the last place to make a small one.
          constraints: const BoxConstraints(minHeight: Touch.minTarget),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Row(
            children: [
              Icon(
                resource.kind == CrisisResourceKind.emergencyServices
                    ? Icons.call_outlined
                    : Icons.open_in_new_rounded,
                size: 18,
                color: colors.signal,
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body2.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      // Nothing is shown on failure, deliberately. Replacing a help link with
      // an error message at this moment would be worse than the link quietly
      // not opening — the emergency-services line above it needs no app.
      Log.w('crisis: could not open resource', error: error);
    }
  }
}
