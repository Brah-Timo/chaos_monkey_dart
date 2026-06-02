import 'dart:math';
import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import '../utils/probability.dart';

/// Middleware that injects chaos into calls made with the `http` package.
///
/// Because the `http` package uses a pure [BaseClient] interface, this
/// interceptor is implemented as a wrapper client — see [ChaosHttpClient].
///
/// Use this class directly if you need the decision logic separated from the
/// actual HTTP transport (e.g. for testing):
///
/// ```dart
/// final interceptor = ChaosHttpInterceptor(
///   config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.05),
/// );
///
/// final decision = await interceptor.process(
///   url: 'https://api.example.com/users',
///   method: 'GET',
/// );
///
/// if (decision.isDropped) {
///   throw NetworkDropException(decision.message!, statusCode: 503);
/// }
/// // else: delay already applied, continue with real request
/// ```
class ChaosHttpInterceptor {
  /// Creates the interceptor with the given [config].
  const ChaosHttpInterceptor({required this.config});

  /// The configuration governing this interceptor.
  final ChaosConfig config;

  /// Evaluates chaos rules and applies any necessary delays/drops.
  ///
  /// Returns a [HttpChaosDecision] indicating what happened.
  Future<HttpChaosDecision> process({
    required String url,
    required String method,
  }) async {
    if (!config.enabled) return HttpChaosDecision.passthrough;

    final random = Random();

    // 1. Drop — highest priority.
    if (Probability.roll(config.dropNetwork, random)) {
      ChaosLogger.chaos(
        '🌐💀 [http] DROP  $method $url  [HTTP ${config.networkErrorCode}]',
      );
      return HttpChaosDecision.drop(
        message:
            'chaos_monkey: http connection dropped for $method $url '
            '[HTTP ${config.networkErrorCode}]',
        statusCode: config.networkErrorCode,
      );
    }

    // 2. Slow — applies delay then lets the request proceed.
    if (Probability.roll(config.slowNetwork, random)) {
      final jitter =
          Random().nextInt(config.networkDelayJitterMs * 2 + 1) -
              config.networkDelayJitterMs;
      final delay =
          (config.networkDelayMs + jitter).clamp(0, 120000);

      ChaosLogger.chaos(
        '🌐⏳ [http] SLOW  $method $url  +${delay}ms',
      );
      await Future<void>.delayed(Duration(milliseconds: delay));
      return HttpChaosDecision.slow(delayMs: delay);
    }

    return HttpChaosDecision.passthrough;
  }
}

// ── Value objects ────────────────────────────────────────────────────────────

/// Outcome of [ChaosHttpInterceptor.process].
class HttpChaosDecision {
  const HttpChaosDecision._({
    required this.type,
    this.delayMs,
    this.statusCode,
    this.message,
  });

  /// No chaos applied.
  static const HttpChaosDecision passthrough =
      HttpChaosDecision._(type: _DecisionType.passthrough);

  /// Request delayed, then allowed to proceed.
  factory HttpChaosDecision.slow({required int delayMs}) =>
      HttpChaosDecision._(type: _DecisionType.slowed, delayMs: delayMs);

  /// Request dropped.
  factory HttpChaosDecision.drop({
    required String message,
    required int statusCode,
  }) =>
      HttpChaosDecision._(
        type: _DecisionType.dropped,
        statusCode: statusCode,
        message: message,
      );

  final _DecisionType type;

  /// Delay applied (only for [slowed]).
  final int? delayMs;

  /// HTTP status code (only for [dropped]).
  final int? statusCode;

  /// Error message (only for [dropped]).
  final String? message;

  bool get isPassthrough => type == _DecisionType.passthrough;
  bool get isSlowed => type == _DecisionType.slowed;
  bool get isDropped => type == _DecisionType.dropped;

  @override
  String toString() => 'HttpChaosDecision(${type.name}'
      '${delayMs != null ? ", delay=${delayMs}ms" : ""}'
      '${statusCode != null ? ", status=$statusCode" : ""})';
}

enum _DecisionType { passthrough, slowed, dropped }
