import 'dart:async';
import 'dart:math';
import '../chaos_monkey.dart' show ChaosEvent;
import '../experiments/base_experiment.dart';
import '../utils/chaos_logger.dart';

/// Periodically selects and fires chaos experiments autonomously.
///
/// The scheduler is responsible for the **time-based** dimension of chaos.
/// Interceptor-based experiments (like [NetworkChaos]) fire inline on every
/// request.  The scheduler fires experiments on a fixed [intervalSeconds]
/// cadence, independently of traffic patterns.
///
/// ## Experiment selection
///
/// On each tick the scheduler picks one experiment at random (uniform
/// distribution across the active pool).  The experiment itself decides
/// whether to actually fire based on its own probability check inside
/// [BaseExperiment.execute].
///
/// ## Concurrency guard
///
/// If a previous tick's experiment is still running when the next tick fires,
/// the new tick is skipped (unless [maxConcurrent] > 1).
class ChaosScheduler {
  /// Creates a [ChaosScheduler].
  ChaosScheduler({
    required this.experiments,
    required this.intervalSeconds,
    required this.onEvent,
    required this.isPausedCallback,
    this.maxConcurrent = 1,
    int? seed,
  }) : _random = seed != null ? Random(seed) : Random();

  /// The pool of experiments to schedule.
  final List<BaseExperiment> experiments;

  /// Interval between scheduler ticks, in seconds.
  final int intervalSeconds;

  /// Callback invoked when an experiment triggers an event.
  final void Function(ChaosEvent event) onEvent;

  /// Returns `true` when the monkey is paused (ticks are skipped).
  final bool Function() isPausedCallback;

  /// Maximum number of experiments that may run simultaneously.
  final int maxConcurrent;

  final Random _random;
  Timer? _timer;
  int _runningCount = 0;
  int _tickCount = 0;
  bool _started = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Starts the periodic timer.
  ///
  /// Fires an initial tick after a short warm-up delay (5 seconds) so the app
  /// has time to finish initialising before the first fault is injected.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    ChaosLogger.info(
      'ChaosScheduler starting — interval: ${intervalSeconds}s, '
      'experiments: ${experiments.length}, '
      'maxConcurrent: $maxConcurrent',
    );

    // Warm-up delay before the very first tick.
    Future<void>.delayed(const Duration(seconds: 5), _tick);

    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) => _tick());
  }

  /// Stops the scheduler and cancels the timer.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    ChaosLogger.info('ChaosScheduler stopped after $_tickCount ticks.');
  }

  // ── Tick ──────────────────────────────────────────────────────────────────

  Future<void> _tick() async {
    _tickCount++;

    if (isPausedCallback()) {
      ChaosLogger.trace('ChaosScheduler: tick $_tickCount skipped (paused)');
      return;
    }

    if (experiments.isEmpty) {
      ChaosLogger.trace('ChaosScheduler: no experiments registered');
      return;
    }

    if (_runningCount >= maxConcurrent) {
      ChaosLogger.trace(
        'ChaosScheduler: tick $_tickCount skipped '
        '($_runningCount/$maxConcurrent running)',
      );
      return;
    }

    final experiment = _selectExperiment();
    if (experiment == null) return;

    ChaosLogger.trace(
      'ChaosScheduler: tick $_tickCount → ${experiment.name}',
    );

    _runningCount++;
    try {
      await experiment.execute(onEvent: onEvent);
    } catch (e, st) {
      ChaosLogger.error(
        'ChaosScheduler: unhandled error in ${experiment.name}',
        error: e,
        stackTrace: st,
      );
    } finally {
      _runningCount--;
    }
  }

  BaseExperiment? _selectExperiment() {
    if (experiments.isEmpty) return null;
    return experiments[_random.nextInt(experiments.length)];
  }

  // ── Diagnostics ───────────────────────────────────────────────────────────

  /// Number of ticks fired so far.
  int get tickCount => _tickCount;

  /// Number of experiments currently executing.
  int get runningCount => _runningCount;

  @override
  String toString() =>
      'ChaosScheduler(interval=${intervalSeconds}s, '
      'ticks=$_tickCount, running=$_runningCount)';
}
