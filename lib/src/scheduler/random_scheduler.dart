import 'dart:async';
import 'dart:math';
import '../chaos_monkey.dart' show ChaosEvent;
import '../experiments/base_experiment.dart';
import '../utils/chaos_logger.dart';

/// A scheduler that fires experiments at random intervals rather than on a
/// fixed cadence.
///
/// This produces more realistic chaos patterns because real-world failures
/// don't follow a predictable schedule.
///
/// The inter-tick delay is drawn uniformly from
/// `[minIntervalSeconds, maxIntervalSeconds]`.
///
/// ## Usage
///
/// ```dart
/// // In a custom ChaosMonkey subclass or test harness:
/// final scheduler = RandomScheduler(
///   experiments: myExperiments,
///   minIntervalSeconds: 15,
///   maxIntervalSeconds: 90,
///   onEvent: handleEvent,
///   isPausedCallback: () => monkey.isPaused,
/// );
/// await scheduler.start();
/// ```
class RandomScheduler {
  /// Creates a [RandomScheduler].
  RandomScheduler({
    required this.experiments,
    required this.onEvent,
    required this.isPausedCallback,
    this.minIntervalSeconds = 10,
    this.maxIntervalSeconds = 120,
    this.maxConcurrent = 1,
    int? seed,
  })  : assert(
          minIntervalSeconds < maxIntervalSeconds,
          'minIntervalSeconds must be less than maxIntervalSeconds',
        ),
        _random = seed != null ? Random(seed) : Random();

  /// The pool of experiments to schedule.
  final List<BaseExperiment> experiments;

  /// Callback invoked when an experiment fires an event.
  final void Function(ChaosEvent event) onEvent;

  /// Returns `true` when the monkey is paused.
  final bool Function() isPausedCallback;

  /// Shortest possible inter-tick delay in seconds.
  final int minIntervalSeconds;

  /// Longest possible inter-tick delay in seconds.
  final int maxIntervalSeconds;

  /// Maximum concurrently-running experiments.
  final int maxConcurrent;

  final Random _random;
  Timer? _timer;
  int _runningCount = 0;
  int _tickCount = 0;
  bool _started = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Starts the randomised scheduler.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    ChaosLogger.info(
      'RandomScheduler starting — '
      'interval: ${minIntervalSeconds}–${maxIntervalSeconds}s, '
      'experiments: ${experiments.length}',
    );

    _scheduleNext();
  }

  /// Stops the scheduler.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    ChaosLogger.info('RandomScheduler stopped after $_tickCount ticks.');
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _scheduleNext() {
    if (!_started) return;

    final range = maxIntervalSeconds - minIntervalSeconds;
    final delay = minIntervalSeconds + _random.nextInt(range + 1);

    _timer = Timer(Duration(seconds: delay), () async {
      await _tick();
      _scheduleNext(); // chain next random delay
    });
  }

  Future<void> _tick() async {
    _tickCount++;

    if (isPausedCallback()) return;
    if (experiments.isEmpty) return;
    if (_runningCount >= maxConcurrent) return;

    final experiment = experiments[_random.nextInt(experiments.length)];
    ChaosLogger.trace('RandomScheduler: tick $_tickCount → ${experiment.name}');

    _runningCount++;
    try {
      await experiment.execute(onEvent: onEvent);
    } catch (e, st) {
      ChaosLogger.error(
        'RandomScheduler: error in ${experiment.name}',
        error: e,
        stackTrace: st,
      );
    } finally {
      _runningCount--;
    }
  }

  // ── Diagnostics ───────────────────────────────────────────────────────────

  /// Number of ticks fired so far.
  int get tickCount => _tickCount;

  @override
  String toString() =>
      'RandomScheduler('
      '${minIntervalSeconds}–${maxIntervalSeconds}s, '
      'ticks=$_tickCount)';
}
