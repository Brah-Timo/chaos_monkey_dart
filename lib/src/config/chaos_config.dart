import 'package:meta/meta.dart';
import '../reporters/chaos_reporter.dart';
import '../reporters/console_reporter.dart';

/// Immutable configuration object that controls every aspect of
/// chaos injection.
///
/// All probability fields accept values between `0.0` (never fires) and
/// `1.0` (fires on every eligible operation).  Intermediate values map
/// linearly to real-world percentages (e.g. `0.05` → 5 % of calls).
///
/// ## Minimal example
///
/// ```dart
/// const config = ChaosConfig(
///   killDatabase: 0.05,
///   slowNetwork:  0.20,
///   networkDelayMs: 10000,
/// );
/// ```
///
/// ## Factory presets
///
/// | Factory | Intensity | Recommended use |
/// |---------|-----------|-----------------|
/// | [ChaosConfig.light]   | ~3 %  | Daily CI |
/// | [ChaosConfig.medium]  | ~9 %  | Weekly resilience gate |
/// | [ChaosConfig.heavy]   | ~18 % | Dedicated resilience sprint |
/// | [ChaosConfig.nuclear] | ~45 % | "Chaos Days" (extreme) |
@immutable
class ChaosConfig {
  /// Creates an immutable [ChaosConfig].
  ///
  /// Every field has a safe default of `0.0` / `false`, meaning the package
  /// does **nothing** unless you explicitly raise a probability above zero.
  const ChaosConfig({
    // ── Network ──────────────────────────────────────────────────
    this.slowNetwork = 0.0,
    this.networkDelayMs = 5000,
    this.networkDelayJitterMs = 2000,
    this.dropNetwork = 0.0,
    this.networkErrorCode = 503,
    this.networkTimeoutMs = 0,

    // ── Database ─────────────────────────────────────────────────
    this.killDatabase = 0.0,
    this.slowDatabase = 0.0,
    this.databaseDelayMs = 3000,
    this.corruptDatabaseRead = 0.0,

    // ── File System ──────────────────────────────────────────────
    this.deleteRandomFile = 0.0,
    this.corruptRandomFile = 0.0,
    this.targetFilePatterns = const <String>[],

    // ── Memory ───────────────────────────────────────────────────
    this.memoryPressure = 0.0,
    this.memoryAllocationMb = 50,

    // ── CPU ──────────────────────────────────────────────────────
    this.cpuSpike = 0.0,
    this.cpuSpikeDurationMs = 2000,
    this.cpuSpikeIterations = 5000000,

    // ── Exceptions ───────────────────────────────────────────────
    this.throwRandomException = 0.0,
    this.customExceptions = const <Exception>[],

    // ── Latency ──────────────────────────────────────────────────
    this.injectLatency = 0.0,
    this.latencyMinMs = 100,
    this.latencyMaxMs = 3000,

    // ── Global ───────────────────────────────────────────────────
    this.enabled = true,
    this.safetyGuard = true,
    this.schedulerIntervalSeconds = 60,
    this.maxConcurrentExperiments = 1,
    this.reporter = const ConsoleReporterConfig(),
    this.seed,
    this.verbose = true,
    this.tags = const <String>[],
  })  : assert(
          slowNetwork >= 0.0 && slowNetwork <= 1.0,
          'slowNetwork must be between 0.0 and 1.0, got $slowNetwork',
        ),
        assert(
          dropNetwork >= 0.0 && dropNetwork <= 1.0,
          'dropNetwork must be between 0.0 and 1.0, got $dropNetwork',
        ),
        assert(
          killDatabase >= 0.0 && killDatabase <= 1.0,
          'killDatabase must be between 0.0 and 1.0, got $killDatabase',
        ),
        assert(
          slowDatabase >= 0.0 && slowDatabase <= 1.0,
          'slowDatabase must be between 0.0 and 1.0, got $slowDatabase',
        ),
        assert(
          corruptDatabaseRead >= 0.0 && corruptDatabaseRead <= 1.0,
          'corruptDatabaseRead must be between 0.0 and 1.0',
        ),
        assert(
          deleteRandomFile >= 0.0 && deleteRandomFile <= 1.0,
          'deleteRandomFile must be between 0.0 and 1.0',
        ),
        assert(
          corruptRandomFile >= 0.0 && corruptRandomFile <= 1.0,
          'corruptRandomFile must be between 0.0 and 1.0',
        ),
        assert(
          memoryPressure >= 0.0 && memoryPressure <= 1.0,
          'memoryPressure must be between 0.0 and 1.0',
        ),
        assert(
          cpuSpike >= 0.0 && cpuSpike <= 1.0,
          'cpuSpike must be between 0.0 and 1.0',
        ),
        assert(
          throwRandomException >= 0.0 && throwRandomException <= 1.0,
          'throwRandomException must be between 0.0 and 1.0',
        ),
        assert(
          injectLatency >= 0.0 && injectLatency <= 1.0,
          'injectLatency must be between 0.0 and 1.0',
        ),
        assert(networkDelayMs > 0, 'networkDelayMs must be positive'),
        assert(databaseDelayMs > 0, 'databaseDelayMs must be positive'),
        assert(
          memoryAllocationMb > 0 && memoryAllocationMb <= 512,
          'memoryAllocationMb must be between 1 and 512',
        ),
        assert(latencyMinMs >= 0, 'latencyMinMs must be >= 0'),
        assert(
          latencyMaxMs > latencyMinMs,
          'latencyMaxMs must be greater than latencyMinMs',
        );

