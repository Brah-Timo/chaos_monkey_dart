import 'dart:async';
import '../chaos_monkey.dart' show ChaosEvent;
import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import 'base_experiment.dart';

/// Simulates database failures: connection drops, slow queries, corrupt reads.
///
/// Wrap every database call site with [wrap] to inject chaos:
///
/// ```dart
/// final dbChaos = DatabaseChaos(config: config);
///
/// // Returns the real result, a corrupted result, or throws.
/// final users = await dbChaos.wrap(
///   () => db.query('SELECT * FROM users'),
///   label: 'users.getAll',
/// );
/// ```
///
/// ## Fault types
///
/// | Fault | Config param | Effect |
/// |-------|-------------|--------|
/// | Kill  | [ChaosConfig.killDatabase] | Throws [DatabaseKillException] |
/// | Slow  | [ChaosConfig.slowDatabase] | Adds `databaseDelayMs` sleep |
/// | Corrupt | [ChaosConfig.corruptDatabaseRead] | Returns `null as T` |
///
/// Order: Kill > Slow > Corrupt (most severe first).
class DatabaseChaos extends BaseExperiment {
  /// Creates a [DatabaseChaos] experiment.
  DatabaseChaos({required super.config, super.seed});

  @override
  String get name => 'DatabaseChaos';

  @override
  String get description =>
      'Simulates database connection failures, slow queries, and '
      'corrupt read results.';

  // ── Core fault-injection ──────────────────────────────────────────────────

  /// Wraps a database operation with chaos injection.
  ///
  /// [label] is an optional identifier shown in event metadata (e.g.
  /// `'users.getById'`).
  ///
  /// Possible outcomes:
  /// - **Kill**: throws [DatabaseKillException] immediately.
  /// - **Slow**: delays [config.databaseDelayMs] ms before executing
  ///   [operation].
  /// - **Corrupt**: executes [operation] but discards result, returning `null`.
  /// - **Pass**: executes [operation] and returns its result unchanged.
  Future<T?> wrap<T>(
    Future<T> Function() operation, {
    String label = 'unknown',
  }) async {
    if (!config.enabled) return operation();

    // 1. Kill — most severe, checked first.
    if (rollFor(config.killDatabase)) {
      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'DB connection killed  [$label]',
        metadata: {'label': label, 'fault': 'kill'},
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('🗄️💀 DB KILL  [$label]');
      throw DatabaseKillException(
        'chaos_monkey: database connection forcibly terminated for "$label". '
        'Your app should handle this with a retry or cached fallback.',
      );
    }

    // 2. Slow query.
    if (rollFor(config.slowDatabase)) {
      final jitter = (config.databaseDelayMs * 0.2).round();
      final delay = config.databaseDelayMs + jitter;

      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'DB query slowed +${delay}ms  [$label]',
        durationMs: delay,
        metadata: {'label': label, 'delayMs': delay, 'fault': 'slow'},
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('🗄️⏳ DB SLOW  [$label]  +${delay}ms');
      await Future<void>.delayed(Duration(milliseconds: delay));
    }

    // 3. Corrupt read.
    if (rollFor(config.corruptDatabaseRead)) {
      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'DB read corrupted → null  [$label]',
        metadata: {'label': label, 'fault': 'corrupt'},
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('🗄️🔥 DB CORRUPT  [$label]  → returning null');
      // Execute operation to avoid resource leaks but discard result.
      await operation().catchError((_) => null as T);
      return null;
    }

    return operation();
  }

  // ── Scheduler-driven execution ────────────────────────────────────────────

  @override
  Future<void> execute({void Function(ChaosEvent event)? onEvent}) async {
    await super.execute(onEvent: onEvent);
    if (!shouldTrigger()) return;

    // Emit a synthetic scheduler-level DB event for observability.
    final fault = rollFor(config.killDatabase)
        ? 'kill'
        : rollFor(config.slowDatabase)
            ? 'slow'
            : 'corrupt';

    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: DateTime.now(),
      description: 'Scheduler: synthetic DB $fault event',
      metadata: {'source': 'scheduler', 'fault': fault},
      tags: config.tags,
    );
    emitEvent(event, onEvent: onEvent);
    ChaosLogger.chaos('🗄️📅 Scheduler DB event fired  [$fault]');
  }

  @override
  bool shouldTrigger() =>
      config.enabled &&
      (config.killDatabase > 0 ||
          config.slowDatabase > 0 ||
          config.corruptDatabaseRead > 0);

  @override
  Future<void> cleanup() async {
    ChaosLogger.info('DatabaseChaos cleanup complete.');
  }
}

// ── Exceptions ───────────────────────────────────────────────────────────────

/// Thrown when chaos kills a database connection.
class DatabaseKillException extends ChaosExperimentException {
  /// Creates the exception.
  const DatabaseKillException(super.message);
}

/// Thrown when a database query is blocked entirely (reserved for future use).
class DatabaseTimeoutException extends ChaosExperimentException {
  /// Creates the exception.
  const DatabaseTimeoutException(super.message);
}
