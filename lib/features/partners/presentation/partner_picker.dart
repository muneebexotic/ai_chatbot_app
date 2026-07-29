import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/design/waveform/waveform.dart';
import 'package:speakwise/features/partners/application/partner_providers.dart';
import 'package:speakwise/features/partners/domain/partner.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// A partner's generated mark (R5.3.1), drawn by the app's one visualization.
///
/// See `Partner.markAmplitudes` for why this is a waveform and not an icon.
class PartnerMark extends StatefulWidget {
  const PartnerMark({super.key, required this.partner, this.width = 44});

  final Partner partner;
  final double width;

  @override
  State<PartnerMark> createState() => _PartnerMarkState();
}

class _PartnerMarkState extends State<PartnerMark> {
  /// Held rather than rebuilt.
  ///
  /// `AmplitudeWindow.fixed` never notifies, so a painter bound to it is never
  /// asked to repaint — but a *new* window on each build is a new identity, and
  /// `shouldRepaint` compares the window by identity. Caching it is what keeps
  /// a scrolling list of partner rows from repainting every mark on every
  /// frame of the scroll.
  late AmplitudeWindow _mark = AmplitudeWindow.fixed(
    widget.partner.markAmplitudes(12),
  );

  @override
  void didUpdateWidget(covariant PartnerMark old) {
    super.didUpdateWidget(old);
    if (old.partner.id != widget.partner.id) {
      _mark = AmplitudeWindow.fixed(widget.partner.markAmplitudes(12));
    }
  }

  @override
  Widget build(BuildContext context) {
    // `Align` is load-bearing and this is the SECOND time this project has
    // learned it. Milestone 3's device pass (`qa/m3-device-pass.md` D2) found
    // `SizedBox(width: 72)` doing nothing inside a `ListView`, because a list
    // item receives a TIGHT cross-axis constraint and `SizedBox` enforces its
    // own constraints only within the incoming ones — so 72 clamps back up to
    // the viewport width.
    //
    // It happened again here: the mark rendered correctly in the horizontal
    // partner rail (whose items are width-bounded) and stretched across the
    // whole screen on the brief screen, whose ListView is vertical. `Align`
    // loosens the constraint first, which is what lets the width mean what it
    // says.
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: widget.width,
        // Static mode: no ticker, so a list of these costs nothing per frame.
        child: Waveform(
          amplitudes: _mark,
          mode: WaveformMode.static_,
          barCount: 12,
          height: widget.width * 0.6,
        ),
      ),
    );
  }
}

/// Choosing who you are talking to (§5.3).
///
/// A sheet rather than a dropdown: R4.1.1 gives partners a horizontal rail on
/// the session home, and this is the typed-chat equivalent — enough room for a
/// name, a one-line description, and the mark, which is what makes the choice
/// meaningful rather than a list of words.
///
/// The old `personas_screen.dart` was a full route with premium padlocks drawn
/// from `Personas.isPersonaPremium(id)` — a client reading a hardcoded map to
/// decide its own entitlement (F2). What a user may talk to now comes back from
/// the server, and the gateway refuses anything else regardless of what the app
/// shows.
Future<Partner?> showPartnerPicker(BuildContext context, String? selectedId) {
  return showModalBottomSheet<Partner>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _PartnerSheet(selectedId: selectedId),
  );
}

class _PartnerSheet extends ConsumerWidget {
  const _PartnerSheet({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final partners = ref.watch(partnersProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radii.sheet),
        border: Border.all(color: colors.line),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle. The one place a filled bar is not accent misuse:
            // it is chrome, in `line`, not in `signal`.
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: Space.sm),
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: Radii.fullAll,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
              child: Text(
                l10n.partnersTitle,
                style: AppTypography.title2.copyWith(color: colors.ink),
              ),
            ),
            Flexible(
              child: partners.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(Space.xl),
                  // §16: no spinner where the waveform can idle instead.
                  child: Waveform(mode: WaveformMode.idle, height: 48),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Text(
                    l10n.partnersUnavailable,
                    style: AppTypography.body2.copyWith(color: colors.muted),
                  ),
                ),
                data: (list) => ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: Space.md),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _PartnerRow(
                    partner: list[index],
                    selected: list[index].id == selectedId,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerRow extends StatelessWidget {
  const _PartnerRow({required this.partner, required this.selected});

  final Partner partner;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () {
          // R7.7.3: selection click on partner change.
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(partner);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: Touch.minTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          color: selected ? colors.surfaceRaised : Colors.transparent,
          child: Row(
            children: [
              PartnerMark(partner: partner),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      style: AppTypography.body2.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      partner.description,
                      style: AppTypography.label.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: colors.signal),
            ],
          ),
        ),
      ),
    );
  }
}