  // ── Network ───────────────────────────────────────────────────────────────

  /// Probability (0.0–1.0) that an intercepted HTTP request is artificially
  /// delayed.  The delay magnitude is [networkDelayMs]
  /// ± [networkDelayJitterMs].
  final double slowNetwork;

  /// Base delay in milliseconds applied when [slowNetwork] fires.
  final int networkDelayMs;

  /// Maximum random ±jitter added to [networkDelayMs] to simulate realistic
  /// variance.  Actual delay = `networkDelayMs + rand(-jitter/2, +jitter/2)`.
  final int networkDelayJitterMs;

  /// Probability (0.0–1.0) that an intercepted HTTP request is completely
  /// dropped, returning an HTTP [networkErrorCode] response.
  final double dropNetwork;

  /// HTTP status code returned when [dropNetwork] fires.  Defaults to 503.
  final int networkErrorCode;

  /// If > 0, adds an explicit socket-timeout simulation of this many
  /// milliseconds on top of any existing delay.  Useful for testing
  /// `SocketException` and `TimeoutException` handlers.
  final int networkTimeoutMs;

  // ── Database ──────────────────────────────────────────────────────────────

  /// Probability (0.0–1.0) that a `DatabaseChaos.wrap()` call throws a
  /// [DatabaseChaosException], simulating a lost connection.
  final double killDatabase;

  /// Probability (0.0–1.0) that a `DatabaseChaos.wrap()` call is delayed by
  /// [databaseDelayMs] milliseconds, simulating a slow or locked query.
  final double slowDatabase;

  /// Artificial delay applied when [slowDatabase] fires, in milliseconds.
  final int databaseDelayMs;

  /// Probability (0.0–1.0) that a `DatabaseChaos.wrap()` call returns `null`
  /// instead of the real result, simulating a corrupt or empty read.
  final double corruptDatabaseRead;

  // ── File System ───────────────────────────────────────────────────────────

  /// Probability (0.0–1.0) that a file matching [targetFilePatterns] is
  /// deleted from the device's document directory.
  final double deleteRandomFile;

  /// Probability (0.0–1.0) that a file matching [targetFilePatterns] is
  /// zeroed out / replaced with garbage bytes.
  final double corruptRandomFile;

  /// Glob-style filename patterns used to scope file-system chaos to
  /// non-critical targets (e.g. `['*.cache', '*.tmp', 'draft_*']`).
  ///
  /// If empty, the file chaos experiments are silently no-ops.
  final List<String> targetFilePatterns;

  // ── Memory ────────────────────────────────────────────────────────────────

  /// Probability (0.0–1.0) that a memory-pressure event is simulated by
  /// allocating [memoryAllocationMb] MB of heap space temporarily.
  final double memoryPressure;

  /// Megabytes to allocate during a memory-pressure event.
  /// Capped at 512 MB to avoid OOM-killing the app under test.
  final int memoryAllocationMb;

  // ── CPU ───────────────────────────────────────────────────────────────────

  /// Probability (0.0–1.0) that a CPU-spike event is simulated by running a
  /// tight compute loop for [cpuSpikeDurationMs] milliseconds.
  final double cpuSpike;

