import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:speakwise/core/config/app_config.dart';
import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/features/chat/domain/chat_usage.dart';
import 'package:speakwise/features/chat/domain/gateway_event.dart';

/// Raised inside the event stream when the gateway refuses or fails.
///
/// A `Stream<GatewayEvent>` cannot return a `Result`, so failures arrive as
/// stream errors and the notifier converts them back into an [AppFailure] at
/// the boundary. This keeps F4 intact — the UI still switches over the sealed
/// taxonomy and never sees an untyped exception.
class GatewayFailure implements Exception {
  const GatewayFailure(this.failure);
  final AppFailure failure;

  @override
  String toString() => 'GatewayFailure(${failure.code})';
}

/// The only path from this app to a model (PRD R9.3).
///
/// ## What is not in this file
///
/// A model key, a model name, a temperature, a system prompt, or a safety
/// setting. All six are server-decided (R9.3.2) and the gateway rejects a
/// request that mentions any of them, so there is nothing here to accidentally
/// expose. That is the whole point of the component: CRITIQUE W0.3 records that
/// moving keys into `--dart-define` "looks like a fix and is not", because an
/// APK is a zip and every string in it is public. The fix is that the key is
/// somewhere the APK cannot reach.
///
/// ## Why `http` and not the Supabase SDK
///
/// `functions.invoke` buffers the whole response before returning it, which
/// would turn a streamed reply into a single late blob and forfeit R9.3.5 and
/// the R4.2.4 latency budget with it. `http.Client.send` exposes the byte
/// stream, which is what streaming needs.
class GatewayClient {
  GatewayClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Sends one message and streams the reply.
  ///
  /// [accessToken] is the caller's Supabase JWT. The gateway derives the user
  /// id from it and ignores anything the body might claim, so this is the only
  /// identity that travels.
  Stream<GatewayEvent> send({
    required String accessToken,
    required String partnerId,
    required String text,
    String? threadId,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('${AppConfig.supabaseUrl}/functions/v1/gateway'),
    )
      ..headers.addAll({
        'apikey': AppConfig.supabasePublishableKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      // Exactly the three fields in the contract. Adding a fourth would be
      // rejected, which is deliberate on both ends.
      ..body = jsonEncode({
        'threadId': threadId,
        'partnerId': partnerId,
        'text': text,
      });

    http.StreamedResponse response;
    try {
      response = await _http.send(request);
    } on Object catch (error, stack) {
      // Any transport-level throw is offline as far as the user is concerned:
      // no DNS, no route, TLS refused, connection dropped before a status line.
      // R11.5 requires this to read as "not sent yet", never as lost work.
      Log.w('gateway: transport failed', error: error);
      throw GatewayFailure(OfflineFailure(cause: error, stackTrace: stack));
    }

    if (response.statusCode != 200) {
      throw GatewayFailure(await _failureFrom(response));
    }

    // SSE frames are separated by a blank line and a network chunk can split
    // one anywhere. Splitting on '\n\n' and keeping the remainder is what makes
    // a reply survive an unlucky packet boundary.
    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final frames = buffer.split('\n\n');
      buffer = frames.removeLast();

      for (final frame in frames) {
        final event = _parseFrame(frame);
        if (event != null) yield event;
      }
    }
  }

  /// Turns one SSE frame into an event, or null if it is not one we act on.
  ///
  /// Throws [GatewayFailure] for an `error` frame — a failure that arrives
  /// mid-stream (a safety block, an upstream drop) has to reach the caller the
  /// same way a failure before the stream does, or the UI would need two
  /// separate error paths for one concept.
  GatewayEvent? _parseFrame(String frame) {
    String? name;
    String? data;
    for (final line in frame.split('\n')) {
      if (line.startsWith('event: ')) name = line.substring(7).trim();
      if (line.startsWith('data: ')) data = line.substring(6);
    }
    if (name == null || data == null) return null;

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(data) as Map<String, dynamic>;
    } catch (error) {
      // A frame we cannot read is a server change, not a user problem. Skipping
      // it keeps a reply in progress alive; tearing the stream down would lose
      // text the user is already reading.
      Log.w('gateway: unreadable frame', error: error);
      return null;
    }

    switch (name) {
      case 'meta':
        return GatewayMeta(
          threadId: payload['threadId'] as String,
          isNewThread: payload['isNewThread'] as bool? ?? false,
          userMessageId: payload['userMessageId'] as String? ?? '',
          usage: ChatUsage.fromMeta(
            (payload['usage'] as Map?)?.cast<String, dynamic>() ?? const {},
          ),
        );
      case 'delta':
        return GatewayDelta(payload['text'] as String? ?? '');
      case 'done':
        return GatewayDone(
          messageId: payload['messageId'] as String?,
          truncated: payload['truncated'] as bool? ?? false,
        );
      case 'error':
        throw GatewayFailure(_failureForCode(payload['code'] as String?, payload));
      default:
        return null;
    }
  }

  Future<AppFailure> _failureFrom(http.StreamedResponse response) async {
    final body = await response.stream.bytesToString();
    Map<String, dynamic> error = const {};
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      error = (decoded['error'] as Map?)?.cast<String, dynamic>() ?? const {};
    } catch (_) {
      // A non-JSON body from a non-200 is an infrastructure error page, not
      // something the contract produced.
      Log.w('gateway: ${response.statusCode} with an unreadable body');
    }
    return _failureForCode(error['code'] as String?, error);
  }

  /// The single place the wire contract meets [AppFailure].
  ///
  /// Every branch maps to a distinct message in `l10n` — R11.5 requires the UI
  /// to distinguish offline, rate-limited, quota-exceeded, and safety-blocked,
  /// and that is only achievable if the codes survive the trip intact.
  AppFailure _failureForCode(String? code, Map<String, dynamic> detail) {
    switch (code) {
      case 'unauthorized':
        return const UnauthorizedFailure();
      case 'email_not_confirmed':
        return const AuthFailure(AuthFailureReason.emailNotConfirmed);
      case 'invalid_request':
        return InvalidRequestFailure(field: detail['field'] as String?);
      case 'rate_limited':
        final seconds = (detail['retryAfterSeconds'] as num?)?.toInt();
        return RateLimitedFailure(
          retryAfter: seconds == null ? null : Duration(seconds: seconds),
        );
      case 'quota_exceeded':
        return QuotaExceededFailure(
          resetsAt: switch (detail['resetsAt']) {
            final String s => DateTime.tryParse(s)?.toLocal(),
            _ => null,
          },
          // False when the ceiling is R10.1 fair use rather than the free tier.
          // Offering an upgrade that would not lift the limit is a dark pattern
          // (§16), so the server decides this and the client obeys.
          isUpgradeable: detail['upgradeable'] as bool? ?? true,
        );
      case 'at_capacity':
        return const AtCapacityFailure();
      case 'safety_blocked':
        return const SafetyBlockedFailure();
      case 'server_misconfigured':
      case 'upstream_failed':
        return const UnknownFailure();
      default:
        Log.w('gateway: unmapped error code "$code"');
        return const UnknownFailure();
    }
  }

  void dispose() => _http.close();
}
