import '../chaos_monkey.dart' show ChaosEvent, ChaosReport;
import '../config/chaos_config.dart';

/// Abstract interface for all chaos reporters.
///
/// A reporter is notified at three points in the ChaosMonkey lifecycle:
/// 1. [onChaosStarted] — when the monkey boots up.
/// 2. [onChaosEvent]   — each time a fault is injected.
/// 3. [onChaosStopped] — when the monkey shuts down with a full report.
///
/// ## Implementing a custom reporter
///
/// ```dart
/// class MyReporter implements ChaosReporter {
///   @override
///   void onChaosStarted(ChaosConfig config) {
///     myAlertSystem.info('ChaosMonkey started: ${config.intensityLabel}');
///   }
///
///   @override
///   void onChaosEvent(ChaosEvent event) {
///     myMetricsPipeline.increment('chaos.${event.experimentType}');
///   }
///
///   @override
///   void onChaosStopped(ChaosReport report) {
///     myAlertSystem.info(
///       'ChaosMonkey stopped after '
///       '${report.totalDuration.inSeconds}s',
///     );
///   }
/// }
///
/// await ChaosMonkey.start(
///   config: config,
///   reporter: MyReporter(),
/// );
/// ```
abstract class ChaosReporter {
  /// Called once when [ChaosMonkey.start] completes setup.
  void onChaosStarted(ChaosConfig config);

  /// Called each time a chaos event fires.
  void onChaosEvent(ChaosEvent event);

  /// Called once when [ChaosMonkey.stop] is called, with the full session
  /// report.
  void onChaosStopped(ChaosReport report);
}

/// A no-op reporter that silently discards all events.
///
/// Useful in headless test environments where log output is undesirable.
class SilentReporter implements ChaosReporter {
  /// Creates a [SilentReporter].
  const SilentReporter();

  @override
  void onChaosStarted(ChaosConfig config) {}

  @override
  void onChaosEvent(ChaosEvent event) {}

  @override
  void onChaosStopped(ChaosReport report) {}
}

/// Configuration token for reporters.
///
/// Used in [ChaosConfig.reporter] to declare which reporter type to
/// instantiate.  Concrete subclasses: [ConsoleReporterConfig],
/// [FileReporterConfig], [CallbackReporterConfig].
abstract class ReporterConfig {
  /// Const constructor for subclasses.
  const ReporterConfig();
}

/// A composite reporter that forwards every event to multiple reporters.
///
/// ```dart
/// final reporter = MultiReporter([
///   ConsoleReporter(),
///   FileReporter(logPath: '/tmp/chaos.log'),
///   CallbackReporter(onEvent: (e) => analytics.track(e)),
/// ]);
/// ```
class MultiReporter implements ChaosReporter {
  /// Creates a [MultiReporter] wrapping [reporters].
  const MultiReporter(this.reporters);

  /// The list of reporters to forward events to.
  final List<ChaosReporter> reporters;

  @override
  void onChaosStarted(ChaosConfig config) {
    for (final r in reporters) r.onChaosStarted(config);
  }

  @override
  void onChaosEvent(ChaosEvent event) {
    for (final r in reporters) r.onChaosEvent(event);
  }

  @override
  void onChaosStopped(ChaosReport report) {
    for (final r in reporters) r.onChaosStopped(report);
  }
}
