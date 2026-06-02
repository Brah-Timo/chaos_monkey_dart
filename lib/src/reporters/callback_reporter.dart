import '../chaos_monkey.dart' show ChaosEvent, ChaosReport;
import '../config/chaos_config.dart';
import 'chaos_reporter.dart';

/// Configuration token for [CallbackReporter].
class CallbackReporterConfig extends ReporterConfig {
  /// Creates the config.
  const CallbackReporterConfig();
}

/// A [ChaosReporter] that forwards events to user-supplied callbacks.
///
/// Use this when you want to integrate chaos events with an existing
/// observability pipeline (e.g. Firebase Analytics, Sentry, DataDog, a
/// custom in-app overlay):
///
/// ```dart
/// await ChaosMonkey.start(
///   config: config,
///   reporter: CallbackReporter(
///     onStarted: (config) {
///       analytics.logEvent(
///         'chaos_started',
///         {'intensity': config.totalChaosIntensity},
///       );
///     },
///     onEvent: (event) {
///       Sentry.captureMessage('[chaos] ${event.description}');
///       // Update UI overlay:
///       setState(() => _lastChaosEvent = event.description);
///     },
///     onStopped: (report) {
///       analytics.logEvent(
///         'chaos_stopped',
///         {'events': report.totalEventsTriggered},
///       );
///     },
///   ),
/// );
/// ```
class CallbackReporter implements ChaosReporter {
  /// Creates a [CallbackReporter].
  ///
  /// All callbacks are optional — omitted ones default to no-ops.
  const CallbackReporter({
    this.onStarted,
    this.onEvent,
    this.onStopped,
  });

  /// Called when [ChaosMonkey.start] completes.
  final void Function(ChaosConfig config)? onStarted;

  /// Called for every chaos event.
  final void Function(ChaosEvent event)? onEvent;

  /// Called when [ChaosMonkey.stop] is called with the full report.
  final void Function(ChaosReport report)? onStopped;

  @override
  void onChaosStarted(ChaosConfig config) => onStarted?.call(config);

  @override
  void onChaosEvent(ChaosEvent event) => onEvent?.call(event);

  @override
  void onChaosStopped(ChaosReport report) => onStopped?.call(report);
}

/// A [ChaosReporter] that collects all events in memory for later inspection.
///
/// Useful in widget tests:
///
/// ```dart
/// final collector = EventCollectorReporter();
///
/// await ChaosMonkey.start(config: config, reporter: collector);
///
/// // ... run your test
///
/// await ChaosMonkey.stop();
///
/// expect(collector.events, hasLength(greaterThan(0)));
/// expect(
///   collector.events.where((e) => e.experimentType == 'NetworkChaos'),
///   isNotEmpty,
/// );
/// ```
class EventCollectorReporter implements ChaosReporter {
  final List<ChaosEvent> _events = [];
  ChaosConfig? _startConfig;
  ChaosReport? _finalReport;

  /// All events collected so far.
  List<ChaosEvent> get events => List.unmodifiable(_events);

  /// The config that was passed to [onChaosStarted], or `null`.
  ChaosConfig? get startConfig => _startConfig;

  /// The final report, available after [onChaosStopped] is called.
  ChaosReport? get finalReport => _finalReport;

  /// Number of events collected.
  int get eventCount => _events.length;

  /// Events filtered by experiment type.
  List<ChaosEvent> eventsFor(String experimentType) =>
      _events.where((e) => e.experimentType == experimentType).toList();

  /// Clears the collected events (useful between test cases).
  void clear() {
    _events.clear();
    _startConfig = null;
    _finalReport = null;
  }

  @override
  void onChaosStarted(ChaosConfig config) => _startConfig = config;

  @override
  void onChaosEvent(ChaosEvent event) => _events.add(event);

  @override
  void onChaosStopped(ChaosReport report) => _finalReport = report;
}
