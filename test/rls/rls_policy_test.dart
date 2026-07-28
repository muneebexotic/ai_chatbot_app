@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Row Level Security tests — PRD R9.5.1, "write an RLS test per table".
///
/// ## Why these run against a real project
///
/// RLS is enforced by Postgres, so it cannot be unit tested. A mock proves
/// only that the mock behaves as written. These drive two genuinely separate
/// authenticated users through the same client library the app uses, so what
/// is verified is the path the app actually takes.
///
/// They point at **kalaam-dev**, never production. Test users and their rows
/// accumulate in whatever project you aim them at, which is the entire reason
/// a second project exists (§9.6).
///
/// ## Running them
///
///     flutter test test/rls/rls_policy_test.dart \
///       --dart-define=SUPABASE_URL=https://<dev-ref>.supabase.co \
///       --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
///
/// Without those defines every test is skipped rather than failed, so the
/// default `flutter test` sweep stays offline and green.
///
/// ## The trap these tests are written around
///
/// RLS blocks reads and writes by *different mechanisms*, and a test that
/// expects the same symptom for both is wrong:
///
/// * A **select** the policy forbids returns an empty result. No error.
/// * An **insert** the policy forbids raises `42501`.
/// * An **update or delete** the policy forbids affects **zero rows and does
///   not raise**. A test asserting "it threw" would pass against a database
///   with no RLS at all.
///
/// So every update/delete case below asserts through the *owner's* client that
/// the row is still there and unchanged. That is the only assertion that
/// distinguishes "blocked" from "silently did nothing on a table anyone can
/// write".
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Postgres SQLSTATE for insufficient_privilege, which is what a policy
/// violation surfaces as through PostgREST.
const _rlsViolation = '42501';

