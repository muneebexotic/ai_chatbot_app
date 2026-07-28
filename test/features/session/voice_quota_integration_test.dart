@Tags(['integration'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// Server-side voice metering against a live project — PRD F2, §8, R10.1.
///
/// ## The claim being tested
///
/// F2: "Entitlements and quotas MUST be computed and enforced server-side; the
/// client only *displays* them." For typed messages, Milestone 3's gateway made
/// that true. For spoken minutes it was not true at all — `usage_daily
/// .voice_seconds` has existed since the initial schema and nothing had ever
/// written to it, so §8's "10 minutes per day" was an unenforced sentence in a
/// table.
///
/// The tests below prove three things that cannot be checked by reading code:
///
///   1. Seconds are charged from the **database clock**, not from anything the
///      client says. There is no field to say it with, and adding one is a
///      rejected request.
///   2. A spoken turn does **not** spend a typed message. §8 gives a free user
///      both budgets, and charging one to the other would end a ten-minute
///      session at message 30.
///   3. A session id belonging to somebody else, or already closed, buys
///      nothing.
///
/// Nothing here holds a service-role key — same discipline as DECISIONS D8. The
/// rows are created by the product's own code paths and read back through RLS
/// as the user who owns them.
///
/// Run with:
///
///     flutter test test/features/session/voice_quota_integration_test.dart \
///       --dart-define=SUPABASE_URL=https://<dev-ref>.supabase.co \
///       --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

const _freeTalk = '11111111-1111-4111-8111-000000000001';

void main() {
  final configured = _url.isNotEmpty && _key.isNotEmpty;

  group(
    'voice quota is server truth (F2)',
    skip: configured
        ? null
        : 'Set --dart-define=SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to run. '
              'Point them at kalaam-dev, never production.',
    () {
      late SupabaseClient client;
      late String token;

      Future<http.Response> session(Map<String, dynamic> body) => http.post(
        Uri.parse('$_url/functions/v1/session'),
        headers: {
          'apikey': _key,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      Future<http.StreamedResponse> gateway(Map<String, dynamic> body) {
        final request = http.Request(
          'POST',
          Uri.parse('$_url/functions/v1/gateway'),
        )
          ..headers.addAll({
            'apikey': _key,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode(body);
        return request.send();
      }

      Future<int> voiceSeconds() async {
        final rows = await client
            .from('usage_daily')
            .select('voice_seconds')
            .withConverter((data) => data);
        if (rows.isEmpty) return 0;
        return (rows.first['voice_seconds'] as num).toInt();
      }

      Future<int> messages() async {
        final rows = await client
            .from('usage_daily')
            .select('messages')
            .withConverter((data) => data);
        if (rows.isEmpty) return 0;
        return (rows.first['messages'] as num).toInt();
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
          email: 'voice-$stamp@example.com',
          password: 'Aa1x$stamp',
        );
        token = response.session!.accessToken;
      });

      tearDownAll(() async => client.dispose());

      test('opening a session reports the free allowance from §8', () async {
        final response = await session({
          'action': 'open',
          'partnerId': _freeTalk,
          'goal': 'I have a frontend interview on Tuesday',
        });

        expect(response.statusCode, 200);
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        expect(body['sessionId'], isNotNull);
        final usage = body['usage'] as Map<String, dynamic>;
        expect(usage['tier'], 'free');
        // §8: 10 minutes per day of model-backed Sessions on the free tier.
        expect(usage['dailyLimitSeconds'], 600);
        expect(usage['remainingSeconds'], 600);
      });

      test('a heartbeat charges wall-clock seconds the client never sent', () async {
        final opened = jsonDecode(
          (await session({'action': 'open', 'partnerId': _freeTalk})).body,
        );
        final id = opened['sessionId'] as String;

        // A baseline, not zero. The previous test left a session open, and
        // opening this one swept it and charged its final slice — which is
        // R4.2.6's crash path working, so asserting a clean slate here would be
        // asserting that it does not.
        final before = await voiceSeconds();

        // The only thing that makes seconds pass is time passing.
        await Future<void>.delayed(const Duration(seconds: 3));

        final beat = await session({'action': 'heartbeat', 'sessionId': id});
        expect(beat.statusCode, 200);

        final charged = await voiceSeconds() - before;
        expect(
          charged,
          greaterThanOrEqualTo(3),
          reason:
              'The meter must charge the elapsed wall clock. Nothing in the '
              'request body said how long anything took.',
        );
        expect(
          charged,
          lessThan(30),
          reason: 'and it must not invent time that did not pass',
        );

        await session({'action': 'close', 'sessionId': id});
      });

      test('a spoken turn does not spend a typed message (§8)', () async {
        final before = await messages();

        final opened = jsonDecode(
          (await session({'action': 'open', 'partnerId': _freeTalk})).body,
        );
        final id = opened['sessionId'] as String;

        final reply = await gateway({
          'threadId': null,
          'partnerId': _freeTalk,
          'text': 'Tell me about yourself.',
          'sessionId': id,
        });
        expect(reply.statusCode, 200);
        await reply.stream.drain<void>();

        expect(
          await messages(),
          before,
          reason:
              'A spoken turn charged the typed-message counter. §8 gives a free '
              'user 30 typed messages AND 10 spoken minutes; a ten-minute '
              'session is ~20 exchanges, so this would end the session with '
              '"you are out of messages" and spend an allowance the user was '
              'never using.',
        );
        expect(
          await voiceSeconds(),
          greaterThan(0),
          reason: 'and the gateway turn must meter the session itself',
        );

        await session({'action': 'close', 'sessionId': id});
      });

      test('a typed turn still spends a typed message', () async {
        // The other half of the branch. Without this, "voice does not charge
        // messages" could be satisfied by charging nothing at all.
        final before = await messages();

        final reply = await gateway({
          'threadId': null,
          'partnerId': _freeTalk,
          'text': 'Just typing this one.',
        });
        expect(reply.statusCode, 200);
        await reply.stream.drain<void>();

        expect(await messages(), before + 1);
      });

      test('a session id that is not yours buys nothing', () async {
        // A well-formed uuid nobody owns. The gateway must treat the turn as
        // typed-or-refused rather than as an unmetered spoken one.
        final response = await session({
          'action': 'heartbeat',
          'sessionId': '99999999-9999-4999-8999-999999999997',
        });
        expect(response.statusCode, 400);
        expect(jsonDecode(response.body)['error']['field'], 'sessionId');

        final reply = await gateway({
          'threadId': null,
          'partnerId': _freeTalk,
          'text': 'hello',
          'sessionId': '99999999-9999-4999-8999-999999999997',
        });
        expect(reply.statusCode, 400);
        final body = jsonDecode(await reply.stream.bytesToString());
        expect(body['error']['field'], 'sessionId');
      });

      test('a closed session cannot be metered again', () async {
        final opened = jsonDecode(
          (await session({'action': 'open', 'partnerId': _freeTalk})).body,
        );
        final id = opened['sessionId'] as String;

        final closed = await session({'action': 'close', 'sessionId': id});
        expect(closed.statusCode, 200);
        expect(jsonDecode(closed.body)['closed'], isTrue);

        final again = await session({'action': 'heartbeat', 'sessionId': id});
        expect(
          again.statusCode,
          400,
          reason:
              'A closed session that still meters is a session that keeps '
              'charging after the user has left the screen.',
        );
      });

      test('opening a second session sweeps the first (R4.2.6)', () async {
        // A force-killed session never reaches a close, so this is the ordinary
        // path after a crash, not an exceptional one. The old row must stop
        // metering and must not block the new one.
        final first = jsonDecode(
          (await session({'action': 'open', 'partnerId': _freeTalk})).body,
        )['sessionId'] as String;

        final second = await session({'action': 'open', 'partnerId': _freeTalk});
        expect(
          second.statusCode,
          200,
          reason: 'a crash must not lock the user out of starting again',
        );
        final secondId = jsonDecode(second.body)['sessionId'] as String;
        expect(secondId, isNot(first));

        final stale = await session({'action': 'heartbeat', 'sessionId': first});
        expect(stale.statusCode, 400, reason: 'the swept session is no longer open');

        await session({'action': 'close', 'sessionId': secondId});
      });

      test('the transcript and the metrics survive the close', () async {
        final opened = jsonDecode(
          (await session({
            'action': 'open',
            'partnerId': _freeTalk,
            'goal': 'practise speaking slowly',
          })).body,
        );
        final id = opened['sessionId'] as String;

        await session({
          'action': 'close',
          'sessionId': id,
          'durationSeconds': 128,
          'metrics': {'words_spoken': 240, 'filler_count': 6},
        });

        final rows = await client
            .from('sessions')
            .select('id, goal, duration_seconds, metrics, state, metered_seconds')
            .eq('id', id)
            .withConverter((data) => data);

        expect(rows, hasLength(1));
        final row = rows.first;
        expect(row['goal'], 'practise speaking slowly');
        expect(row['duration_seconds'], 128);
        expect((row['metrics'] as Map)['words_spoken'], 240);
        expect(row['state'], 'ended');
        expect(
          (row['metered_seconds'] as num).toInt(),
          lessThan(128),
          reason:
              'metered_seconds is what the SERVER charged. The client said 128; '
              'the session lasted about a second. If these ever agree by '
              'construction, the meter is reading the client.',
        );
      });

      test('the client cannot write voice_seconds itself', () async {
        // R9.5.1: usage_daily is service-role write only. Re-asserted for the
        // column this milestone started using, because a policy that covers
        // `messages` and not `voice_seconds` would look identical until
        // somebody tried.
        final before = await voiceSeconds();
        expect(before, greaterThan(0), reason: 'the earlier tests charged time');

        // Two outcomes are both acceptable and only one of them raises. With
        // RLS enabled and no update policy, Postgres does not error — it
        // matches zero rows and returns success. A client that read HTTP 200 as
        // confirmation would believe it had reset its own quota. So the
        // assertion is on the VALUE, not on the exception.
        try {
          await client
              .from('usage_daily')
              .update({'voice_seconds': 0})
              .eq('user_id', client.auth.currentUser!.id);
        } on PostgrestException {
          // Refused outright. Also fine.
        }

        expect(
          await voiceSeconds(),
          before,
          reason:
              'A client write reached usage_daily.voice_seconds. R9.5.1 makes '
              'that table service-role write only, and a policy covering '
              '`messages` but not `voice_seconds` would look identical from '
              'the outside until somebody tried it.',
        );
      });
    },
  );
}
