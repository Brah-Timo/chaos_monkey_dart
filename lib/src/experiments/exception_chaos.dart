import 'dart:math';
import '../chaos_monkey.dart' show ChaosEvent;
import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import 'base_experiment.dart';

/// Randomly throws exceptions at wrapped call sites.
///
/// Use this to verify that your app's exception-handling layer (error
/// boundaries, try/catch blocks, global error handlers) is exhaustive and
/// never leaks raw exceptions to the user.
///
/// ## Usage
///
/// ```dart
/// final exChaos = ExceptionChaos(config: config);
///
/// // Wrap any call — may throw unexpectedly:
/// final result = await exChaos.wrap(
///   () => myRepository.fetchUser(id),
///   label: 'UserRepository.fetchUser',
/// );
/// ```
///
/// ## Custom exception pool
///
/// ```dart
/// ChaosConfig(
///   throwRandomException: 0.05,
///   customExceptions: [
///     NetworkException('simulated network failure'),
///     AuthException('simulated token expired'),
///     NotFoundException('simulated 404'),
///   ],
/// )
/// ```
class ExceptionChaos extends BaseExperiment {
  /// Creates an [ExceptionChaos] experiment.
  ExceptionChaos({required super.config, super.seed});

  /// Pool of built-in exceptions used when [ChaosConfig.customExceptions]
  /// is empty.
  static final List<Exception> _builtinPool = [
    const ChaosException('Simulated unexpected error'),
    const ChaosException('Simulated service unavailable'),
    const ChaosException('Simulated timeout'),
    const ChaosException('Simulated null reference'),
    const ChaosException('Simulated data parse failure'),
    const ChaosException('Simulated authentication error'),
    const ChaosException('Simulated rate limit exceeded'),
  ];

  @override
  String get name => 'ExceptionChaos';

  @override
  String get description =>
      'Randomly throws exceptions at wrapped call sites to validate '
      'error-handling completeness.';

  // ── Core fault-injection ──────────────────────────────────────────────────

  /// Wraps [operation] and may throw a random exception before executing it.
  ///
  /// [label] appears in event metadata for traceability.
  Future<T> wrap<T>(
    Future<T> Function() operation, {
    String label = 'unknown',
  }) async {
    if (!config.enabled) return operation();

    if (rollFor(config.throwRandomException)) {
      final exception = _pickException();
      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'Random exception thrown  [$label]  → $exception',
        metadata: {
          'label': label,
          'exceptionType': exception.runtimeType.toString(),
          'fault': 'exception',
        },
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('💥 EXCEPTION  [$label]  → ${exception.runtimeType}');
      throw exception;
    }

    return operation();
  }

  // ── Scheduler-driven execution ────────────────────────────────────────────

  @override
  Future<void> execute({void Function(ChaosEvent event)? onEvent}) async {
    await super.execute(onEvent: onEvent);
    if (!rollFor(config.throwRandomException)) return;

    final exception = _pickException();
    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: DateTime.now(),
      description: 'Scheduler: synthetic exception event → $exception',
      metadata: {
        'source': 'scheduler',
        'exceptionType': exception.runtimeType.toString(),
        'fault': 'exception',
      },
      tags: config.tags,
    );
    emitEvent(event, onEvent: onEvent);
    ChaosLogger.chaos('💥📅 Scheduler EXCEPTION event fired');
    // Note: the scheduler does NOT re-throw; it only records the event.
    // Actual throwing happens in wrap() at call sites.
  }

  @override
  bool shouldTrigger() =>
      config.enabled && config.throwRandomException > 0;

  @override
  Future<void> cleanup() async {
    ChaosLogger.info('ExceptionChaos cleanup complete.');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Exception _pickException() {
    final pool = config.customExceptions.isNotEmpty
        ? config.customExceptions
        : _builtinPool;
    return pool[Random().nextInt(pool.length)];
  }
}

// ── Exceptions ───────────────────────────────────────────────────────────────

/// Generic chaos exception thrown when no [customExceptions] are configured.
class ChaosException extends ChaosExperimentException {
  /// Creates the exception with [message].
  const ChaosException(super.message);
}
