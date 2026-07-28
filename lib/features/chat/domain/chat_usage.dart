/// What the server says about this account's allowance.
///
/// **The client displays this. It never enforces it.** That sentence is F2 and
/// it is the reason this class has no `canSend` method: a method like that
/// invites a caller to ask permission locally, and the answer would be a guess
/// that a patched APK can change. The gateway decides, every time, and says so
/// in the response.
///
/// Milestone 2 shipped the opposite — `PaymentService` counting messages in
/// local storage, resettable by reinstalling, with `isPremium` as a local
/// boolean carrying a comment asking callers not to trust it (CRITIQUE W2.2).
/// This type replaces that, and the counters it reports were written by the
/// gateway inside the same statement that authorised the call.
class ChatUsage {
  const ChatUsage({
    required this.used,
    required this.dailyLimit,
    required this.tier,
    required this.resetsAt,
  });

  factory ChatUsage.fromMeta(Map<String, dynamic> meta) => ChatUsage(
    used: (meta['used'] as num?)?.toInt() ?? 0,
    dailyLimit: (meta['dailyLimit'] as num?)?.toInt() ?? 0,
    tier: meta['tier'] as String? ?? 'free',
    resetsAt: switch (meta['resetsAt']) {
      final String s => DateTime.tryParse(s)?.toLocal(),
      _ => null,
    },
  );

  final int used;
  final int dailyLimit;
  final String tier;

  /// Server-computed. R8.3's acceptance test changes the device clock, so a
  /// locally derived midnight would be exactly the wrong answer.
  final DateTime? resetsAt;

  bool get isPro => tier == 'pro';
  int get remaining => (dailyLimit - used).clamp(0, dailyLimit);

  /// Whether to show the remaining count at all.
  ///
  /// Only in the last stretch. A counter visible from the first message turns
  /// every reply into a transaction, and §16 bans manufactured scarcity — a
  /// permanent "27 left" is a countdown timer with extra steps.
  bool get shouldWarn => !isPro && remaining <= 5;
}
