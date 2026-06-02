import 'dart:math';
import '../chaos_monkey.dart' show ChaosEvent;
import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import 'base_experiment.dart';

/// Simulates network latency and connection drops.
///
/// This experiment works in two modes:
///
/// 1. **Interceptor mode** (primary): called inline by [ChaosDioInterceptor]
///    or [ChaosHttpInterceptor] on every request.  Use [applyTo] to apply
///    chaos to a single outgoing call.
///
/// 2. **Scheduler mode** (secondary): [execute] logs a synthetic "network
///    degradation event" for observability purposes when triggered by the
///    [ChaosScheduler].
///
/// ## Fault types
///
/// | Fault | Config param | Effect |
/// |-------|-------------|--------|
/// | Slow  | [ChaosConfig.slowNetwork] | Adds `networkDelayMs ± jitter` sleep |
/// | Drop  | [ChaosConfig.dropNetwork] | Throws [NetworkDropException] |
///
/// ## Usage (manual wrapping)
///
/// ```dart
/// final networkChaos = NetworkChaos(config: config);
///
/// // Wrap any async HTTP call:
/// final result = await networkChaos.applyTo(() => dio.get('/api/users'));
/// ```
class NetworkChaos extends BaseExperiment {
  /// Creates a [NetworkChaos] experiment.
  NetworkChaos({required super.config, super.seed});

  @override
  String get name => 'NetworkChaos';

  @override
  String get description =>
      'Injects artificial network latency and connection drops into '
      'HTTP requests.';

  // ── Core fault-injection ──────────────────────────────────────────────────

  /// Checks whether chaos should be applied to the current call and, if so,
  /// either delays it (slow) or aborts it (drop).
  ///
  /// [url] is attached to the event metadata for observability.
  ///
  /// Returns a [NetworkOutcome] describing what happened.
  Future<NetworkOutcome> applyToRequest(String url, String method) async {
    if (!config.enabled) return NetworkOutcome.passthrough;
    if (_isPaused) return NetworkOutcome.passthrough;

    // Drop takes precedence over slow.
    if (rollFor(config.dropNetwork)) {
      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'Dropped $method $url',
        metadata: {
          'url': url,
          'method': method,
          'errorCode': config.networkErrorCode,
          'fault': 'drop',
        },
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('🌐💀 DROP  $method $url  [${config.networkErrorCode}]');
      return NetworkOutcome.dropped(config.networkErrorCode);
    }

    if (rollFor(config.slowNetwork)) {
      final jitter = _jitter();
      final delay = (config.networkDelayMs + jitter).clamp(0, 120000);

      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'Slowed $method $url  +${delay}ms',
        durationMs: delay,
        metadata: {
          'url': url,
          'method': method,
          'delayMs': delay,
          'jitterMs': jitter,
          'fault': 'slow',
        },
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('🌐⏳ SLOW  $method $url  +${delay}ms');

      await Future<void>.delayed(Duration(milliseconds: delay));
      return NetworkOutcome.slowed(delay);
    }

    return NetworkOutcome.passthrough;
  }

  /// Convenience wrapper that applies chaos and then executes [call].
  ///
  /// ```dart
  /// final response = await networkChaos.applyTo(
  ///   () => httpClient.get(Uri.parse('https://api.example.com/users')),
  ///   url: 'https://api.example.com/users',
  ///   method: 'GET',
  /// );
  /// ```
  Future<T> applyTo<T>(
    Future<T> Function() call, {
    String url = 'unknown',
    String method = 'GET',
  }) async {
    final outcome =
        await applyToRequest(url, method);
    if (outcome.isDropped) {
      throw NetworkDropException(
        'chaos_monkey: connection dropped for $method $url '
        '[HTTP ${outcome.errorCode}]',
        statusCode: outcome.errorCode ?? config.networkErrorCode,
      );
    }
    return call();
  }

  // ── Scheduler-driven execution ────────────────────────────────────────────

  @override
  Future<void> execute({void Function(ChaosEvent event)? onEvent}) async {
    await super.execute(onEvent: onEvent);
    if (!rollFor(config.slowNetwork) && !rollFor(config.dropNetwork)) return;

    final isFast = rollFor(0.5);
    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: DateTime.now(),
      description: isFast
          ? 'Scheduler: synthetic network degradation event'
          : 'Scheduler: synthetic network drop event',
      metadata: {'source': 'scheduler'},
      tags: config.tags,
    );
    emitEvent(event, onEvent: onEvent);
    ChaosLogger.chaos('🌐📅 Scheduler network event fired');
  }

  @override
  bool shouldTrigger() =>
      config.enabled && (config.slowNetwork > 0 || config.dropNetwork > 0);

  @override
  Future<void> cleanup() async {
    _isPaused = false;
    ChaosLogger.info('NetworkChaos cleanup complete.');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isPaused = false;

  /// Temporarily disables this experiment (used by [ChaosMonkey.pause]).
  void pause() => _isPaused = true;

  /// Re-enables this experiment.
  void resume() => _isPaused = false;

  int _jitter() {
    final half = config.networkDelayJitterMs;
    if (half <= 0) return 0;
    return Random().nextInt(half * 2) - half;
  }
}

// ── Value objects ────────────────────────────────────────────────────────────

/// Describes the outcome of a chaos network check.
class NetworkOutcome {
  const NetworkOutcome._({
    required this.type,
    this.delayMs,
    this.errorCode,
  });

  /// No chaos was applied.
  static const NetworkOutcome passthrough =
      NetworkOutcome._(type: _Type.passthrough);

  /// A delay was applied.
  factory NetworkOutcome.slowed(int delayMs) =>
      NetworkOutcome._(type: _Type.slowed, delayMs: delayMs);

  /// The request was dropped.
  factory NetworkOutcome.dropped([int? errorCode]) =>
      NetworkOutcome._(type: _Type.dropped, errorCode: errorCode);

  final _Type type;

  /// Delay applied, in milliseconds (only set for [slowed]).
  final int? delayMs;

  /// HTTP error code (only set for [dropped]).
  final int? errorCode;

  bool get isPassthrough => type == _Type.passthrough;
  bool get isSlowed => type == _Type.slowed;
  bool get isDropped => type == _Type.dropped;
}

enum _Type { passthrough, slowed, dropped }

// ── Exceptions ───────────────────────────────────────────────────────────────

/// Thrown when [NetworkChaos.applyTo] drops the request entirely.
class NetworkDropException extends ChaosExperimentException {
  /// Creates the exception with an HTTP [statusCode].
  const NetworkDropException(super.message, {required this.statusCode});

  /// The simulated HTTP status code.
  final int statusCode;

  @override
  String toString() => 'NetworkDropException[$statusCode]: $message';
}
