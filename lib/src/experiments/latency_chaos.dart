import 'dart:math';
import '../chaos_monkey.dart' show ChaosEvent;
import '../utils/chaos_logger.dart';
import 'base_experiment.dart';

/// Injects random latency into **any** async call — not just HTTP.
///
/// Unlike [NetworkChaos] (which targets HTTP interceptors), [LatencyChaos]
/// works at the application layer and can wrap:
/// - Repository calls
/// - Service method calls
/// - Database queries
/// - Any async operation
///
/// This is useful for simulating slow storage, laggy BLE devices,
/// unresponsive external sensors, or any non-HTTP latency source.
///
/// ## Usage
///
/// ```dart
/// final latency = LatencyChaos(config: config);
///
/// final result = await latency.wrap(
///   () => userRepository.getProfile(id),
///   label: 'UserRepository.getProfile',
/// );
/// ```
///
/// ## Configuration
///
/// ```dart
/// ChaosConfig(
///   injectLatency: 0.15,    // 15% of calls get delayed
///   latencyMinMs: 500,      // minimum delay
///   latencyMaxMs: 4000,     // maximum delay
/// )
/// ```
class LatencyChaos extends BaseExperiment {
  /// Creates a [LatencyChaos] experiment.
  LatencyChaos({required super.config, super.seed});

  @override
  String get name => 'LatencyChaos';

  @override
  String get description =>
      'Injects random latency into arbitrary async calls to simulate '
      'slow storage, laggy services, and non-HTTP response delays.';

  // ── Core fault-injection ──────────────────────────────────────────────────

  /// Wraps [operation] with a random latency injection.
  ///
  /// The delay is drawn uniformly from
  /// `[latencyMinMs, latencyMaxMs]`.
  ///
  /// [label] is shown in event metadata (e.g. `'UserRepo.getAll'`).
  Future<T> wrap<T>(
    Future<T> Function() operation, {
    String label = 'unknown',
  }) async {
    if (!config.enabled) return operation();

    if (rollFor(config.injectLatency)) {
      final delay = _randomDelay();
      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'Latency injected +${delay}ms  [$label]',
        durationMs: delay,
        metadata: {
          'label': label,
          'delayMs': delay,
          'minMs': config.latencyMinMs,
          'maxMs': config.latencyMaxMs,
          'fault': 'latency',
        },
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('⏱️  LATENCY  [$label]  +${delay}ms');
      await Future<void>.delayed(Duration(milliseconds: delay));
    }

    return operation();
  }

  /// Checks whether a latency injection should fire and, if so, only
  /// applies the delay without executing a wrapped call.
  ///
  /// Returns the injected delay in milliseconds, or `null` if no delay
  /// was applied.
  Future<int?> maybeDelay({String label = 'unknown'}) async {
    if (!config.enabled) return null;
    if (!rollFor(config.injectLatency)) return null;

    final delay = _randomDelay();
    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: DateTime.now(),
      description: 'Standalone latency injected +${delay}ms  [$label]',
      durationMs: delay,
      metadata: {'label': label, 'delayMs': delay, 'fault': 'latency'},
      tags: config.tags,
    );
    emitEvent(event);
    ChaosLogger.chaos('⏱️  LATENCY (standalone)  [$label]  +${delay}ms');
    await Future<void>.delayed(Duration(milliseconds: delay));
    return delay;
  }

  // ── Scheduler-driven execution ────────────────────────────────────────────

  @override
  Future<void> execute({void Function(ChaosEvent event)? onEvent}) async {
    await super.execute(onEvent: onEvent);
    if (!rollFor(config.injectLatency)) return;

    final delay = _randomDelay();
    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: DateTime.now(),
      description: 'Scheduler: latency injection +${delay}ms',
      durationMs: delay,
      metadata: {'source': 'scheduler', 'delayMs': delay, 'fault': 'latency'},
      tags: config.tags,
    );
    emitEvent(event, onEvent: onEvent);
    ChaosLogger.chaos('⏱️📅 Scheduler LATENCY  +${delay}ms');
    await Future<void>.delayed(Duration(milliseconds: delay));
  }

  @override
  bool shouldTrigger() => config.enabled && config.injectLatency > 0;

  @override
  Future<void> cleanup() async {
    ChaosLogger.info('LatencyChaos cleanup complete.');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _randomDelay() {
    final range = config.latencyMaxMs - config.latencyMinMs;
    if (range <= 0) return config.latencyMinMs;
    return config.latencyMinMs + Random().nextInt(range);
  }
}
