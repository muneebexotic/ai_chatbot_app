/// Reads `lib/` as syntax rather than as text, for the rules that need to know
/// the difference between code and copy.
///
/// ## Why this exists
///
/// `architecture_test.dart` originally matched banned features by identifier —
/// `ImageGenerationService`, `CloudinaryService`. That catches the code and
/// misses the product. Milestone 2 shipped with **"Generate Avatar"** on the
/// profile-photo screen and **"Create Image"** on the chat empty state: image
/// generation, banned outright by §16, offered to the user in the first thirty
/// seconds of the app. Both survived because deleting the generation
/// *services* left no compile error behind in a constants list, and no test
/// read the list (CRITIQUE.md W2.1).
///
/// A grep would have found those two strings. A grep would also have found the
/// paragraphs in `suggestion_data.dart` and `CRITIQUE.md` that *describe* them
/// in order to explain their removal, and a rule that cries wolf on its own
/// changelog is a rule people disable. Parsing gets both: comments are simply
/// not in the tree, so prose about a banned feature is invisible while a
/// string literal offering it is not.
///
/// The same tree answers R11.7, which needs the opposite question — which
/// literals a person can actually read — and that is a question about
/// syntactic position, not about words.
library;


import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// One string literal in `lib/`, with the syntax around it.
class DartString {
  const DartString({
    required this.path,
    required this.line,
    required this.value,
    required this.owner,
    required this.argument,
  });

  /// Repo-relative, with forward slashes on every platform.
  final String path;
  final int line;

  /// The literal's text. Interpolated expressions collapse to `{}`, so
  /// `'Hello $name'` reads as `Hello {}` — the words are preserved and the
  /// expression is not mistaken for copy.
  final String value;

  /// The nearest enclosing constructor or method, e.g. `Text`,
  /// `AppText.bodyLarge`, `SnackBar`. Empty when the literal is not an
  /// argument to anything.
  final String owner;

  /// The nearest enclosing named argument, e.g. `hintText`, `semanticLabel`.
  /// Empty for a positional argument.
  final String argument;

  String get location => '$path:$line';

  @override
  String toString() => '$location  ${_describe()}  "$value"';

  String _describe() {
    if (owner.isEmpty && argument.isEmpty) return '<bare>';
    if (argument.isEmpty) return owner;
    if (owner.isEmpty) return '$argument:';
    return '$owner($argument:)';
  }
}

/// Generated code that happens to live in `lib/`.
///
/// Flutter dropped the synthetic `package:flutter_gen`, so `gen-l10n` now
/// writes `AppLocalizations` next to the ARB files. It is a build artefact, it
/// is gitignored, and it contains every user-facing string in the app by
/// definition — scanning it would make the R11.7 rule assert that the fix for
/// R11.7 violates R11.7.
bool isGenerated(File file) {
  final path = relativePath(file);
  return path.startsWith('lib/l10n/app_localizations') ||
      path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart');
}

/// Every hand-written `.dart` file under [directory], sorted so failure output
/// is stable.
List<File> dartFilesUnder(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const [];
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !isGenerated(f))
      .toList();
  files.sort((a, b) => relativePath(a).compareTo(relativePath(b)));
  return files;
}

