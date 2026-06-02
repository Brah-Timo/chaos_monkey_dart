import 'dart:async';
import 'config/chaos_config.dart';
import 'experiments/base_experiment.dart';
import 'experiments/network_chaos.dart';
import 'experiments/database_chaos.dart';
import 'experiments/file_chaos.dart';
import 'experiments/memory_chaos.dart';
import 'experiments/cpu_chaos.dart';
import 'experiments/exception_chaos.dart';
import 'experiments/latency_chaos.dart';
import 'reporters/chaos_reporter.dart';
import 'reporters/console_reporter.dart';
import 'scheduler/chaos_scheduler.dart';
import 'utils/environment_guard.dart';
import 'utils/chaos_logger.dart';

// We expose meta only for @visibleForTesting.
// ignore: implementation_imports
import 'package:meta/meta.dart';

/// The central controller for `chaos_monkey_dart`.
///
/// ## Lifecycle
///
/// ```
///   start() ──► running ──► pause() ──► paused ──► resume()
///                  │                                    │
///                  └─────────────────────► stop() ──► report
/// ```
///
/// ## Minimal usage
///
/// ```dart
/// // In main() or your DI setup — staging only:
/// await ChaosMonkey.start(
///   config: ChaosConfig(
///     killDatabase: 0.05,
///     slowNetwork:  0.20,
///     networkDelayMs: 10000,
///   ),
/// );
/// runApp(const MyApp());
///
/// // When done (e.g. in tests):
/// final report = await ChaosMonkey.stop();
/// print(report);
/// ```
///
/// ## Preset usage
///
/// ```dart
/// await ChaosMonkey.start(config: ChaosConfig.medium());
/// ```
class ChaosMonkey {
  ChaosMonkey._();

  // ── Singleton ──────────────────────────────────────────────────────────────

  static ChaosMonkey? _instance;

  /// The global singleton instance.
  static ChaosMonkey get instance => _instance ??= ChaosMonkey._();

  // ── Private state ─────────────────────────────────────────────────────────

  late ChaosConfig _config;
  late ChaosReporter _reporter;
  late ChaosScheduler _scheduler;

  bool _isRunning = false;
  bool _isPaused = false;

  final List<BaseExperiment> _activeExperiments = [];
  final List<ChaosEvent> _eventHistory = [];
  int _totalEventsTriggered = 0;
  DateTime? _startTime;

  // ── Public read-only accessors ────────────────────────────────────────────

  /// The [ChaosConfig] currently in use.
  ChaosConfig get config => _config;

  /// `true` while chaos experiments are active.
  bool get isRunning => _isRunning;

  /// `true` while chaos has been paused via [pause].
  bool get isPaused => _isPaused;

  /// Immutable snapshot of all events recorded so far.
  List<ChaosEvent> get eventHistory => List.unmodifiable(_eventHistory);

  /// Total number of chaos events triggered since [start] was called.
  int get totalEventsTriggered => _totalEventsTriggered;

  // ── Static facade ─────────────────────────────────────────────────────────

  /// Starts ChaosMonkey with the given [config].
  ///
  /// [isRelease] should be set to `kReleaseMode` when calling from Flutter so
  /// the production guard works correctly without importing Flutter here.
  ///
  /// Throws [ChaosInProductionException] if [config.safetyGuard] is `true`
  /// and [isRelease] is `true`.
  ///
  /// Returns silently (no-op) if [config.enabled] is `false`.
  static Future<void> start({
    required ChaosConfig config,
    ChaosReporter? reporter,
    bool isRelease = false,
  }) async {
    await instance._start(
      config: config,
      reporter: reporter,
      isRelease: isRelease,
    );
  }

  /// Convenience factory: start with individually named parameters instead of
  /// constructing a [ChaosConfig] manually.
  ///
  /// ```dart
  /// await ChaosMonkey.quickStart(
  ///   killDatabase: 0.05,
  ///   slowNetwork:  0.20,
  ///   networkDelayMs: 10000,
  /// );
  /// ```
  static Future<void> quickStart({
    double killDatabase = 0.0,
    double slowNetwork = 0.0,
    double dropNetwork = 0.0,
    double throwRandomException = 0.0,
    double injectLatency = 0.0,
    int networkDelayMs = 5000,
    bool isRelease = false,
  }) async {
    await start(
      config: ChaosConfig(
        killDatabase: killDatabase,
        slowNetwork: slowNetwork,
        dropNetwork: dropNetwork,
        throwRandomException: throwRandomException,
        injectLatency: injectLatency,
        networkDelayMs: networkDelayMs,
      ),
      isRelease: isRelease,
    );
  }

  /// Stops all active experiments and returns a [ChaosReport].
  static Future<ChaosReport> stop() => instance._stop();

  /// Temporarily suppresses chaos without cancelling the scheduler.
  ///
  /// In-flight experiments complete normally; new ones are skipped.
  static void pause() => instance._pause();

  /// Resumes chaos after [pause].
  static void resume() => instance._resume();

  /// Returns a real-time [ChaosStatus] snapshot — cheap, no allocations.
  static ChaosStatus status() => instance._status();