  /// Duration of the simulated CPU spike in milliseconds.
  final int cpuSpikeDurationMs;

  /// Number of tight-loop iterations per CPU-spike event.
  /// Higher values → heavier spike.  Default: 5 000 000.
  final int cpuSpikeIterations;

  // ── Exceptions ────────────────────────────────────────────────────────────

  /// Probability (0.0–1.0) that a call to any `ExceptionChaos`-wrapped
  /// function throws a randomly selected exception from [customExceptions]
  /// (or a generic [ChaosException] if the list is empty).
  final double throwRandomException;

  /// Custom pool of exceptions to sample from when [throwRandomException]
  /// fires.  If empty, a [ChaosException] is thrown instead.
  final List<Exception> customExceptions;

  // ── Latency ───────────────────────────────────────────────────────────────

  /// Probability (0.0–1.0) that a `LatencyChaos.wrap()` call inserts a
  /// random delay between [latencyMinMs] and [latencyMaxMs] milliseconds.
  ///
  /// Unlike [slowNetwork] this works on *any* async call, not just HTTP.
  final double injectLatency;

  /// Minimum latency in milliseconds for [injectLatency] events.
  final int latencyMinMs;

  /// Maximum latency in milliseconds for [injectLatency] events.
  final int latencyMaxMs;

  // ── Global ────────────────────────────────────────────────────────────────

  /// Master enable switch.  Set to `false` to disable ALL chaos without
  /// removing any code.  Useful for feature-flag driven rollout.
  final bool enabled;

  /// When `true` (default), [EnvironmentGuard] will throw
  /// [ChaosInProductionException] if the app is running in release mode.
  /// Set to `false` only when you have a custom guard in place.
  final bool safetyGuard;

  /// How often (in seconds) the [ChaosScheduler] fires a random experiment
  /// autonomously, independently of interceptor-level triggers.
  final int schedulerIntervalSeconds;

  /// Maximum number of chaos experiments allowed to run concurrently.
  /// Prevents compounding failures that make root-cause analysis impossible.
  final int maxConcurrentExperiments;

  /// Reporter configuration.  Defaults to [ConsoleReporterConfig].
  /// Swap to [FileReporterConfig] or [CallbackReporterConfig] as needed.
  final ReporterConfig reporter;

  /// Optional RNG seed for fully reproducible chaos scenarios in tests.
  /// When `null` a cryptographically random seed is used.
  final int? seed;

  /// When `true`, every chaos event is printed / logged in detail.
  /// Set to `false` in headless CI to reduce log noise.
  final bool verbose;

  /// Arbitrary string tags attached to every [ChaosEvent] produced by this
  /// config.  Useful for filtering reports (e.g. `['sprint-42', 'backend']`).
  final List<String> tags;

  // ── Computed properties ───────────────────────────────────────────────────

  /// Normalised chaos intensity score in the range [0.0, 1.0].
  ///
  /// Calculated as the arithmetic mean of all independent probability fields.
  /// A value of `0.0` means silent and `1.0` means maximum anarchy.
  double get totalChaosIntensity {
    final sum = slowNetwork +
        dropNetwork +
        killDatabase +
        slowDatabase +
        corruptDatabaseRead +
        deleteRandomFile +
        corruptRandomFile +
        memoryPressure +
        cpuSpike +
        throwRandomException +
        injectLatency;
    return sum / 11.0;
  }

  /// Returns `true` if at least one experiment has a probability > 0.
  bool get hasActiveChaos =>
      slowNetwork > 0 ||
      dropNetwork > 0 ||
      killDatabase > 0 ||
      slowDatabase > 0 ||
      corruptDatabaseRead > 0 ||
      deleteRandomFile > 0 ||
      corruptRandomFile > 0 ||
      memoryPressure > 0 ||
      cpuSpike > 0 ||
      throwRandomException > 0 ||
      injectLatency > 0;

