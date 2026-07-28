import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_chatbot_app/core/result/app_failure.dart';
import 'package:ai_chatbot_app/features/chat/data/gateway_client.dart';
import 'package:ai_chatbot_app/features/chat/domain/gateway_event.dart';

/// The client half of the wire contract (PRD §9.3, F4, R11.5).
///
/// Two things are proved here, and the second is the one that has actually
/// broken in this codebase before.
///
/// **Framing.** SSE frames are separated by a blank line, and a network chunk
/// can split one anywhere — including between `event:` and `data:`, or in the
/// middle of a UTF-8 sequence. A parser that assumes one chunk is one frame
/// works perfectly on a fast connection and drops words on a slow one, which
/// is exactly the environment §16 says the app must not require.
///
/// **Error identity.** R11.5 requires the UI to distinguish offline from
/// rate-limited from quota-exceeded from safety-blocked and say something
/// specific for each. That is only true if the server's code survives the trip
/// as a distinct [AppFailure]; a mapper that quietly collapses to `unknown`
/// satisfies the type system and defeats the requirement.
void main() {
  /// Feeds [chunks] back as a streamed 200, one chunk per event-loop turn, so
  /// the client sees the same partial reads a real socket would deliver.
  GatewayClient clientStreaming(List<String> chunks) {
    return GatewayClient(
      httpClient: MockClient.streaming((request, bodyStream) async {
        final controller = StreamController<List<int>>();
        scheduleMicrotask(() async {
          for (final chunk in chunks) {
            controller.add(utf8.encode(chunk));
            await Future<void>.delayed(Duration.zero);
          }
          await controller.close();
        });
        return http.StreamedResponse(controller.stream, 200);
      }),
    );
  }

  GatewayClient clientFailing(int status, Object body) {
    return GatewayClient(
      httpClient: MockClient((request) async {
        return http.Response(jsonEncode(body), status);
      }),
    );
  }

  Stream<GatewayEvent> run(GatewayClient client) => client.send(
    accessToken: 'token',
    partnerId: '11111111-1111-4111-8111-000000000002',
    text: 'hello',
  );

  const meta =
      'event: meta\n'
      'data: {"threadId":"t1","isNewThread":true,"userMessageId":"u1",'
      '"usage":{"used":1,"dailyLimit":30,"tier":"free","resetsAt":null}}\n\n';

  group('framing', () {
    test('a well-formed stream produces meta, deltas, and done', () async {
      final events = await run(
        clientStreaming([
          meta,
          'event: delta\ndata: {"text":"Hello"}\n\n',
          'event: delta\ndata: {"text":" there"}\n\n',
          'event: done\ndata: {"messageId":"a1","truncated":false}\n\n',
        ]),
      ).toList();

      expect(events.length, 4);
      expect(events[0], isA<GatewayMeta>());
      expect((events[0] as GatewayMeta).threadId, 't1');
      expect((events[0] as GatewayMeta).usage.dailyLimit, 30);
      expect((events[1] as GatewayDelta).text, 'Hello');
      expect((events[2] as GatewayDelta).text, ' there');
      expect((events[3] as GatewayDone).messageId, 'a1');
    });

    test('a frame split across chunks still arrives whole', () async {
      // The failure this prevents: the reply loses "there" on a slow link and
      // reads fine on a fast one, so it never reproduces on the desk it was
      // written at.
      final events = await run(
        clientStreaming([
          meta,
          'event: delta\ndata: {"te',
          'xt":" there"}\n',
          '\nevent: done\ndata: {"messageId":"a1","truncated":false}\n\n',
        ]),
      ).toList();

      expect(events.whereType<GatewayDelta>().map((d) => d.text).toList(), [
        ' there',
      ]);
      expect(events.last, isA<GatewayDone>());
    });

    test('several frames in one chunk all arrive', () async {
      // One TCP read can carry several frames. Nagle and the provider's own
      // buffering make this the common case, not the edge case.
      const burst =
          'event: delta\ndata: {"text":"a"}\n\n'
          'event: delta\ndata: {"text":"b"}\n\n'
          'event: delta\ndata: {"text":"c"}\n\n';
      final events = await run(clientStreaming(['$meta$burst'])).toList();

      expect(events.whereType<GatewayDelta>().map((d) => d.text).join(), 'abc');
    });

    test('an unreadable frame is skipped, not fatal', () async {
      // A frame we cannot parse is a server change. Tearing the stream down
      // would lose text the user is already reading.
      final events = await run(
        clientStreaming([
          meta,
          'event: delta\ndata: {this is not json}\n\n',
          'event: delta\ndata: {"text":"kept"}\n\n',
        ]),
      ).toList();

      expect(events.whereType<GatewayDelta>().map((d) => d.text).toList(), [
        'kept',
      ]);
    });

    test('unknown event names are ignored', () async {
      final events = await run(
        clientStreaming([meta, 'event: heartbeat\ndata: {}\n\n']),
      ).toList();
      expect(events.length, 1);
    });

    test('truncation is carried through', () async {
      final events = await run(
        clientStreaming([
          meta,
          'event: done\ndata: {"messageId":"a1","truncated":true}\n\n',
        ]),
      ).toList();
      expect((events.last as GatewayDone).truncated, isTrue);
    });
  });

  group('error identity (R11.5)', () {
    Future<AppFailure> failureFrom(Stream<GatewayEvent> stream) async {
      try {
        await stream.toList();
      } on GatewayFailure catch (e) {
        return e.failure;
      }
      fail('expected a GatewayFailure');
    }

    test('429 quota_exceeded keeps its reset time and upgradeability', () async {
      final failure = await failureFrom(
        run(
          clientFailing(429, {
            'error': {
              'code': 'quota_exceeded',
              'resetsAt': '2026-07-29T00:00:00Z',
              'upgradeable': true,
            },
          }),
        ),
      );

      expect(failure, isA<QuotaExceededFailure>());
      final quota = failure as QuotaExceededFailure;
      expect(quota.isUpgradeable, isTrue);
      expect(quota.resetsAt, isNotNull);
    });

    test('a fair-use ceiling is quota-exceeded but NOT upgradeable', () async {
      // §16: offering an upgrade that would not lift the limit is a dark
      // pattern. The server decides, and the flag has to survive the trip or
      // the client will offer it anyway.
      final failure = await failureFrom(
        run(
          clientFailing(429, {
            'error': {'code': 'quota_exceeded', 'upgradeable': false},
          }),
        ),
      );
      expect((failure as QuotaExceededFailure).isUpgradeable, isFalse);
    });

    test('rate_limited carries the retry delay', () async {
      final failure = await failureFrom(
        run(
          clientFailing(429, {
            'error': {'code': 'rate_limited', 'retryAfterSeconds': 90},
          }),
        ),
      );
      expect(failure, isA<RateLimitedFailure>());
      expect((failure as RateLimitedFailure).retryAfter, const Duration(seconds: 90));
    });

    test('503 at_capacity is distinct from quota', () async {
      // R10.4. Telling a user "you are out of messages" when the truth is "we
      // are out" is a false statement about their account.
      final failure = await failureFrom(
        run(clientFailing(503, {'error': {'code': 'at_capacity'}})),
      );
      expect(failure, isA<AtCapacityFailure>());
    });

    test('401 is unauthorized', () async {
      final failure = await failureFrom(
        run(clientFailing(401, {'error': {'code': 'unauthorized'}})),
      );
      expect(failure, isA<UnauthorizedFailure>());
    });

    test('403 email_not_confirmed maps to the auth reason, not unauthorized', () async {
      final failure = await failureFrom(
        run(clientFailing(403, {'error': {'code': 'email_not_confirmed'}})),
      );
      expect(failure, isA<AuthFailure>());
      expect(
        (failure as AuthFailure).reason,
        AuthFailureReason.emailNotConfirmed,
      );
    });

    test('400 invalid_request keeps the offending field', () async {
      final failure = await failureFrom(
        run(
          clientFailing(400, {
            'error': {'code': 'invalid_request', 'field': 'partnerId'},
          }),
        ),
      );
      expect((failure as InvalidRequestFailure).field, 'partnerId');
    });

    test('a mid-stream safety block is a SafetyBlockedFailure', () async {
      // R10.5. It arrives as a frame rather than a status code, and has to
      // reach the caller the same way — otherwise the UI needs two error paths
      // for one concept and one of them gets forgotten.
      final failure = await failureFrom(
        run(
          clientStreaming([
            meta,
            'event: delta\ndata: {"text":"I "}\n\n',
            'event: error\ndata: {"code":"safety_blocked"}\n\n',
          ]),
        ),
      );
      expect(failure, isA<SafetyBlockedFailure>());
    });

    test('a transport throw is offline, not unknown', () async {
      // R11.5 requires this to read as "not sent yet", never as lost work.
      final client = GatewayClient(
        httpClient: MockClient((_) async => throw const SocketishError()),
      );
      final failure = await failureFrom(run(client));
      expect(failure, isA<OfflineFailure>());
    });

    test('a non-JSON error body still produces a typed failure', () async {
      // A 502 from infrastructure returns an HTML error page, not our contract.
      final client = GatewayClient(
        httpClient: MockClient((_) async => http.Response('<html>502</html>', 502)),
      );
      final failure = await failureFrom(run(client));
      expect(failure, isA<UnknownFailure>());
    });
  });
}

/// Stands in for whatever the socket layer throws. The client must not care
/// which exception type it was — only that nothing reached the server.
class SocketishError implements Exception {
  const SocketishError();
}
