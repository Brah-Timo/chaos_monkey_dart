import 'dart:async';
import '../chaos_monkey.dart' show ChaosEvent;
import '../utils/chaos_logger.dart';
import 'base_experiment.dart';

/// Simulates CPU spikes by running a tight computational loop.
///
/// The spike runs in the **same Dart isolate** as the app, which means it
/// will delay the event loop and surface any UI-blocking code that the app
/// has inadvertently placed on the main isolate.
///
/// For heavier simulation, consider spawning the loop in a separate
/// `Isolate` (future enhancement).
///
/// ## Configuration
///
/// ```dart
/// ChaosConfig(
///   cpuSpike: 0.10,             // 10% chance per scheduler tick
///   cpuSpikeDurationMs: 2000,   // spike lasts 2 seconds
///   cpuSpikeIterations: 5000000 // tight-loop iterations per spike
/// )
/// ```
class CpuChaos extends BaseExperiment {
  /// Creates a [CpuChaos] experiment.
  CpuChaos({required super.config, super.seed});

  @override
  String get name => 'CpuChaos';

  @override
  String get description =>
      'Simulates CPU spikes by executing a tight computational loop to '
      'stress-test event-loop latency and UI responsiveness.';

  // ── Core fault-injection ──────────────────────────────────────────────────

  /// Manually triggers a CPU spike.
  ///
  /// Returns `true` if the spike was triggered based on the configured
  /// probability.
  Future<bool> spike() async {
    if (!config.enabled) return false;
    if (!rollFor(config.cpuSpike)) return false;

    return _executeSpikeInternal();
  }

  // ── Scheduler-driven execution ────────────────────────────────────────────

  @override
  Future<void> execute({void Function(ChaosEvent event)? onEvent}) async {
    await super.execute(onEvent: onEvent);
    if (!rollFor(config.cpuSpike)) return;
    await _executeSpikeInternal(onEvent: onEvent);
  }

  Future<bool> _executeSpikeInternal({
    void Function(ChaosEvent)? onEvent,
  }) async {
    final duration = config.cpuSpikeDurationMs;
    final iterations = config.cpuSpikeIterations;

    ChaosLogger.chaos(
      '💻🔥 CPU SPIKE  ${iterations} iterations  ×  ~${duration}ms',
    );

    final start = DateTime.now();
    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: start,
      description: 'CPU spike: $iterations iterations / ~${duration}ms',
      durationMs: duration,
      metadata: {
        'iterations': iterations,
        'durationMs': duration,
        'fault': 'cpu_spike',
      },
      tags: config.tags,
    );
    emitEvent(event, onEvent: onEvent);

    // Run tight loop — deliberately blocks event loop.
    var sum = 0;
    final deadline = start.add(Duration(milliseconds: duration));
    while (DateTime.now().isBefore(deadline)) {
      for (var i = 0; i < iterations; i++) {
        sum ^= i; // prevent dead-code elimination
      }
      // Yield occasionally to allow timers to fire.
      await Future<void>.delayed(Duration.zero);
    }
    // Use sum to prevent compiler optimisation.
    ChaosLogger.trace('CpuChaos: sum=$sum (prevents DCE)');

    ChaosLogger.chaos('💻✅ CPU SPIKE done  elapsed: '
        '${DateTime.now().difference(start).inMilliseconds}ms');
    return true;
  }

  @override
  bool shouldTrigger() => config.enabled && config.cpuSpike > 0;

  @override
  Future<void> cleanup() async {
    ChaosLogger.info('CpuChaos cleanup complete.');
  }
}
