/// Build-time configuration (PRD R9.6).
///
/// Values arrive by `--dart-define`, never from a `.env` file read at runtime.
/// `flutter_dotenv` is not a dependency and must not become one: a `.env` sat
/// in this repo for months with a live token in it precisely because it was a
/// dead file nobody looked at (`SECURITY-REMEDIATION.md`).
///
/// ## Why these two are safe to ship
///
/// The Supabase URL and publishable key are public by design. Security comes
/// from Row Level Security, not from hiding them — R9.6 says so outright, and
/// the RLS tests in `test/rls/` are what make that claim true rather than
/// hopeful. The publishable key grants exactly what an unauthenticated caller
/// is allowed, which the policies define as almost nothing.
///
/// The *secret* key is a different animal entirely. It bypasses RLS. It lives
/// in Supabase Function secrets, is read only by Edge Functions, and must
/// never appear in a `--dart-define`, in this file, or anywhere else the
/// client can reach. If you are about to add one here, re-read `SECURITY.md`.
abstract final class AppConfig {
  const AppConfig._();

  /// e.g. `https://<ref>.supabase.co`
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The `sb_publishable_...` key. Named for the current Supabase key format;
  /// projects created before it shipped call the equivalent value `anon`.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Fails closed and loudly, naming the fix.
  ///
  /// A missing URL produces a confusing socket error several layers down; a
  /// missing key produces a 401 that reads like a policy bug. Both waste more
  /// time than this check costs.
  static void assertConfigured() {
    if (hasSupabase) return;
    throw StateError(
      'Supabase is not configured. Run with:\n'
      '  --dart-define=SUPABASE_URL=https://<ref>.supabase.co\n'
      '  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...\n'
      'Both are public by design (PRD R9.6). See .env.example for the names '
      'and README.md for where to find the values.',
    );
  }
}
