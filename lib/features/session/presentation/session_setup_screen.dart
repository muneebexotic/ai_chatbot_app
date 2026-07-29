import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:speakwise/design/tokens/app_colors.dart';
import 'package:speakwise/design/tokens/app_metrics.dart';
import 'package:speakwise/design/tokens/app_typography.dart';
import 'package:speakwise/design/waveform/waveform.dart';
import 'package:speakwise/features/session/application/session_providers.dart';
import 'package:speakwise/features/session/data/speech_recognition_service.dart';
import 'package:speakwise/l10n/app_localizations.dart';

/// R4.1.2's first-run flow.
///
/// "Before the first session only, a 3-step permission and calibration flow:
/// microphone permission with a plain explanation of why, a 5-second mic level
/// check with live waveform, and a choice of session length (5 / 10 / 20
/// minutes or open-ended)."
///
/// R4.2.7 is discharged here too: "State this plainly in the UI on first run,
/// because it is both true and a genuine selling point." It sits on the
/// permission step rather than on a separate screen, because the moment the app
/// asks for a microphone is the moment the claim is worth something.
///
/// Returns true from the route when the flow completed.
class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

enum _Step { permission, calibrate, length }

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  _Step _step = _Step.permission;
  bool _permanentlyDenied = false;

  final _window = AmplitudeWindow();
  StreamSubscription<RecognitionEvent>? _levels;
  Timer? _countdown;
  int _secondsLeft = 5;
  double _peak = 0;
  bool _calibrationDone = false;

  @override
  void dispose() {
    _levels?.cancel();
    _countdown?.cancel();
    _window.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();

    if (status.isPermanentlyDenied) {
      // No in-app prompt can undo this. §7.6 requires an error to state its
      // fix, and the fix is a system settings page — offering "try again" here
      // would be advice that cannot work.
      setState(() => _permanentlyDenied = true);
      return;
    }
    if (!status.isGranted) return;

    setState(() {
      _permanentlyDenied = false;
      _step = _Step.calibrate;
    });
    await _startCalibration();
  }

  /// R4.1.2's five-second level check.
  ///
  /// It uses the real recogniser rather than a separate audio path, so what it
  /// proves is what the session will actually do. A calibration that passes
  /// through a different code path than the feature is a calibration that can
  /// pass while the feature is broken.
  Future<void> _startCalibration() async {
    final speech = ref.read(speechRecognitionServiceProvider);
    _peak = 0;
    _secondsLeft = 5;
    _calibrationDone = false;

    _levels?.cancel();
    _levels = speech.events.listen((event) {
      if (event is RecognitionLevel) {
        _window.push(event.amplitude);
        if (event.amplitude > _peak) _peak = event.amplitude;
      }
    });

    await speech.listen(localeId: 'en_US', listenFor: const Duration(seconds: 6));

    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        await speech.stop();
        await _levels?.cancel();
        if (mounted) setState(() => _calibrationDone = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: switch (_step) {
            _Step.permission => _permissionStep(),
            _Step.calibrate => _calibrateStep(),
            _Step.length => _lengthStep(),
          },
        ),
      ),
    );
  }

  Widget _permissionStep() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _permanentlyDenied
              ? l10n.sessionPermissionDeniedTitle
              : l10n.sessionPermissionTitle,
          style: AppTypography.display3.copyWith(color: colors.ink),
        ),
        const SizedBox(height: Space.sm),
        Text(
          _permanentlyDenied
              ? l10n.sessionPermissionDeniedBody
              : l10n.sessionPermissionBody,
          style: AppTypography.body2.copyWith(color: colors.muted),
        ),
        const SizedBox(height: Space.xl),

        // R4.2.7. Given its own bordered block rather than a line of small
        // print, because it is a claim the product is willing to be held to.
        Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.cardAll,
            border: Border.all(color: colors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: colors.good),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      l10n.sessionPrivacyTitle,
                      style: AppTypography.title2.copyWith(color: colors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                l10n.sessionPrivacyBody,
                style: AppTypography.body2.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),

        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _permanentlyDenied
                ? () => openAppSettings()
                : _requestPermission,
            child: Text(
              _permanentlyDenied
                  ? l10n.sessionOpenSettings
                  : l10n.sessionPermissionGrant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _calibrateStep() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // A peak that never cleared this is a microphone that is not picking the
    // user up — a broken headset, a covered port, or a very loud room drowning
    // them out. Better found here than in the first thirty seconds of a
    // session.
    const audibleFloor = 0.25;
    final wasAudible = _peak >= audibleFloor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sessionCalibrateTitle,
          style: AppTypography.display3.copyWith(color: colors.ink),
        ),
        const SizedBox(height: Space.sm),
        Text(
          l10n.sessionCalibrateBody,
          style: AppTypography.body2.copyWith(color: colors.muted),
        ),
        const Spacer(),

        // The signature element doing its primary job (R7.5.1), before the
        // session even starts.
        Waveform(
          amplitudes: _window,
          mode: _calibrationDone
              ? WaveformMode.static_
              : WaveformMode.capturing,
          height: 120,
        ),
        const SizedBox(height: Space.md),

        if (!_calibrationDone)
          Center(
            child: Text(
              '$_secondsLeft',
              style: AppTypography.display2.copyWith(color: colors.signal),
            ),
          )
        else
          Text(
            wasAudible ? l10n.sessionCalibrateGood : l10n.sessionCalibrateQuiet,
            style: AppTypography.body2.copyWith(
              color: wasAudible ? colors.good : colors.ink,
            ),
          ),

        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            // Enabled either way once the check is done. A quiet result is
            // advice, not a gate: refusing to let somebody continue because
            // their microphone read low would strand a user whose only problem
            // is a quiet voice.
            onPressed: _calibrationDone
                ? () => setState(() => _step = _Step.length)
                : null,
            child: Text(l10n.sessionContinue),
          ),
        ),
      ],
    );
  }

  Widget _lengthStep() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    Future<void> choose(Duration? length) async {
      await ref
          .read(sessionSettingsProvider.notifier)
          .completeFirstRun(preferredLength: length);
      if (mounted) Navigator.of(context).pop(true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sessionLengthTitle,
          style: AppTypography.display3.copyWith(color: colors.ink),
        ),
        const SizedBox(height: Space.lg),
        for (final minutes in [5, 10, 20])
          _LengthOption(
            label: l10n.sessionLengthMinutes(minutes),
            onTap: () => choose(Duration(minutes: minutes)),
          ),
        _LengthOption(
          label: l10n.sessionLengthOpen,
          onTap: () => choose(null),
        ),
        const Spacer(),
      ],
    );
  }
}

class _LengthOption extends StatelessWidget {
  const _LengthOption({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: InkWell(
        borderRadius: Radii.cardAll,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: Touch.minTarget),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: Radii.cardAll,
            border: Border.all(color: colors.line),
          ),
          child: Text(
            label,
            style: AppTypography.title2.copyWith(color: colors.ink),
          ),
        ),
      ),
    );
  }
}
