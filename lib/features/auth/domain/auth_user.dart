import 'package:flutter/foundation.dart';

/// The signed-in identity, and nothing else.
///
/// Deliberately much smaller than the `AppUser` it replaces. That class carried
/// identity, subscription tier, expiry dates, daily usage counters, device
/// info, and app version on one object, which meant every screen touching a
/// display name also depended on billing.
///
/// Under the PRD those live apart and are owned by the server:
/// entitlements in `entitlements`, counters in `usage_daily`, both
/// service-role write only (R9.5.1) because a client that can write them can
/// grant itself a subscription or reset its own quota. They are read through
/// their own repositories in Milestones 3 and 6.
///
/// So this holds identity alone, and is immutable — no setters, no lazy
/// refresh, no cache-validity flag.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.createdAt,
  });

  /// Supabase `auth.users.id`, and the foreign key every table in §9.5 hangs
  /// off. Also the value `auth.uid()` returns inside an RLS policy.
  final String id;

  final String email;

  /// From `profiles.display_name`, seeded at sign-up by the database trigger.
  /// Null is normal and must render as something sensible rather than "null".
  final String? displayName;

  final DateTime? createdAt;

  AuthUser copyWith({String? displayName}) => AuthUser(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthUser &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          createdAt == other.createdAt);

  @override
  int get hashCode => Object.hash(id, email, displayName, createdAt);

  /// No email in the string form. This gets interpolated into log lines, and
  /// the old codebase printed user identifiers straight to logcat where any
  /// app holding READ_LOGS could read them (`SECURITY-REMEDIATION.md` §1.5).
  @override
  String toString() => 'AuthUser($id)';
}