  /// Human-readable intensity label.
  String get intensityLabel {
    final i = totalChaosIntensity;
    if (i == 0) return 'SILENT';
    if (i < 0.05) return 'LIGHT';
    if (i < 0.15) return 'MEDIUM';
    if (i < 0.30) return 'HEAVY';
    return 'NUCLEAR 🔥';
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  /// Returns a copy of this [ChaosConfig] with selected fields overridden.
  ChaosConfig copyWith({
    double? slowNetwork,
    int? networkDelayMs,
    int? networkDelayJitterMs,
    double? dropNetwork,
    int? networkErrorCode,
    int? networkTimeoutMs,
    double? killDatabase,
    double? slowDatabase,
    int? databaseDelayMs,
    double? corruptDatabaseRead,
    double? deleteRandomFile,
    double? corruptRandomFile,
    List<String>? targetFilePatterns,
    double? memoryPressure,
    int? memoryAllocationMb,
    double? cpuSpike,
    int? cpuSpikeDurationMs,
    int? cpuSpikeIterations,
    double? throwRandomException,
    List<Exception>? customExceptions,
    double? injectLatency,
    int? latencyMinMs,
    int? latencyMaxMs,
    bool? enabled,
    bool? safetyGuard,
    int? schedulerIntervalSeconds,
    int? maxConcurrentExperiments,
    ReporterConfig? reporter,
    int? seed,
    bool? verbose,
    List<String>? tags,
  }) {
    return ChaosConfig(
      slowNetwork: slowNetwork ?? this.slowNetwork,
      networkDelayMs: networkDelayMs ?? this.networkDelayMs,
      networkDelayJitterMs: networkDelayJitterMs ?? this.networkDelayJitterMs,
      dropNetwork: dropNetwork ?? this.dropNetwork,
      networkErrorCode: networkErrorCode ?? this.networkErrorCode,
      networkTimeoutMs: networkTimeoutMs ?? this.networkTimeoutMs,
      killDatabase: killDatabase ?? this.killDatabase,
      slowDatabase: slowDatabase ?? this.slowDatabase,
      databaseDelayMs: databaseDelayMs ?? this.databaseDelayMs,
      corruptDatabaseRead: corruptDatabaseRead ?? this.corruptDatabaseRead,
      deleteRandomFile: deleteRandomFile ?? this.deleteRandomFile,
      corruptRandomFile: corruptRandomFile ?? this.corruptRandomFile,
      targetFilePatterns: targetFilePatterns ?? this.targetFilePatterns,
      memoryPressure: memoryPressure ?? this.memoryPressure,
      memoryAllocationMb: memoryAllocationMb ?? this.memoryAllocationMb,
      cpuSpike: cpuSpike ?? this.cpuSpike,
      cpuSpikeDurationMs: cpuSpikeDurationMs ?? this.cpuSpikeDurationMs,
      cpuSpikeIterations: cpuSpikeIterations ?? this.cpuSpikeIterations,
      throwRandomException: throwRandomException ?? this.throwRandomException,
      customExceptions: customExceptions ?? this.customExceptions,
      injectLatency: injectLatency ?? this.injectLatency,
      latencyMinMs: latencyMinMs ?? this.latencyMinMs,
      latencyMaxMs: latencyMaxMs ?? this.latencyMaxMs,
      enabled: enabled ?? this.enabled,
      safetyGuard: safetyGuard ?? this.safetyGuard,
      schedulerIntervalSeconds:
          schedulerIntervalSeconds ?? this.schedulerIntervalSeconds,
      maxConcurrentExperiments:
          maxConcurrentExperiments ?? this.maxConcurrentExperiments,
      reporter: reporter ?? this.reporter,
      seed: seed ?? this.seed,
      verbose: verbose ?? this.verbose,
      tags: tags ?? this.tags,
    );
  }

  // ── Presets ───────────────────────────────────────────────────────────────

  /// **Light preset** — gentle chaos suitable for daily CI pipelines.
  ///
  /// Total intensity ≈ 3 %.  Only network slowness and minor exceptions.
  factory ChaosConfig.light() => const ChaosConfig(
        slowNetwork: 0.05,
        networkDelayMs: 3000,
        killDatabase: 0.01,
        throwRandomException: 0.01,
        injectLatency: 0.02,
      );

  /// **Medium preset** — moderate chaos for weekly resilience gate checks.
  ///
  /// Total intensity ≈ 5–6 %.  Network, database, and latency combined.
  factory ChaosConfig.medium() => const ChaosConfig(
        slowNetwork: 0.20,
        networkDelayMs: 5000,
        dropNetwork: 0.05,
        killDatabase: 0.10,
        slowDatabase: 0.10,
        databaseDelayMs: 2000,
        throwRandomException: 0.05,
        injectLatency: 0.08,
      );

  /// **Heavy preset** — aggressive chaos for dedicated resilience sprints.
  ///
  /// Total intensity ≈ 18 %.  All subsystems under pressure.
  factory ChaosConfig.heavy() => const ChaosConfig(
        slowNetwork: 0.30,
        networkDelayMs: 8000,
        dropNetwork: 0.10,
        killDatabase: 0.10,
        slowDatabase: 0.15,
        databaseDelayMs: 4000,
        corruptDatabaseRead: 0.03,
        deleteRandomFile: 0.03,
        memoryPressure: 0.05,
        cpuSpike: 0.03,
        throwRandomException: 0.08,
        injectLatency: 0.10,
      );

  /// **Nuclear preset** — maximum chaos.  Handle with extreme caution.
  ///
  /// Total intensity ≈ 34 %.  Only for dedicated "Chaos Day" events.
  ///
  /// ⚠️  Do NOT run this in a production-adjacent environment.
  factory ChaosConfig.nuclear() => const ChaosConfig(
        slowNetwork: 0.75,
        networkDelayMs: 12000,
        networkDelayJitterMs: 4000,
        dropNetwork: 0.45,
        killDatabase: 0.40,
        slowDatabase: 0.55,
        databaseDelayMs: 6000,
        corruptDatabaseRead: 0.20,
        deleteRandomFile: 0.15,
        corruptRandomFile: 0.10,
        memoryPressure: 0.25,
        memoryAllocationMb: 128,
        cpuSpike: 0.25,
        cpuSpikeDurationMs: 3000,
        throwRandomException: 0.30,
        injectLatency: 0.30,
        latencyMinMs: 500,
        latencyMaxMs: 8000,
      );

  // ── Equality & toString ───────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChaosConfig &&
          runtimeType == other.runtimeType &&
          slowNetwork == other.slowNetwork &&
          dropNetwork == other.dropNetwork &&
          killDatabase == other.killDatabase &&
          slowDatabase == other.slowDatabase &&
          throwRandomException == other.throwRandomException &&
          enabled == other.enabled &&
          seed == other.seed;

  @override
  int get hashCode =>
      slowNetwork.hashCode ^
      dropNetwork.hashCode ^
      killDatabase.hashCode ^
      slowDatabase.hashCode ^
      throwRandomException.hashCode ^
      enabled.hashCode ^
      seed.hashCode;

  @override
  String toString() {
    final pct = (double v) => '${(v * 100).toStringAsFixed(1)}%';
    return '''
ChaosConfig {
  intensity  : ${pct(totalChaosIntensity)} [${intensityLabel}]
  enabled    : $enabled  |  safetyGuard: $safetyGuard  |  seed: $seed

  ─── Network ───────────────────────────────────────
  slowNetwork          : ${pct(slowNetwork)}
                          (+${networkDelayMs}ms ±${networkDelayJitterMs}ms)
  dropNetwork          : ${pct(dropNetwork)}  [HTTP $networkErrorCode]
  networkTimeoutMs     : ${networkTimeoutMs}ms

  ─── Database ──────────────────────────────────────
  killDatabase         : ${pct(killDatabase)}
  slowDatabase         : ${pct(slowDatabase)}  (+${databaseDelayMs}ms)
  corruptDatabaseRead  : ${pct(corruptDatabaseRead)}

  ─── File System ───────────────────────────────────
  deleteRandomFile     : ${pct(deleteRandomFile)}
  corruptRandomFile    : ${pct(corruptRandomFile)}
  patterns             : $targetFilePatterns

  ─── Memory ────────────────────────────────────────
  memoryPressure       : ${pct(memoryPressure)}  (${memoryAllocationMb}MB alloc)

  ─── CPU ───────────────────────────────────────────
  cpuSpike             : ${pct(cpuSpike)}
                          (${cpuSpikeDurationMs}ms / $cpuSpikeIterations iters)

  ─── Exceptions ────────────────────────────────────
  throwRandomException : ${pct(throwRandomException)}
                          (pool: ${customExceptions.length})

  ─── Latency ───────────────────────────────────────
  injectLatency        : ${pct(injectLatency)}
                          (${latencyMinMs}–${latencyMaxMs}ms)

  ─── Scheduler ─────────────────────────────────────
  interval             : ${schedulerIntervalSeconds}s
  maxConcurrent        : $maxConcurrentExperiments
}''';
  }
}
