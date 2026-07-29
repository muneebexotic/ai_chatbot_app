import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:speakwise/core/config/app_config.dart';
import 'package:speakwise/core/logging/log.dart';
import 'package:speakwise/core/result/app_failure.dart';
import 'package:speakwise/core/result/result.dart';
import 'package:speakwise/core/speech_metrics/speech_metrics.dart';
import 'package:speakwise/features/session/domain/session_state.dart';

/// Talks to the `session` Edge Function (PRD §8, F2).
///
/// ## What is not in this file
///
/// Any calculation of how much allowance is left. F2: "Entitlements and quotas
/// MUST be computed and enforced server-side; the client only *displays*
/// them." Every number this class returns came from the server in the response
/// it is parsing, and there is no field on the way out that says how long
/// anything took — the meter reads the database clock.
class SessionClient {
  SessionClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri get _endpoint => Uri.parse('${AppConfig.supabaseUrl}/functions/v1/session');

  Future<Result<T>> _post<T>(
    String accessToken,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
  ) async {
    http.Response response;
    try {
      response = await _http.post(
        _endpoint,
        headers: {
          'apikey': AppConfig.supabasePublishableKey,
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } on Object catch (error, stack) {
      // R11.5 requires this to read as "not sent yet", never as lost work. A
      // session whose open call fails still runs — it records locally and
      // syncs later (R4.2.6, R11.5).
      Log.w('session: transport failed', error: error);
      return Err(OfflineFailure(cause: error, stackTrace: stack));
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      Log.w('session: ${response.statusCode} with an unreadable body');
      return const Err(UnknownFailure());
    }

    if (response.statusCode != 200) {
      return Err(_failureFor(decoded['error'] as Map<String, dynamic>?));
    }

    return Ok(parse(decoded));
  }

  /// Opens a session and returns the server's id and the remaining allowance.
  Future<Result<SessionOpened>> open({
    required String accessToken,
    required String partnerId,
    String? threadId,
    String? goal,
  }) => _post(accessToken, {
    'action': 'open',
    'partnerId': partnerId,
    'threadId': threadId,
    'goal': goal,
  }, (json) => SessionOpened(
    sessionId: json['sessionId'] as String,
    usage: SessionUsage.fromJson(
      (json['usage'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  ));

  /// Keeps the meter running between model turns.
  ///
  /// `allowed: false` is NOT an instruction to hang up. R8.3: "never cut them
  /// off mid-sentence, finish the exchange, then show it." The controller reads
  /// this and ends after the current turn.
  Future<Result<SessionHeartbeat>> heartbeat({
    required String accessToken,
    required String sessionId,
  }) => _post(accessToken, {
    'action': 'heartbeat',
    'sessionId': sessionId,
  }, (json) => SessionHeartbeat(
    allowed: json['allowed'] as bool? ?? true,
    usage: SessionUsage.fromJson(
      (json['usage'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  ));

  /// Closes the session and stores the locally computed report data.
  ///
  /// [duration] and [metrics] are what the report shows. Neither affects quota:
  /// the server charges what its own clock measured, and a client that lied
  /// here would get a wrong report card rather than free minutes.
  Future<Result<SessionUsage>> close({
    required String accessToken,
    required String sessionId,
    required Duration duration,
    SpeechMetrics? metrics,
  }) => _post(accessToken, {
    'action': 'close',
    'sessionId': sessionId,
    'durationSeconds': duration.inSeconds,
    'metrics': metrics?.toJson(),
  }, (json) => SessionUsage.fromJson(
    (json['usage'] as Map?)?.cast<String, dynamic>() ?? const {},
  ));

  /// The same mapping the gateway client uses, deliberately.
  ///
  /// R11.5 requires the UI to distinguish offline, rate-limited,
  /// quota-exceeded and safety-blocked. Two endpoints with two vocabularies for
  /// one concept is how a UI ends up with a generic snackbar for the cases it
  /// cannot line up.
  AppFailure _failureFor(Map<String, dynamic>? error) {
    switch (error?['code']) {
      case 'unauthorized':
        return const UnauthorizedFailure();
      case 'email_not_confirmed':
        return const AuthFailure(AuthFailureReason.emailNotConfirmed);
      case 'invalid_request':
        return InvalidRequestFailure(field: error?['field'] as String?);
      case 'quota_exceeded':
        return QuotaExceededFailure(
          resetsAt: switch (error?['resetsAt']) {
            final String s => DateTime.tryParse(s)?.toLocal(),
            _ => null,
          },
          isUpgradeable: error?['upgradeable'] as bool? ?? true,
        );
      case 'at_capacity':
        return const AtCapacityFailure();
      default:
        Log.w('session: unmapped error code "${error?['code']}"');
        return const UnknownFailure();
    }
  }

  void dispose() => _http.close();
}

class SessionOpened {
  const SessionOpened({required this.sessionId, required this.usage});
  final String sessionId;
  final SessionUsage usage;
}

class SessionHeartbeat {
  const SessionHeartbeat({required this.allowed, required this.usage});

  /// False once the day's allowance is gone. See [SessionClient.heartbeat].
  final bool allowed;
  final SessionUsage usage;
}
