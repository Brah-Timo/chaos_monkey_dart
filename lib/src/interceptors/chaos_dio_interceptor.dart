// ignore_for_file: depend_on_referenced_packages
// Consumers must add `dio: ^5.4.0` to their own pubspec.yaml.
// This file uses conditional import-guards so the package still
// compiles in projects that do not depend on Dio.

// NetworkChaos re-export — must come before all declarations.
export '../experiments/network_chaos.dart'
    show NetworkDropException, NetworkOutcome;

import 'dart:math';
import 'package:meta/meta.dart';
import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import '../utils/probability.dart';

/// A [Dio] interceptor that transparently injects network chaos into every
/// outgoing HTTP request.
///
/// ## Setup
///
/// Add this interceptor once when creating your [Dio] instance — typically
/// in your DI setup or `main()`:
///
/// ```dart
/// import 'package:dio/dio.dart';
/// import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';
///
/// final dio = Dio();
///
/// if (!kReleaseMode) {
///   dio.interceptors.add(
///     ChaosDioInterceptor(
///       config: ChaosConfig(
///         slowNetwork:    0.20,   // 20% of requests delayed
///         networkDelayMs: 10000,  // 10-second delay
///         dropNetwork:    0.05,   // 5% of requests dropped
///       ),
///     ),
///   );
/// }
/// ```
///
/// ## Fault behaviour
///
/// | Priority | Config param | What happens |
/// |----------|-------------|--------------|
/// | 1st | [ChaosConfig.dropNetwork] | Request is **rejected** with a
///         [DioException] of type `connectionError`. |
/// | 2nd | [ChaosConfig.slowNetwork] | Request is **delayed** by
///         `networkDelayMs \u00b1 jitter` before proceeding. |
///
/// ## Response tampering (optional)
///
/// Override [onResponse] in a subclass to add response-level tampering
/// (e.g. returning 500 status or corrupted JSON).
@immutable
class ChaosDioInterceptor {
  /// Creates the interceptor with the given [config].
  const ChaosDioInterceptor({required this.config});

  /// The chaos configuration governing this interceptor.
  final ChaosConfig config;

  // The class cannot extend Interceptor directly here because we cannot
  // import Dio without making it a mandatory dependency.
  // Instead, consumers integrate this as a mixin/wrapper or use the
  // DioInterceptorAdapter provided below.

  /// Applies chaos to the request represented by [url] and [method].
  ///
  /// Returns a [DioRequestDecision] that tells the caller whether to:
  /// - [DioRequestDecision.proceed] — continue normally (possibly after delay)
  /// - [DioRequestDecision.reject]  — abort the request with a network error
  Future<DioRequestDecision> processRequest(
    String url,
    String method,
  ) async {
    if (!config.enabled) return DioRequestDecision.proceed;

    final random = Random();

    // 1. Drop check — highest priority.
    if (Probability.roll(config.dropNetwork, random)) {
      ChaosLogger.chaos(
        '🌐💀 [Dio] DROP  $method  $url  [HTTP ${config.networkErrorCode}]',
      );
      return DioRequestDecision.reject(
        DioErrorInfo(
          url: url,
          method: method,
          errorCode: config.networkErrorCode,
          message:
              'chaos_monkey: Dio connection dropped for $method $url',
          chaosType: 'drop',
        ),
      );
    }

    // 2. Slow check.
    if (Probability.roll(config.slowNetwork, random)) {
      final jitter =
          Random().nextInt(config.networkDelayJitterMs * 2 + 1) -
              config.networkDelayJitterMs;
      final delay =
          (config.networkDelayMs + jitter).clamp(0, 120000);

      ChaosLogger.chaos(
        '🌐⏳ [Dio] SLOW  $method  $url  +${delay}ms',
      );
      await Future<void>.delayed(Duration(milliseconds: delay));
      return DioRequestDecision.proceed;
    }

    return DioRequestDecision.proceed;
  }
}

// ── Value objects ────────────────────────────────────────────────────────────

/// Decision returned by [ChaosDioInterceptor.processRequest].
class DioRequestDecision {
  const DioRequestDecision._({required this.shouldProceed, this.error});

  /// Continue the request normally.
  static const DioRequestDecision proceed =
      DioRequestDecision._(shouldProceed: true);

  /// Abort the request with [error].
  factory DioRequestDecision.reject(DioErrorInfo error) =>
      DioRequestDecision._(shouldProceed: false, error: error);

  /// `true` if the request should continue.
  final bool shouldProceed;

  /// Error details when [shouldProceed] is `false`.
  final DioErrorInfo? error;
}

/// Structured error info for a dropped Dio request.
class DioErrorInfo {
  /// Creates the error info.
  const DioErrorInfo({
    required this.url,
    required this.method,
    required this.errorCode,
    required this.message,
    required this.chaosType,
  });

  final String url;
  final String method;
  final int errorCode;
  final String message;
  final String chaosType;

  @override
  String toString() =>
      'DioErrorInfo($chaosType  $method $url  [$errorCode])';
}

// ── Concrete Dio interceptor (requires dio package) ──────────────────────────

/// A ready-to-use Dio [Interceptor] that wraps [ChaosDioInterceptor].
///
/// Add to your [Dio] instance:
/// ```dart
/// dio.interceptors.add(
///   DioChaosBridge(config: ChaosConfig(slowNetwork: 0.2)),
/// );
/// ```
///
/// This class is defined here (not in chaos_monkey_dart.dart) to keep the
/// `dio` import isolated.  Consumers add `dio` to their own pubspec.
///
/// NOTE: Because chaos_monkey_dart does not declare `dio` in its own
/// `pubspec.yaml`, static analysis in the package's own tests skips this
/// file.  It is validated by the example app which DOES list `dio`.
class DioChaosBridge {
  /// Creates the bridge with the given [config].
  const DioChaosBridge({required this.config});

  /// The configuration governing this interceptor.
  final ChaosConfig config;

  /// Entry point called by the Dio pipeline on every outgoing request.
  ///
  /// In your own code, extend the real `Interceptor` class and call this:
  ///
  /// ```dart
  /// @override
  /// Future<void> onRequest(
  ///   RequestOptions options,
  ///   RequestInterceptorHandler handler,
  /// ) async {
  ///   final decision = await bridge.handleRequest(
  ///     options.uri.toString(),
  ///     options.method,
  ///   );
  ///   if (!decision.shouldProceed) {
  ///     handler.reject(
  ///       DioException(
  ///         requestOptions: options,
  ///         type: DioExceptionType.connectionError,
  ///         message: decision.error?.message,
  ///       ),
  ///     );
  ///     return;
  ///   }
  ///   handler.next(options);
  /// }
  /// ```
  Future<DioRequestDecision> handleRequest(String url, String method) {
    return ChaosDioInterceptor(config: config).processRequest(url, method);
  }

  // Provided as a complete standalone file in example/lib/example_with_dio.dart
  // which imports dio and extends Interceptor concretely.
}

// NetworkDropException and NetworkOutcome are re-exported at the top of this
// file (before declarations), where Dart directives are required to appear.
