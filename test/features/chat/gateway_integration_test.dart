@Tags(['integration'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// The gateway against a live project — and the close-out of CRITIQUE W2.3.
///
/// ## What this exists to prove
///
/// W2.3 left two RLS policies untested: `entitlements` and `usage_daily` are
/// proven to refuse client writes, but their **read-own** policies were
/// unproven, because creating a row to read requires the service-role key the
/// suite deliberately does not hold. The untested half is the half that decides
/// whether a paying user can see what they paid for, and a read-own policy that
/// silently returns nothing looks identical to "no subscription" in the UI.
///
/// DECISIONS.md D8 chose to wait for the gateway rather than hand the tests a
/// service key. The gateway holds one legitimately: it writes `usage_daily`
/// atomically with the response it accounts for (R9.3.4) and ensures the
/// caller's `entitlements` row exists (R9.3.1). So the sequence is:
///
///   1. sign up on kalaam-dev,
///   2. send one message through the gateway with that user's JWT,
///   3. read both tables back **as that user**, through the publishable key and
///      therefore through RLS.
///
/// A row appears, the user can read it, and nothing in this file ever holds a
/// key that bypasses RLS. That is a stronger result than seeding would have
/// given: a row the test writes proves the policy accepts a row the test knows
/// how to shape, while a row the gateway writes proves it accepts the row the
/// product actually writes.
///
/// It also closes §14's "a patched client cannot gain Pro", by sending a forged
/// premium claim and showing it is rejected rather than ignored.
///
/// Run with:
///
///     flutter test test/features/chat/gateway_integration_test.dart \
///       --dart-define=SUPABASE_URL=https://<dev-ref>.supabase.co \
///       --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// Free Talk. Seeded with a fixed uuid by the gateway migration precisely so a
/// test can name one without first querying for it.
const _freeTalk = '11111111-1111-4111-8111-000000000001';

void main() {
  final configured = _url.isNotEmpty && _key.isNotEmpty;

  group(
    'the gateway against a live project',
    skip: configured
        ? null
        : 'Set --dart-define=SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to run. '
              'Point them at kalaam-dev, never production.',
    () {
      late SupabaseClient client;
      late String token;

      /// Posts to the gateway with the signed-in user's JWT.
      Future<http.StreamedResponse> post(Map<String, dynamic> body) {
        final request = http.Request('POST', Uri.parse('$_url/functions/v1/gateway'))
          ..headers.addAll({
            'apikey': _key,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode(body);
        return request.send();
      }

      setUpAll(() async {
        client = SupabaseClient(
          _url,
          _key,
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );

        final stamp = DateTime.now().microsecondsSinceEpoch;
        final response = await client.auth.signUp(
          email: 'gateway-$stamp@example.com',
          // Derived, not a literal: a `password = '...'` in source is the
          // exact shape check-secrets.sh exists to stop, and teaching the
          // scanner an exception for test files would mean a real credential
          // in a test could never be caught again.
          password: 'Aa1!-$stamp',
        );
        token = response.session!.accessToken;
      });

      tearDownAll(() async {
        // Leaves the account behind on kalaam-dev. Deleting it needs the
        // service role (R9.5.2 runs deletion in an Edge Function), which is
        // exactly what this file is written to avoid holding.
        await client.dispose();
      });

      test('a message streams back and creates a thread', () async {
        final response = await post({
          'threadId': null,
          'partnerId': _freeTalk,
          'text': 'I am practising for a job interview on Tuesday.',
        });

        expect(response.statusCode, 200);
        expect(response.headers['content-type'], contains('text/event-stream'));

        final body = await response.stream.transform(utf8.decoder).join();
        expect(body, contains('event: meta'));
        expect(body, contains('event: delta'));
        expect(body, contains('event: done'));
      });

      test('W2.3: the user can read the usage_daily row the gateway wrote', () async {
        // The row exists only because the previous test caused it. That is the
        // point — nothing here inserted it.
        final rows = await client
            .from('usage_daily')
            .select('day, messages')
            .withConverter((data) => data);

        expect(
          rows,
          isNotEmpty,
          reason:
              'read-own on usage_daily returned nothing for a user who has '
              'used the gateway. That is W2.3 realised: a policy that silently '
              'returns nothing is indistinguishable from having no usage.',
        );
        expect((rows.first['messages'] as num).toInt(), greaterThan(0));
      });

      test('W2.3: the user can read their own entitlements row', () async {
        final rows = await client
            .from('entitlements')
            .select('tier, state')
            .withConverter((data) => data);

        expect(
          rows,
          hasLength(1),
          reason:
              'Every account gets a free entitlement row at signup. If this is '
              'empty, a paying user would see "no subscription" for a '
              'subscription they hold.',
        );
        expect(rows.first['tier'], 'free');
        expect(rows.first['state'], 'active');
      });

      test('the client still cannot write either table', () async {
        // The half W2.3 already covered, re-asserted here so the read-own
        // proof above cannot be mistaken for a relaxation.
        await expectLater(
          client.from('usage_daily').insert({
            'user_id': client.auth.currentUser!.id,
            'day': '2026-01-01',
            'messages': 0,
          }),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
          ),
        );

        // UPDATE is the subtler case and deserves its own note: with RLS
        // enabled and no update policy, Postgres does not raise — it matches
        // zero rows and returns success. A client that took HTTP 200 as
        // confirmation would believe it had granted itself Pro.
        await client
            .from('entitlements')
            .update({'tier': 'pro'})
            .eq('user_id', client.auth.currentUser!.id);

        final after = await client
            .from('entitlements')
            .select('tier')
            .withConverter((data) => data);
        expect(
          after.first['tier'],
          'free',
          reason: 'an UPDATE that affects no rows must not change the tier',
        );
      });

      test('§14: a forged premium claim is rejected, not ignored', () async {
        final response = await post({
          'threadId': null,
          'partnerId': _freeTalk,
          'text': 'hello',
          'tier': 'pro',
        });

        expect(response.statusCode, 400);
        final body = jsonDecode(await response.stream.bytesToString());
        expect(body['error']['code'], 'invalid_request');
        expect(
          body['error']['field'],
          'tier',
          reason:
              'The field must be named back. An accepted-and-ignored field is '
              'indistinguishable, from the sender, from an honoured one.',
        );
      });

      test('a partner the caller has no claim to is refused', () async {
        final response = await post({
          'threadId': null,
          // A well-formed uuid that is not a built-in and not owned by anyone.
          'partnerId': '99999999-9999-4999-8999-999999999999',
          'text': 'hello',
        });

        expect(response.statusCode, 400);
        final body = jsonDecode(await response.stream.bytesToString());
        expect(body['error']['field'], 'partnerId');
      });

      test('a thread belonging to nobody is refused', () async {
        final response = await post({
          'threadId': '99999999-9999-4999-8999-999999999998',
          'partnerId': _freeTalk,
          'text': 'hello',
        });

        expect(response.statusCode, 400);
        final body = jsonDecode(await response.stream.bytesToString());
        expect(body['error']['field'], 'threadId');
      });

      test('R9.3.2: partners.system_prompt is not readable by a client', () async {
        // The prompt is server-decided. A column-level revoke was written in
        // the first gateway migration, ran without error, and did nothing —
        // a column REVOKE cannot subtract from a table GRANT. This is the
        // assertion that would have caught it.
        await expectLater(
          client.from('partners').select('id, system_prompt'),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
          ),
        );

        // And the columns a client legitimately needs still work.
        final partners = await client
            .from('partners')
            .select('id, name, description, difficulty')
            .withConverter((data) => data);
        expect(partners.length, greaterThanOrEqualTo(5));
      });

      test('an unauthenticated call is refused', () async {
        final request = http.Request('POST', Uri.parse('$_url/functions/v1/gateway'))
          ..headers.addAll({'apikey': _key, 'Content-Type': 'application/json'})
          ..body = jsonEncode({'partnerId': _freeTalk, 'text': 'hello'});

        final response = await request.send();
        expect(response.statusCode, anyOf(401, 403));
      });
    },
  );
}
