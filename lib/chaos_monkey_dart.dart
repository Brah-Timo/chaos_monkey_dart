/// chaos_monkey_dart
///
/// A production-grade chaos engineering package for Flutter/Dart.
/// Deliberately injects failures — network delays, database failures,
/// file corruption, memory pressure, CPU spikes, random exceptions —
/// to test application resilience before real users encounter them.
///
/// ⚠️  WARNING: NEVER use in production environments.
///     This package is strictly for staging and testing only.
///     It will REFUSE to run when [kReleaseMode] is true (configurable).
///
/// ## Quick Start
///
/// ```dart
/// import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   if (kDebugMode) {
///     await ChaosMonkey.start(
///       config: ChaosConfig(
///         killDatabase: 0.05,    // 5% — DB connection dies
///         slowNetwork: 0.20,     // 20% — network delayed 10s
///         networkDelayMs: 10000,
///         dropNetwork: 0.03,     // 3% — request completely dropped
///         throwRandomException: 0.02,
///       ),
///     );
///   }
///
///   runApp(const MyApp());
/// }
/// ```
///
/// ## Presets
///
/// ```dart
/// ChaosConfig.light()    // Gentle — good for daily CI
/// ChaosConfig.medium()   // Moderate — weekly resilience checks
/// ChaosConfig.heavy()    // Aggressive — dedicated resilience sprints
/// ChaosConfig.nuclear()  // Apocalyptic — maximum chaos (use with care!)
/// ```
library chaos_monkey_dart;

// ── Core ────────────────────────────────────────────────────────────────────
export 'src/chaos_monkey.dart';

// ── Configuration ───────────────────────────────────────────────────────────
export 'src/config/chaos_config.dart';
export 'src/config/chaos_environment.dart';

// ── Experiments ─────────────────────────────────────────────────────────────
export 'src/experiments/base_experiment.dart';
export 'src/experiments/network_chaos.dart';
export 'src/experiments/database_chaos.dart';
export 'src/experiments/file_chaos.dart';
export 'src/experiments/memory_chaos.dart';
export 'src/experiments/cpu_chaos.dart';
export 'src/experiments/exception_chaos.dart';
export 'src/experiments/latency_chaos.dart';

// ── Interceptors ────────────────────────────────────────────────────────────
// NOTE: These require the consumer app to have the relevant packages in
// their own pubspec.yaml (http: ^1.2.0 / dio: ^5.4.0).
export 'src/interceptors/chaos_http_client.dart';
export 'src/interceptors/chaos_dio_interceptor.dart';
export 'src/interceptors/chaos_http_interceptor.dart';

// ── Reporters ───────────────────────────────────────────────────────────────
export 'src/reporters/chaos_reporter.dart';
export 'src/reporters/console_reporter.dart';
export 'src/reporters/file_reporter.dart';
export 'src/reporters/callback_reporter.dart';

// ── Scheduler ───────────────────────────────────────────────────────────────
export 'src/scheduler/chaos_scheduler.dart';
export 'src/scheduler/random_scheduler.dart';

// ── Utilities (public surface) ──────────────────────────────────────────────
export 'src/utils/probability.dart';
export 'src/utils/environment_guard.dart';
