import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_source.dart';

/// Executable version of R11.7: "No hardcoded user-facing strings anywhere in
/// `lib/`."
///
/// ## Why a baseline and not a flat zero
///
/// A flat zero today would be a lie or a bonfire. `lib/` still contains the
/// pre-rebuild app — around twenty screens that Milestones 3 to 6 delete
/// outright — and extracting their copy into ARB would be several hundred keys
/// thrown away within weeks, done against strings §7.6 is going to rewrite
/// anyway. That is exactly the argument DECISIONS.md D4 made for keeping three
/// markdown renderers one milestone longer.
///
/// So the rule is a ratchet instead. `test/l10n_baseline.txt` records how many
/// unextracted strings each file still holds. The test fails when:
///
///   * a file **not** in the baseline gains one — which is every new file, so
///     everything written from Milestone 3 onward is localized from birth;
///   * a file in the baseline **grows**;
///   * a file in the baseline **shrinks** and the baseline was not updated —
///     the ratchet only turns one way, and a stale baseline is slack that
///     someone eventually spends.
///
/// The last of those is the one that makes this honest. A baseline that is
/// allowed to be generous stops measuring anything.
///
/// Regenerate with:
///
/// ```
/// dart run test/tool/update_l10n_baseline.dart
/// ```
void main() {
  group('R11.7 — ARB is the source of user-facing copy', () {
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;

    test('every message has a description', () {
      // A translator sees the string and nothing else. "Skip" is a verb or a
      // noun depending on the screen, and Urdu needs to know which. The
      // description is the only channel for that, so an undescribed key is an
      // unanswerable question posted to whoever translates next.
      final undescribed = <String>[];
      for (final key in arb.keys) {
        if (key.startsWith('@')) continue;
        final meta = arb['@$key'];
        final description = meta is Map ? meta['description'] : null;
        if (description is! String || description.trim().isEmpty) {
          undescribed.add(key);
        }
      }
      expect(
        undescribed,
        isEmpty,
        reason:
            'These ARB keys have no @description:\n${undescribed.join('\n')}',
      );
    });

    test('no metadata entry is orphaned', () {
      // An `@foo` with no `foo` is a key that was renamed or deleted and left
      // its documentation behind, which then describes the wrong string.
      final orphans = [
        for (final key in arb.keys)
          if (key.startsWith('@') && key != '@@locale')
            if (!arb.containsKey(key.substring(1))) key,
      ];
      expect(orphans, isEmpty, reason: orphans.join('\n'));
    });

    test('no message ends in an exclamation mark or carries an emoji', () {
      // §7.6, applied where it is now cheap to apply: "no exclamation marks,
      // no emoji in UI copy". Enforced on the ARB rather than on all of `lib/`
      // because the ARB is the copy that survives — the legacy screens have
      // both and are being deleted.
      final emoji = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]',
        unicode: true,
      );
      final offenders = <String>[];
      for (final entry in arb.entries) {
        if (entry.key.startsWith('@')) continue;
        final value = entry.value as String;
        if (value.contains('!')) offenders.add('${entry.key}: exclamation');
        if (emoji.hasMatch(value)) offenders.add('${entry.key}: emoji');
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('R11.7 — no new hardcoded user-facing strings', () {
    test('lib/ does not drift away from the baseline', () {
      final actual = <String, int>{};
      for (final literal in hardcodedUserFacingStrings()) {
        actual[literal.path] = (actual[literal.path] ?? 0) + 1;
      }
      final baseline = readL10nBaseline();

      final problems = <String>[];

      for (final entry in actual.entries) {
        final allowed = baseline[entry.key];
        if (allowed == null) {
          problems.add(
            'NEW  ${entry.key} has ${entry.value} hardcoded user-facing '
            'string(s). Put them in lib/l10n/app_en.arb and read them through '
            'AppLocalizations.of(context).',
          );
        } else if (entry.value > allowed) {
          problems.add(
            'GREW ${entry.key}: $allowed allowed, ${entry.value} found. '
            'Do not add copy to a file that is waiting to be extracted.',
          );
        }
      }

      for (final entry in baseline.entries) {
        final found = actual[entry.key] ?? 0;
        if (found < entry.value) {
          problems.add(
            'SHRANK ${entry.key}: baseline says ${entry.value}, only $found '
            'left. Good — now lower the baseline: '
            'dart run test/tool/update_l10n_baseline.dart',
          );
        }
      }

      expect(
        problems,
        isEmpty,
        reason:
            'R11.7: user-facing copy belongs in lib/l10n/*.arb.\n\n'
            '${problems.join('\n')}\n',
      );
    });

    test('the detector finds copy and ignores code', () {
      // Same discipline as the §16 entry-point rule: a heuristic that is never
      // exercised against known answers is a heuristic nobody can trust to
      // fail correctly.
      //
      // These fixtures are parsed exactly as `lib/` is, so a change to the
      // detector shows up here before it shows up as a silently empty result.
      final tmp = Directory.systemTemp.createTempSync('kalaam_l10n_test');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final file = File('${tmp.path}/sample.dart')
        ..writeAsStringSync('''
import 'package:flutter/material.dart';

class Sample extends StatelessWidget {
  const Sample({super.key});

  @override
  Widget build(BuildContext context) {
    Log.d('a debug line nobody reads');
    Navigator.pushNamed(context, '/settings');
    return Column(
      children: [
        const Text('Start speaking'),
        AppText.bodyMedium('You have 3 minutes left today'),
        Image.asset('assets/logo.png'),
        const TextField(
          decoration: InputDecoration(hintText: 'Type a message'),
        ),
        Semantics(label: 'Microphone level', child: const SizedBox()),
        Text(AppLocalizations.of(context).appName),
        const Text(''),
        const Text('  '),
      ],
    );
  }
}
''');

      final found = userFacingStringsIn(file).map((s) => s.value).toSet();
      expect(found, {
        'Start speaking',
        'You have 3 minutes left today',
        'Type a message',
        'Microphone level',
      });
    });
  });
}
