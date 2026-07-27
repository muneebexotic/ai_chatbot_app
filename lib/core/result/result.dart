import 'app_failure.dart';

/// The return type of anything that can fail.
///
/// PRD F4. A `Result<T>` is either [Ok] or [Err]; there is no third state and
/// no `null` sentinel. Because it is sealed, a `switch` over it is exhaustive
/// and the compiler refuses to let a caller read a value without having
/// considered the failure.
///
/// Deliberately hand-written rather than pulled from `dartz`, `fpdart`, or
/// `result_dart`: it is roughly eighty lines, the PRD's dependency list is
/// meant to contain only what it requires (§14), and a functional-programming
/// package invites a style the rest of this codebase does not use.
sealed class Result<T> {
  const Result();

  /// Wraps a synchronous computation, converting a throw into an [Err].
  ///
  /// [onError] maps the caught object onto the taxonomy in [AppFailure];
  /// without it everything collapses to [UnknownFailure], which defeats the
  /// purpose of having the taxonomy.
  factory Result.guard(
    T Function() body, {
    AppFailure Function(Object error, StackTrace stackTrace)? onError,
  }) {
    try {
      return Ok<T>(body());
    } catch (error, stackTrace) {
      return Err<T>(
        onError?.call(error, stackTrace) ??
            UnknownFailure(cause: error, stackTrace: stackTrace),
      );
    }
  }

  /// Async twin of [Result.guard].
  static Future<Result<T>> guardAsync<T>(
    Future<T> Function() body, {
    AppFailure Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      return Ok<T>(await body());
    } catch (error, stackTrace) {
      return Err<T>(
        onError?.call(error, stackTrace) ??
            UnknownFailure(cause: error, stackTrace: stackTrace),
      );
    }
  }

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The value, or `null` when this is an [Err].
  ///
  /// An escape hatch for call sites that genuinely do not care why something
  /// failed. Reach for `switch` first — if you find yourself using this
  /// everywhere, the taxonomy is not being used and F4 has quietly been
  /// reintroduced.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure, or `null` when this is an [Ok].
  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Collapses both branches into one value. The safe way to render a
  /// `Result` in a widget, because it cannot forget the error case.
  R fold<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };

  /// Transforms the success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// [map] for operations that themselves return a `Result`, so chains do not
  /// nest into `Result<Result<T>>`.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) =>
      switch (this) {
        Ok<T>(:final value) => transform(value),
        Err<T>(:final failure) => Err<R>(failure),
      };

  /// The value, or [fallback] when this is an [Err].
  T getOrElse(T fallback) => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => fallback,
  };
}

/// A successful result carrying [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ok<T> &&
          runtimeType == other.runtimeType &&
          value == other.value);

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Ok($value)';
}

/// A failed result carrying [failure].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Err<T> &&
          runtimeType == other.runtimeType &&
          failure == other.failure);

  @override
  int get hashCode => Object.hash(runtimeType, failure);

  @override
  String toString() => 'Err(${failure.code})';
}
