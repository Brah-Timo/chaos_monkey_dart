import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

/// Test helper that creates a [ChaosConfig] guaranteed to trigger every
/// experiment on every call.  Useful for deterministic fault-injection tests.
ChaosConfig alwaysTriggerConfig({
  int networkDelayMs = 100,
  int databaseDelayMs = 100,
}) =>
    ChaosConfig(
      slowNetwork: 1.0,
      networkDelayMs: networkDelayMs,
      networkDelayJitterMs: 0,
      dropNetwork: 0.0, // keep 0 so we can test slow separately
      killDatabase: 0.0,
      slowDatabase: 1.0,
      databaseDelayMs: databaseDelayMs,
      corruptDatabaseRead: 0.0,
      throwRandomException: 0.0,
      injectLatency: 1.0,
      latencyMinMs: networkDelayMs,
      latencyMaxMs: networkDelayMs + 1,
      safetyGuard: false,
      seed: 42,
    );

/// A [ChaosConfig] that always kills the database.
ChaosConfig alwaysKillDatabaseConfig() => const ChaosConfig(
      killDatabase: 1.0,
      safetyGuard: false,
      seed: 42,
    );

/// A [ChaosConfig] that always drops network requests.
ChaosConfig alwaysDropNetworkConfig() => const ChaosConfig(
      dropNetwork: 1.0,
      networkErrorCode: 503,
      safetyGuard: false,
      seed: 42,
    );

/// A [ChaosConfig] that always throws random exceptions.
ChaosConfig alwaysThrowConfig() => const ChaosConfig(
      throwRandomException: 1.0,
      safetyGuard: false,
      seed: 42,
    );

/// A completely silent [ChaosConfig] — nothing fires.
const ChaosConfig silentConfig = ChaosConfig(
  enabled: false,
  safetyGuard: false,
);

/// Installs a [EventCollectorReporter] for the duration of [body] and
/// returns the collected events.
///
/// ```dart
/// final events = await withChaosCollector(
///   config: const ChaosConfig(throwRandomException: 1.0, safetyGuard: false),
///   body: () async {
///     // ... do stuff
///   },
/// );
/// expect(events, hasLength(greaterThan(0)));
/// ```
Future<List<ChaosEvent>> withChaosCollector({
  required ChaosConfig config,
  required Future<void> Function() body,
}) async {
  final collector = EventCollectorReporter();
  await ChaosMonkey.start(config: config, reporter: collector);
  try {
    await body();
  } finally {
    await ChaosMonkey.stop();
  }
  return collector.events;
}
