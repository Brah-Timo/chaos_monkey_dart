import 'dart:math';

import '../chaos_monkey.dart' show ChaosEvent;
import '../config/chaos_config.dart';
import '../utils/probability.dart';

/// Abstract base class for all chaos experiments.
///
/// Every concrete experiment must implement:
/// - [name]: short identifier shown in reports and logs.
/// - [description]: human-readable explanation of what this experiment does.
/// - [shouldTrigger]: returns `true` if at least one probability in [config]
///   is > 0 for this experiment type.
/// - [execute]: performs the actual chaos side-effect and fires
///   [onEventTriggered].
/// - [cleanup]: releases any resources acquired during the experiment.
///
/// Subclasses can call [rollFor] as a convenience wrapper around
/// [Probability.roll] that uses the shared [_random] instance.
abstract class BaseExperiment {
  /// Creates the experiment with the given [config].
  BaseExperiment({required this.config, int? seed})
      : _random = seed != null ? Random(seed) : Random();

  /// The configuration that governs this experiment's behaviour.
  final ChaosConfig config;

  /// Shared random-number generator.
  final Random _random;

  /// Callback invoked each time a chaos event is triggered.
  ///
  /// Set by the [ChaosScheduler] and [ChaosMonkey] controller so events flow
  /// into the reporter pipeline automatically.
  void Function(ChaosEvent event)? onEventTriggered;

  // ── Abstract contract ──────────────────────────────────────────────────────

  /// Short, stable identifier (e.g. `'NetworkChaos'`).
  String get name;

  /// Human-readable explanation shown in reports.
  String get description;

  /// Returns `true` if this experiment should be active given [config].
  ///
  /// Used by the [ChaosMonkey] controller to decide which experiments to
  /// register.  **Does not** roll a random number; it only checks whether at
  /// least one relevant probability is > 0.
  bool shouldTrigger();

  /// Executes one iteration of the chaos experiment.
  ///
  /// The default implementation does nothing.  Override in subclasses that
  /// have scheduler-driven behaviour (e.g. [MemoryChaos], [CpuChaos]).
  ///
  /// Interceptor-driven experiments (e.g. [NetworkChaos]) typically do NOT
  /// override this because they are triggered inline by the interceptor.
  Future<void> execute({void Function(ChaosEvent event)? onEvent}) async {
    onEventTriggered ??= onEvent;
  }

  /// Releases any resources held by this experiment.
  ///
  /// Called by [ChaosMonkey.stop].  Implementations should be idempotent.
  Future<void> cleanup();

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Convenience wrapper: rolls [p] against the internal [Random] instance.
  bool rollFor(double p) => Probability.roll(p, _random);

  /// Fires [onEventTriggered] (and [onEvent] if provided) with [event].
  void emitEvent(ChaosEvent event, {void Function(ChaosEvent)? onEvent}) {
    onEventTriggered?.call(event);
    onEvent?.call(event);
  }

  @override
  String toString() => 'Experiment($name)';
}

/// Base class for exceptions thrown by experiments.
///
/// All experiment-specific exceptions extend this so callers can catch them
/// with a single `on ChaosExperimentException` handler.
abstract class ChaosExperimentException implements Exception {
  /// Creates the exception with a descriptive [message].
  const ChaosExperimentException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}