  /// Updates the config while ChaosMonkey is running.
  ///
  /// The new config takes effect on the **next** scheduler tick and on the
  /// next interceptor call.  Currently running experiments use the old config.
  static void updateConfig(ChaosConfig newConfig) {
    if (!instance._isRunning) {
      ChaosLogger.warning(
        'updateConfig called while ChaosMonkey is not running.',
      );
      return;
    }
    instance._config = newConfig;
    ChaosLogger.info('ChaosMonkey config updated on-the-fly.');
  }

  // ── Internal implementation ───────────────────────────────────────────────

  Future<void> _start({
    required ChaosConfig config,
    ChaosReporter? reporter,
    bool isRelease = false,
  }) async {
    // ── Production guard ────────────────────────────────────────────────────
    if (config.safetyGuard) {
      EnvironmentGuard.assertNotProduction(isRelease: isRelease);
    }

    // ── Master switch ───────────────────────────────────────────────────────
    if (!config.enabled) {
      ChaosLogger.info(
        'ChaosMonkey: config.enabled = false — staying silent.',
      );
      return;
    }

    if (_isRunning) {
      ChaosLogger.warning(
        'ChaosMonkey is already running. Call stop() before restarting.',
      );
      return;
    }

    _config = config;
    _reporter = reporter ?? ConsoleReporter();
    _startTime = DateTime.now();
    _isRunning = true;
    _isPaused = false;
    _totalEventsTriggered = 0;
    _eventHistory.clear();
    _activeExperiments.clear();

    // ── Build experiment list ───────────────────────────────────────────────
    final seed = config.seed;

    if (config.slowNetwork > 0 || config.dropNetwork > 0) {
      _activeExperiments.add(NetworkChaos(config: config, seed: seed));
    }
    if (config.killDatabase > 0 ||
        config.slowDatabase > 0 ||
        config.corruptDatabaseRead > 0) {
      _activeExperiments.add(DatabaseChaos(config: config, seed: seed));
    }
    if (config.deleteRandomFile > 0 || config.corruptRandomFile > 0) {
      _activeExperiments.add(FileChaos(config: config, seed: seed));
    }
    if (config.memoryPressure > 0) {
      _activeExperiments.add(MemoryChaos(config: config, seed: seed));
    }
    if (config.cpuSpike > 0) {
      _activeExperiments.add(CpuChaos(config: config, seed: seed));
    }
    if (config.throwRandomException > 0) {
      _activeExperiments.add(ExceptionChaos(config: config, seed: seed));
    }
    if (config.injectLatency > 0) {
      _activeExperiments.add(LatencyChaos(config: config, seed: seed));
    }

    // Attach event callback to all experiments
    for (final exp in _activeExperiments) {
      exp.onEventTriggered = _recordEvent;
    }

    // ── Start scheduler ─────────────────────────────────────────────────────
    _scheduler = ChaosScheduler(
      experiments: _activeExperiments,
      intervalSeconds: config.schedulerIntervalSeconds,
      maxConcurrent: config.maxConcurrentExperiments,
      onEvent: _recordEvent,
      isPausedCallback: () => _isPaused,
    );
    await _scheduler.start();

    _reporter.onChaosStarted(config);

    ChaosLogger.info(
      '🐒 ChaosMonkey STARTED  |  '
      '${_activeExperiments.length} experiments  |  '
      'intensity ${(config.totalChaosIntensity * 100).toStringAsFixed(1)}%  |  '
      'env: ${EnvironmentGuard.describe(isRelease: isRelease)}',
    );
  }

  Future<ChaosReport> _stop() async {
    if (!_isRunning) {
      ChaosLogger.warning('ChaosMonkey.stop() called but not running.');
      return ChaosReport.empty();
    }

    await _scheduler.stop();

    for (final experiment in _activeExperiments) {
      try {
        await experiment.cleanup();
      } catch (e, st) {
        ChaosLogger.error(
          'Error during ${experiment.name} cleanup',
          error: e,
          stackTrace: st,
        );
      }
    }

    _isRunning = false;
    _isPaused = false;

    final report = ChaosReport(
      config: _config,
      startTime: _startTime!,
      endTime: DateTime.now(),
      events: List.from(_eventHistory),
      totalEventsTriggered: _totalEventsTriggered,
    );

    _reporter.onChaosStopped(report);
    ChaosLogger.info(
      '🐒 ChaosMonkey STOPPED  |  total events: $_totalEventsTriggered  |  '
      'duration: ${report.totalDuration.inSeconds}s',
    );
    return report;
  }

  void _pause() {
    if (!_isRunning) return;
    _isPaused = true;
    ChaosLogger.info('⏸  ChaosMonkey PAUSED');
  }

  void _resume() {
    if (!_isRunning) return;
    _isPaused = false;
    ChaosLogger.info('▶️  ChaosMonkey RESUMED');
  }

  void _recordEvent(ChaosEvent event) {
    _eventHistory.add(event);
    _totalEventsTriggered++;
    _reporter.onChaosEvent(event);
  }

