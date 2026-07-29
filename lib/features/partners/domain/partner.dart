/// A speaking partner (PRD §5.3).
///
/// R5.3.1 lists: "name, avatar (generated geometric mark, not an uploaded
/// photo, in v1), one-line description, system prompt, voice settings (rate,
/// pitch), difficulty (for practice partners), and locale."
///
/// **There is no `systemPrompt` field here, and that is not an oversight.**
/// R9.3.2 makes the prompt server-decided, and the column is revoked from the
/// `authenticated` role in Postgres (migration 20260728140000) — a client
/// cannot select it even by asking. The gateway reads it under service role and
/// builds the prompt where the client cannot see or influence it.
///
/// The avatar is derived, not stored: [mark] turns the id into a geometric
/// shape. §5.3.1 says a v1 avatar is a generated mark rather than an upload,
/// which is also what let the profile-photo screen and its DiceBear call be
/// deleted outright (§16 — it was image generation).
class Partner {
  const Partner({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.locale,
    required this.isBuiltin,
    this.voiceRate = 1.0,
    this.voicePitch = 1.0,
    this.openingLine,
  });

  factory Partner.fromRow(Map<String, dynamic> row) => Partner(
    id: row['id'] as String,
    name: row['name'] as String,
    description: row['description'] as String? ?? '',
    difficulty: (row['difficulty'] as num?)?.toInt() ?? 2,
    locale: row['locale'] as String? ?? 'en',
    isBuiltin: row['is_builtin'] as bool? ?? false,
    voiceRate: (row['voice_rate'] as num?)?.toDouble() ?? 1.0,
    voicePitch: (row['voice_pitch'] as num?)?.toDouble() ?? 1.0,
    openingLine: row['opening_line'] as String?,
  );

  /// The exact column list a client is permitted to read. Named here rather
  /// than spelled out at each call site because `select('*')` now fails
  /// outright — see the migration — and a forgotten column list is a runtime
  /// 42501 rather than a compile error.
  static const columns =
      'id, name, description, difficulty, locale, is_builtin, '
      'voice_rate, voice_pitch, opening_line';

  final String id;
  final String name;
  final String description;

  /// 1–5. Used by practice partners; ignored by Free Talk.
  final int difficulty;

  final String locale;
  final bool isBuiltin;

  /// Text-to-speech settings, applied in Milestone 4. Carried now because they
  /// are part of the row and dropping them would mean a second query later.
  final double voiceRate;
  final double voicePitch;

  /// R4.1.3's example opening line, shown on the brief screen.
  ///
  /// Data, not a constant in Dart (§5.3.2): a hardcoded line would go stale the
  /// first time somebody edited this partner's prompt in the database, and the
  /// mismatch would be invisible — the brief would promise one thing and the
  /// partner would do another. Null for a partner that has not been given one.
  final String? openingLine;

  /// The partner's geometric mark, as waveform amplitudes (R5.3.1).
  ///
  /// R5.3.1 asks for "a generated geometric mark, not an uploaded photo", and
  /// §7.5.3 says **never introduce a second visualization style**. Those two
  /// resolve into one answer: the mark is a waveform. Same painter, same code,
  /// drawn in static mode from a shape derived from the id — so a partner looks
  /// like it belongs to this app and not like a stock avatar dropped into it.
  ///
  /// Deterministic, because a mark that changes between devices or after a
  /// reinstall is not recognisable, and being recognisable is its only job. A
  /// small xorshift over the id gives a stable, well-spread shape without
  /// pulling in a hashing package.
  List<double> markAmplitudes([int bars = 18]) {
    var seed = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      seed = ((seed ^ unit) * 0x01000193) & 0xffffffff;
    }
    return List<double>.generate(bars, (i) {
      seed ^= (seed << 13) & 0xffffffff;
      seed ^= seed >> 17;
      seed ^= (seed << 5) & 0xffffffff;
      seed &= 0xffffffff;
      // 0.25 floor: a bar at zero reads as a gap rather than as quiet, and a
      // mark with holes in it looks broken rather than distinctive.
      return 0.25 + (seed % 1000) / 1000 * 0.75;
    });
  }
}