void main() {
  final configured = _url.isNotEmpty && _key.isNotEmpty;

  group(
    'RLS policies (R9.5.1)',
    skip: configured
        ? null
        : 'Set --dart-define=SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to run. '
              'Point them at kalaam-dev, never production.',
    () {
      late SupabaseClient alice;
      late SupabaseClient bob;
      late String aliceId;
      late String bobId;

      setUpAll(() async {
        alice = _testClient();
        bob = _testClient();

        aliceId = await _signUpFresh(alice, 'alice');
        bobId = await _signUpFresh(bob, 'bob');

        expect(
          aliceId,
          isNot(bobId),
          reason: 'the two clients must be genuinely different users',
        );
      });

      tearDownAll(() async {
        await alice.dispose();
        await bob.dispose();
      });

      // ── profiles ───────────────────────────────────────────────────────────

      test('profiles: a user reads only their own row', () async {
        final own = await alice.from('profiles').select().eq('id', aliceId);
        expect(own, hasLength(1), reason: 'the signup trigger must create it');

        final other = await alice.from('profiles').select().eq('id', bobId);
        expect(other, isEmpty, reason: "Alice must not see Bob's profile");
      });

      test('profiles: a user cannot update another user\'s row', () async {
        await alice
            .from('profiles')
            .update({'display_name': 'owned'})
            .eq('id', bobId);

        // No exception is expected — the update matches zero rows. The real
        // assertion is that Bob's row is untouched, read as Bob.
        final bobRow = await bob.from('profiles').select().eq('id', bobId);
        expect(bobRow.single['display_name'], isNot('owned'));
      });

      // ── entitlements (service-role write only) ─────────────────────────────

      test('entitlements: a user cannot write their own entitlement', () async {
        await expectLater(
          alice.from('entitlements').insert({'user_id': aliceId, 'tier': 'pro'}),
          _throwsRlsViolation,
          reason: 'a client that can write this can grant itself a subscription',
        );
      });

      test('entitlements: a user can read their own row', () async {
        // Empty is correct — nothing has provisioned one yet. What matters is
        // that the select is permitted rather than rejected.
        final rows = await alice
            .from('entitlements')
            .select()
            .eq('user_id', aliceId);
        expect(rows, isA<List<dynamic>>());
      });

      // ── usage_daily (service-role write only) ──────────────────────────────

      test('usage_daily: a user cannot write their own usage', () async {
        await expectLater(
          alice.from('usage_daily').insert({'user_id': aliceId, 'messages': 0}),
          _throwsRlsViolation,
          reason: 'a client that can write this can reset its own quota',
        );
      });

      // ── partners ───────────────────────────────────────────────────────────

      test('partners: private partners are invisible to other users', () async {
        // `select()` — no column list — used to work here and now returns
        // 42501. That is deliberate: Milestone 3 revoked SELECT on
        // `partners.system_prompt` from `authenticated`, because R9.3.2 makes
        // the prompt server-decided and §6.2 will eventually put user-authored
        // text in that column for other users to see.
        //
        // A column-level revoke cannot subtract from a table-level grant, so
        // the fix was to drop the table grant and grant columns back — which
        // makes an unqualified select fail loudly instead of silently
        // returning one column too many. Naming the columns is the cost, and a
        // loud failure is the point.
        const readable = 'id, owner_id, name, description, visibility';

        final created = await alice
            .from('partners')
            .insert({
              'owner_id': aliceId,
              'name': 'Alice private',
              'system_prompt': 'x',
            })
            .select(readable)
            .single();

        final seenByBob = await bob
            .from('partners')
            .select(readable)
            .eq('id', created['id']);
        expect(seenByBob, isEmpty);
      });

      test('partners: system_prompt is unreadable even for your own row', () async {
        // The owner has no more claim to read a prompt than anyone else. The
        // gateway builds the prompt under service role; nothing in the client
        // needs it, and a partner prompt in the client's hands is the first
        // half of working out how to talk around it.
        await alice.from('partners').insert({
          'owner_id': aliceId,
          'name': 'Alice prompt check',
          'system_prompt': 'x',
        });

        await expectLater(
          alice.from('partners').select('id, system_prompt').eq('owner_id', aliceId),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
          ),
        );
      });

      test('partners: a user cannot forge a built-in', () async {
        await expectLater(
          alice.from('partners').insert({
            'owner_id': aliceId,
            'name': 'fake builtin',
            'system_prompt': 'x',
            'is_builtin': true,
          }),
          throwsA(isA<PostgrestException>()),
          reason: 'a forged built-in impersonates a shipped partner',
        );
      });

      test('partners: a user cannot publish their own partner', () async {
        await expectLater(
          alice.from('partners').insert({
            'owner_id': aliceId,
            'name': 'self published',
            'system_prompt': 'x',
            'visibility': 'public',
          }),
          _throwsRlsViolation,
          reason: 'public is a reviewed state (§6), not a self-service one',
        );
      });

      // ── threads and messages ───────────────────────────────────────────────

      test('threads: a user cannot read or delete another user\'s thread', () async {
        final thread = await alice
            .from('threads')
            .insert({'user_id': aliceId, 'title': 'Alice thread'})
            .select()
            .single();

        expect(
          await bob.from('threads').select().eq('id', thread['id']),
          isEmpty,
        );

        await bob.from('threads').delete().eq('id', thread['id']);
        expect(
          await alice.from('threads').select().eq('id', thread['id']),
          hasLength(1),
          reason: 'the delete must match zero rows, not remove the thread',
        );
      });

      test('messages: ownership is enforced through the parent thread', () async {
        final thread = await alice
            .from('threads')
            .insert({'user_id': aliceId, 'title': 'Alice thread'})
            .select()
            .single();

        await alice.from('messages').insert({
          'thread_id': thread['id'],
          'role': 'user',
          'content': 'private',
        });

        expect(
          await bob.from('messages').select().eq('thread_id', thread['id']),
          isEmpty,
        );

        await expectLater(
          bob.from('messages').insert({
            'thread_id': thread['id'],
            'role': 'user',
            'content': 'injected',
          }),
          _throwsRlsViolation,
          reason: "Bob must not be able to write into Alice's thread",
        );
      });

      // ── sessions ───────────────────────────────────────────────────────────

      test('sessions: a user cannot read another user\'s session', () async {
        final session = await alice
            .from('sessions')
            .insert({'user_id': aliceId, 'goal': 'private goal'})
            .select()
            .single();

        expect(
          await bob.from('sessions').select().eq('id', session['id']),
          isEmpty,
        );
      });

      // ── memories ───────────────────────────────────────────────────────────

      test('memories: readable and deletable only by their owner', () async {
        final memory = await alice
            .from('memories')
            .insert({'user_id': aliceId, 'content': 'Alice prefers mornings'})
            .select()
            .single();

        expect(
          await bob.from('memories').select().eq('id', memory['id']),
          isEmpty,
        );

        await bob.from('memories').delete().eq('id', memory['id']);
        expect(
          await alice.from('memories').select().eq('id', memory['id']),
          hasLength(1),
        );

        // The owner must be able to forget — §5.2 treats this as a privacy
        // requirement, not a convenience.
        await alice.from('memories').delete().eq('id', memory['id']);
        expect(
          await alice.from('memories').select().eq('id', memory['id']),
          isEmpty,
        );
      });

      // ── referrals ──────────────────────────────────────────────────────────

      test('referrals: a user cannot write their own referral', () async {
        await expectLater(
          alice.from('referrals').insert({
            'inviter_id': aliceId,
            'invitee_id': bobId,
          }),
          _throwsRlsViolation,
          reason: 'the reward state machine pays out; clients cannot drive it',
        );
      });

      // ── abuse_events ───────────────────────────────────────────────────────

      test('abuse_events: no client read and no client write (D7)', () async {
        expect(await alice.from('abuse_events').select(), isEmpty);

        await expectLater(
          alice.from('abuse_events').insert({
            'user_id': aliceId,
            'kind': 'self_reported',
          }),
          _throwsRlsViolation,
          reason: 'the detected party must not be able to edit the detection',
        );
      });
    },
  );
}