  ChaosStatus _status() => ChaosStatus(
        isRunning: _isRunning,
        isPaused: _isPaused,
        activeExperimentsCount: _activeExperiments.length,
        totalEventsTriggered: _totalEventsTriggered,
        uptime: _startTime != null
            ? DateTime.now().difference(_startTime!)
            : Duration.zero,
        lastEvent:
            _eventHistory.isNotEmpty ? _eventHistory.last : null,
        config: _isRunning ? _config : null,
      );

  // ── Testing helpers ───────────────────────────────────────────────────────

  /// Resets the singleton — **only for use in tests**.
  @visibleForTesting
  static void reset() {
    if (_instance?._isRunning == true) {
      _instance!._isRunning = false;
    }
    _instance = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Value objects
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single chaos event that was triggered during a session.
class ChaosEvent {
  /// Creates a [ChaosEvent].
  const ChaosEvent({
    required this.experimentType,
    required this.triggeredAt,
    required this.description,
    this.durationMs,
    this.metadata = const <String, dynamic>{},
    this.tags = const <String>[],
  });

  /// The experiment class name (e.g. `'NetworkChaos'`).
  final String experimentType;

  /// Wall-clock time when the event fired.
  final DateTime triggeredAt;

  /// Short description of what happened.
  final String description;

  /// Duration of the injected fault in milliseconds, if applicable.
  final int? durationMs;

  /// Arbitrary key-value metadata (e.g. URL, HTTP status, delay).
  final Map<String, dynamic> metadata;

  /// Tags inherited from [ChaosConfig.tags].
  final List<String> tags;

  @override
  String toString() {
    final ms = durationMs != null ? ' (+${durationMs}ms)' : '';
    return '[${triggeredAt.toIso8601String()}] '
        '$experimentType: $description$ms';
  }
}

/// Aggregated summary produced when [ChaosMonkey.stop] is called.
class ChaosReport {
  /// Creates a [ChaosReport].
  const ChaosReport({
    required this.config,
    required this.startTime,
    required this.endTime,
    required this.events,
    required this.totalEventsTriggered,
  });

  /// Factory for an empty / no-op report.
  factory ChaosReport.empty() => ChaosReport(
        config: const ChaosConfig(),
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        events: const [],
        totalEventsTriggered: 0,
      );

  /// The config that was active during the session.
  final ChaosConfig config;

  /// When [ChaosMonkey.start] was called.
  final DateTime startTime;

  /// When [ChaosMonkey.stop] was called.
  final DateTime endTime;

  /// All events recorded during the session.
  final List<ChaosEvent> events;

  /// Total events triggered (should equal `events.length`).
  final int totalEventsTriggered;

  /// Session duration.
  Duration get totalDuration => endTime.difference(startTime);

  /// Count of events grouped by experiment type.
  Map<String, int> get eventsByType {
    final counts = <String, int>{};
    for (final event in events) {
      counts[event.experimentType] =
          (counts[event.experimentType] ?? 0) + 1;
    }
    return Map.fromEntries(
      counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Average events per minute over the session.
  double get eventsPerMinute {
    final minutes = totalDuration.inSeconds / 60.0;
    return minutes > 0 ? totalEventsTriggered / minutes : 0;
  }

  @override
  String toString() {
    final breakdown = eventsByType.entries
        .map((e) => '  ${e.key.padRight(24)} : ${e.value}')
        .join('\n');
    return '''
╔══════════════════════════════════════════════════════╗
║            🐒  CHAOS MONKEY DART  REPORT             ║
╠══════════════════════════════════════════════════════╣
  Session start  : $startTime
  Session end    : $endTime
  Duration       : ${totalDuration.inSeconds}s
  Total events   : $totalEventsTriggered
  Events / min   : ${eventsPerMinute.toStringAsFixed(1)}
  Intensity      : ${(config.totalChaosIntensity * 100).toStringAsFixed(1)}%'''
        ' [${config.intensityLabel}]\n\n'
        '  ── Breakdown ──────────────────────────────────────\n'
        '$breakdown\n'
        '╚══════════════════════════════════════════════════════╝';
  }
}

/// Lightweight real-time status snapshot — returned by [ChaosMonkey.status].
class ChaosStatus {
  /// Creates a [ChaosStatus].
  const ChaosStatus({
    required this.isRunning,
    required this.isPaused,
    required this.activeExperimentsCount,
    required this.totalEventsTriggered,
    required this.uptime,
    this.lastEvent,
    this.config,
  });

  /// `true` while the monkey is running.
  final bool isRunning;

  /// `true` while the monkey is paused.
  final bool isPaused;

  /// Number of registered experiments.
  final int activeExperimentsCount;

  /// Events triggered since [ChaosMonkey.start].
  final int totalEventsTriggered;

  /// Time elapsed since [ChaosMonkey.start].
  final Duration uptime;

  /// The most recently recorded event, or `null` if none yet.
  final ChaosEvent? lastEvent;

  /// The active config, or `null` if not running.
  final ChaosConfig? config;

  @override
  String toString() => 'ChaosStatus('
      'running=$isRunning, paused=$isPaused, '
      'experiments=$activeExperimentsCount, '
      'events=$totalEventsTriggered, '
      'uptime=${uptime.inSeconds}s)';
}
