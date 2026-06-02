import 'dart:async';
import '../chaos_monkey.dart' show ChaosEvent;
import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import 'base_experiment.dart';

/// Simulates memory-pressure events by allocating large byte arrays.
///
/// The allocated memory is held for a brief period (one scheduler tick) to
/// force the Dart VM's garbage collector to work harder and surface any
/// memory-related race conditions or UI freezes in the host app.
///
/// ⚠️  [ChaosConfig.memoryAllocationMb] is capped at 512 MB to avoid
///     crashing the device under test.
class MemoryChaos extends BaseExperiment {
  /// Creates a [MemoryChaos] experiment.
  MemoryChaos({required super.config, super.seed});

  @override
  String get name => 'MemoryChaos';

  @override
  String get description =>
      'Allocates large byte arrays to simulate memory pressure and '
      'stress-test the app under low-memory conditions.';

  // Held reference — keeps the allocation alive until cleanup() is called.
  // The reference is intentionally read in [heldAllocationSize] so the
  // analyser recognises it as used.
  List<List<int>>? _heldAllocation;

  // ── Core fault-injection ──────────────────────────────────────────────────

  /// Allocates [ChaosConfig.memoryAllocationMb] MB and holds the reference
  /// for [holdDurationMs] milliseconds before releasing.
  ///
  /// Returns `true` if the event was triggered, `false` otherwise.
  Future<bool> pressurize({int holdDurationMs = 2000}) async {
    if (!config.enabled) return false;
    if (!rollFor(config.memoryPressure)) return false;

    final mb = config.memoryAllocationMb;
    ChaosLogger.chaos('🧠💥 MEMORY PRESSURE  allocating ${mb}MB...');

    final allocation = <List<int>>[];
    try {
      // Allocate in 1-MB chunks to give Dart's allocator a chance to breathe.
      for (var i = 0; i < mb; i++) {
        allocation.add(List<int>.filled(1024 * 1024, i & 0xFF));
      }
      _heldAllocation = allocation;

      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description:
            'Memory pressure: allocated ${mb}MB for ${holdDurationMs}ms',
        durationMs: holdDurationMs,
        metadata: {
          'allocatedMb': mb,
          'holdDurationMs': holdDurationMs,
          'fault': 'pressure',
        },
        tags: config.tags,
      );
      emitEvent(event);

      // Hold the allocation, then release.
      await Future<void>.delayed(Duration(milliseconds: holdDurationMs));
    } finally {
      _heldAllocation = null;
    }
    return true;
  }

  // ── Scheduler-driven execution ────────────────────────────────────────────

  @override
  Future<void> execute({void Function(ChaosEvent event)? onEvent}) async {
    await super.execute(onEvent: onEvent);
    if (!rollFor(config.memoryPressure)) return;

    final mb = config.memoryAllocationMb;
    ChaosLogger.chaos('🧠📅 Scheduler MEMORY PRESSURE  ${mb}MB');

    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: DateTime.now(),
      description: 'Scheduler: memory pressure ${mb}MB',
      metadata: {
        'allocatedMb': mb,
        'source': 'scheduler',
        'fault': 'pressure',
      },
      tags: config.tags,
    );
    emitEvent(event, onEvent: onEvent);

    // Actually allocate to make the pressure real.
    final allocation = <List<int>>[];
    try {
      for (var i = 0; i < mb; i++) {
        allocation.add(List<int>.filled(1024 * 1024, 0));
      }
      _heldAllocation = allocation;
      await Future<void>.delayed(const Duration(seconds: 2));
    } finally {
      _heldAllocation = null;
    }
  }

  /// Current number of held 1-MB chunks, or `0` if no allocation is live.
  ///
  /// Useful for diagnostics and tests that need to assert memory is being held.
  int get heldAllocationSize => _heldAllocation?.length ?? 0;

  @override
  bool shouldTrigger() => config.enabled && config.memoryPressure > 0;

  @override
  Future<void> cleanup() async {
    _heldAllocation = null;
    ChaosLogger.info('MemoryChaos cleanup complete — allocation released.');
  }
}