/// `lib\screens\chat_screen.dart` → `lib/screens/chat_screen.dart`.
///
/// Windows is the development machine here and CI is Linux; a baseline file
/// keyed on the native separator would pass on one and fail on the other.
String relativePath(File file) =>
    file.path.replaceAll(r'\', '/').replaceFirst(RegExp(r'^\./'), '');

/// Every string literal in [file], in source order.
///
/// Comments are absent by construction — they are not nodes. Neither are
/// import URIs, which are [StringLiteral]s in the grammar but are filtered
/// out here because no one reads them.
List<DartString> stringLiteralsIn(File file) {
  final result = parseString(
    content: file.readAsStringSync(),
    // A parse error should fail loudly rather than silently exempt a file
    // from every rule in this suite — an unparseable file is exactly where
    // something unreviewed would hide.
    throwIfDiagnostics: true,
    path: file.path,
  );
  final visitor = _StringVisitor(relativePath(file), result.lineInfo.getLocation);
  result.unit.accept(visitor);
  return visitor.found;
}

/// All string literals under `lib/`.
List<DartString> allLibStrings() => [
  for (final file in dartFilesUnder('lib')) ...stringLiteralsIn(file),
];

// ── R11.7: which literals a person can actually read ─────────────────────────

/// Constructors and factories whose positional text argument is read by a
/// human. Matched on the identifier before the dot, so `AppText.bodyLarge`,
/// `AppText.displayMedium`, and every future member are covered by `AppText`.
///
/// This list is deliberately about *rendering*, not about intent. A literal
/// reaching `Text` is on screen whatever the author meant by it.
const _textOwners = {
  'Text',
  'SelectableText',
  'RichText',
  'TextSpan',
  'AppText',
  'GptMarkdown',
  'MarkdownBody',
  'Tooltip',
  'SnackBar',
  'AlertDialog',
  'SimpleDialog',
  'ListTile',
  'SwitchListTile',
  'CheckboxListTile',
  'RadioListTile',
  'ExpansionTile',
  'AppBar',
  'Semantics',
  'AppButton',
  'ElevatedButton',
  'TextButton',
  'OutlinedButton',
  'FilledButton',
  'PopupMenuItem',
  'DropdownMenuItem',
  'Chip',
  'ActionChip',
  'InputChip',
  'FilterChip',
  'Tab',
  'InputDecoration',
};

/// Named arguments that carry copy regardless of what they are passed to.
///
/// `semanticLabel` is here because R11.6 requires a screen reader to work
/// through the whole flow, and a label nobody translated is a screen a blind
/// Urdu speaker cannot use. It is user-facing even though it is never drawn.
const _textArguments = {
  'text',
  'title',
  'subtitle',
  'label',
  'labelText',
  'hintText',
  'helperText',
  'errorText',
  'counterText',
  'prefixText',
  'suffixText',
  'message',
  'tooltip',
  'semanticLabel',
  'content',
  'placeholder',
  'confirmText',
  'cancelText',
  'buttonText',
  'description',
};

/// True when [literal] is copy rather than code.
///
/// Judged by *syntactic position*, never by how the words look. "Rate limited"
/// and "rate_limited" are both prose-shaped; only one of them is on a screen.
/// A word-shape heuristic would have to guess about `Log.d('Signing out')`,
/// `throw Exception('User not authenticated')`, and every asset path, and it
/// would guess wrong often enough to get itself deleted.
bool isUserFacing(DartString literal) {
  final value = literal.value.trim();
  // Empty and punctuation-only literals are spacing, not copy: `Text('')` is a
  // layout placeholder and `Text('·')` is a separator. Neither needs Urdu.
  if (value.isEmpty || !RegExp(r'[A-Za-z]').hasMatch(value)) return false;

  if (_textArguments.contains(literal.argument)) return true;

  final owner = literal.owner.split('.').first;
  return _textOwners.contains(owner);
}

/// Hardcoded copy in [file] — the R11.7 violations.
List<DartString> userFacingStringsIn(File file) =>
    stringLiteralsIn(file).where(isUserFacing).toList();

/// Hardcoded copy across `lib/`.
List<DartString> hardcodedUserFacingStrings() => [
  for (final file in dartFilesUnder('lib')) ...userFacingStringsIn(file),
];

/// Path to the ratchet file. One place, so the test and the updater cannot
/// disagree about where it lives.
const l10nBaselinePath = 'test/l10n_baseline.txt';

/// Reads `path count` pairs, ignoring `#` comments and blank lines.
Map<String, int> readL10nBaseline() {
  final file = File(l10nBaselinePath);
  if (!file.existsSync()) return {};
  final baseline = <String, int>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split(RegExp(r'\s+'));
    baseline[parts.first] = int.parse(parts.last);
  }
  return baseline;
}

class _StringVisitor extends RecursiveAstVisitor<void> {
  _StringVisitor(this.path, this.locate);

  final String path;
  final CharacterLocation Function(int offset) locate;
  final found = <DartString>[];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _record(node, node.value);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _record(node, _flatten(node));
    // Deliberately not `super`: the literal is recorded whole, and recursing
    // would record each `InterpolationString` fragment again as its own
    // string. The interpolated *expressions* are still visited, because a
    // banned string can hide inside one.
    for (final element in node.elements) {
      if (element is InterpolationExpression) element.expression.accept(this);
    }
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    // `'a long line ' 'continued here'` is one string to a reader and three
    // nodes to the parser. Record the joined text so a banned phrase cannot
    // hide in the seam, and skip the parts.
    _record(node, node.strings.map(_valueOf).join());
  }

  @override
  void visitImportDirective(ImportDirective node) {}

  @override
  void visitExportDirective(ExportDirective node) {}

  @override
  void visitPartDirective(PartDirective node) {}

  // Exhaustive: `StringLiteral` has exactly these three subtypes, and the
  // analyzer rejects a default clause here because of it. That is a feature —
  // if the grammar grows a fourth, this stops compiling rather than silently
  // stringifying a node whose text is not its value.
  String _valueOf(StringLiteral node) => switch (node) {
    SimpleStringLiteral() => node.value,
    StringInterpolation() => _flatten(node),
    AdjacentStrings() => node.strings.map(_valueOf).join(),
  };

  String _flatten(StringInterpolation node) => node.elements
      .map((e) => e is InterpolationString ? e.value : '{}')
      .join();

  void _record(AstNode node, String value) {
    final (owner, argument) = _contextOf(node);
    found.add(
      DartString(
        path: path,
        line: locate(node.offset).lineNumber,
        value: value,
        owner: owner,
        argument: argument,
      ),
    );
  }

  /// Walks outward to the nearest invocation and the nearest named argument.
  ///
  /// Stops at a body or declaration boundary so a literal deep inside a
  /// closure is not attributed to whatever the closure was passed to.
  (String, String) _contextOf(AstNode node) {
    var argument = '';
    var owner = '';
    for (AstNode? p = node.parent; p != null; p = p.parent) {
      if (p is NamedExpression) {
        argument = argument.isEmpty ? p.name.label.name : argument;
        continue;
      }
      if (p is InstanceCreationExpression) {
        owner = p.constructorName.toString();
        break;
      }
      if (p is MethodInvocation) {
        final target = p.target;
        owner = target is SimpleIdentifier
            ? '${target.name}.${p.methodName.name}'
            : p.methodName.name;
        break;
      }
      // A closure body, a statement, or a declaration: the literal belongs to
      // whatever is inside, not to the enclosing call.
      if (p is FunctionBody || p is Declaration || p is Statement) break;
    }
    return (owner, argument);
  }
}
