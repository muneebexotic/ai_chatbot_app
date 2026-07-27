import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Executable versions of the layering rules in PRD §9.1.
///
/// F3 ("`BuildContext` inside services") survived a year because it was a
/// convention nobody could run. A convention that cannot fail a build is a
/// preference. These tests read the source and fail if the rules are broken,
/// so the next person to reach for `Provider.of` inside a service finds out in
/// CI rather than in review — or not at all.
void main() {
  final libDir = Directory('lib');

  List<File> dartFilesIn(String relativePath) {
    final dir = Directory('lib/$relativePath');
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
  }

  /// Strips `//` and `///` comments so a rule is not tripped by prose about
  /// the rule — several files legitimately explain why they do NOT do these
  /// things.
  String codeOf(File file) => file
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('PRD §9.1 — services never know about the widget tree', () {
    test('no service takes or stores a BuildContext (F3)', () {
      final offenders = <String>[];
      for (final file in dartFilesIn('services')) {
        if (codeOf(file).contains('BuildContext')) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These services reference BuildContext, which is F3. Inject plain '
            'dependencies through the constructor instead:\n${offenders.join('\n')}',
      );
    });

    test('no service imports flutter/material', () {
      final offenders = <String>[];
      for (final file in dartFilesIn('services')) {
        if (codeOf(file).contains("package:flutter/material.dart")) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'A service importing Material is how presentation concerns leak '
            'into the data layer:\n${offenders.join('\n')}',
      );
    });

    test('no provider or controller stores a BuildContext as a field', () {
      // Holding a context is the same defect as a service holding one, one
      // layer up: it forces a liveness check before every use and makes the
      // class impossible to drive in a test without a widget tree.
      // `ChatProvider` was exactly this.
      //
      // HISTORY. This assertion originally covered `providers/` and
      // `controllers/`, failed on login_controller and welcome_controller, and
      // was narrowed to `providers/` with a justification. Narrowing a rule
      // because it caught something is how F3 survived a year in the first
      // place, so the controllers were fixed instead and the original scope
      // restored. Both now take a BuildContext per call. See CRITIQUE.md W1.3.
      final pattern = RegExp(r'final\s+BuildContext\s+\w+\s*;');
      final offenders = <String>[];
      for (final dir in ['providers', 'controllers']) {
        for (final file in dartFilesIn(dir)) {
          if (pattern.hasMatch(codeOf(file))) offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Storing a BuildContext on a long-lived object outlives the widget '
            'that provided it. Pass it per call instead:\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('PRD F5 — Provider is fully migrated to Riverpod', () {
    test('nothing imports package:provider', () {
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (codeOf(entity).contains('package:provider/')) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'F5 forbids ending a milestone half-Provider:\n${offenders.join('\n')}',
      );
    });

    test('no Provider.of / context.read / context.watch remains', () {
      final pattern = RegExp(r'Provider\.of<|context\.read<|context\.watch<');
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (pattern.hasMatch(codeOf(entity))) offenders.add(entity.path);
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('PRD §2.2 — cut features stay cut', () {
    test('no image-generation or Cloudinary code', () {
      final pattern = RegExp(
        r'ImageGenerationProvider|ImageGenerationService|GeneratedImage\b|CloudinaryService|api\.cloudinary\.com',
      );
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (pattern.hasMatch(codeOf(entity))) offenders.add(entity.path);
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('no banned typeface is referenced', () {
      // §7 anti-brief and §16. Poppins and Urbanist were deleted from assets;
      // this stops a stray fontFamily string resurrecting them as a silent
      // fallback to the platform default.
      final banned = [
        'Poppins',
        'Urbanist',
        'Montserrat',
        'Space Grotesk',
      ];
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final code = codeOf(entity);
        for (final font in banned) {
          if (code.contains("'$font'") || code.contains('"$font"')) {
            offenders.add('${entity.path}: $font');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('android and ios are the only platform folders', () {
      for (final gone in ['web', 'windows', 'macos', 'linux']) {
        expect(
          Directory(gone).existsSync(),
          isFalse,
          reason: '$gone/ was deleted in Milestone 1 (PRD §2.2)',
        );
      }
      expect(Directory('android').existsSync(), isTrue);
      expect(Directory('ios').existsSync(), isTrue);
    });
  });

  group('PRD §16 — no print in release', () {
    test('lib/ uses Log, not print or debugPrint', () {
      final pattern = RegExp(r'(?<![\w.])(print|debugPrint)\s*\(');
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('log.dart')) continue;
        if (pattern.hasMatch(codeOf(entity))) offenders.add(entity.path);
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use Log, which compiles out in release:\n${offenders.join('\n')}',
      );
    });
  });
}