/// A bare client with its own session, one per simulated user.
///
/// `AuthFlowType.implicit` is required here. The SDK defaults to PKCE, which
/// needs an async storage implementation to persist the code verifier — the
/// app gets one from `Supabase.initialize`, but a raw client in a test has no
/// such thing and asserts on sign-up. PKCE protects the redirect leg of an
/// OAuth flow; these tests only ever use email and password, so there is no
/// redirect to protect. This is a test-harness detail and says nothing about
/// which flow the app should use.
SupabaseClient _testClient() => SupabaseClient(
  _url,
  _key,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
);

/// Signs up a throwaway user and returns its id.
///
/// The email is unique per run so repeated runs do not collide. This requires
/// email confirmation to be OFF on the target project — with it on, `signUp`
/// returns a user but no session and every test below would fail on
/// authentication rather than on policy.
Future<String> _signUpFresh(SupabaseClient client, String label) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final res = await client.auth.signUp(
    email: 'rls-$label-$stamp@example.com',
    password: 'rls-test-${stamp}A!',
  );

  final user = res.user;
  if (user == null || res.session == null) {
    throw StateError(
      'Sign-up produced no session for $label. Email confirmation is likely '
      'still enabled on this project: Authentication → Sign In / Providers → '
      'Email → turn off "Confirm email". Do this on kalaam-dev only.',
    );
  }
  return user.id;
}

/// A PostgREST error carrying the RLS violation SQLSTATE.
///
/// Asserting on the code rather than on "some exception" matters: a not-null
/// or foreign-key failure also throws, and would let a table with no policy at
/// all pass a laxer test.
final _throwsRlsViolation = throwsA(
  isA<PostgrestException>().having(
    (e) => e.code,
    'code',
    _rlsViolation,
  ),
);
