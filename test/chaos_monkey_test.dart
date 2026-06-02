import 'package:test/test.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';
import 'helpers/mock_helpers.dart';

void main() {
  setUp(ChaosMonkey.reset);
  tearDown(ChaosMonkey.reset);

  group('ChaosMonkey.start', () {
    test('does nothing when config.enabled = false', () async {
      await ChaosMonkey.start(config: silentConfig);
      expect(ChaosMonkey.status().isRunning, isFalse);
    });

    test('starts successfully with valid config', () async {
      await ChaosMonkey.start(
        config: const ChaosConfig(
          slowNetwork: 0.10,
          killDatabase: 0.05,
          safetyGuard: false,
        ),
        reporter: const SilentReporter(),
      );
      expect(ChaosMonkey.status().isRunning, isTrue);
      await ChaosMonkey.stop();
    });

    test('no-ops when called twice without stop', () async {
      await ChaosMonkey.start(
        config: const ChaosConfig(
          slowNetwork: 0.10,
          safetyGuard: false,
        ),
        reporter: const SilentReporter(),
      );
      // Second call should be silently ignored
      await ChaosMonkey.start(
        config: const ChaosConfig(
          slowNetwork: 0.50,
          safetyGuard: false,
        ),
        reporter: const SilentReporter(),
      );
      // Config should still be the first one
      expect(ChaosMonkey.status().config?.slowNetwork, equals(0.10));
      await ChaosMonkey.stop();
    });
  });

  group('ChaosMonkey.stop', () {
    test('returns empty report when not running', () async {
      final report = await ChaosMonkey.stop();
      expect(report.totalEventsTriggered, equals(0));
    });

    test('returns report with correct config after start/stop', () async {
      const config = ChaosConfig(
        slowNetwork: 0.20,
        networkDelayMs: 100,
        safetyGuard: false,
      );
      await ChaosMonkey.start(config: config, reporter: const SilentReporter());
      final report = await ChaosMonkey.stop();

      expect(report.config.slowNetwork, equals(0.20));
      expect(report.totalDuration, isNotNull);
    });

    test('isRunning is false after stop', () async {
      await ChaosMonkey.start(
        config: const ChaosConfig(slowNetwork: 0.10, safetyGuard: false),
        reporter: const SilentReporter(),
      );
      await ChaosMonkey.stop();
      expect(ChaosMonkey.status().isRunning, isFalse);
    });
  });

  group('ChaosMonkey.pause / resume', () {
    test('isPaused toggles correctly', () async {
      await ChaosMonkey.start(
        config: const ChaosConfig(slowNetwork: 0.10, safetyGuard: false),
        reporter: const SilentReporter(),
      );

      ChaosMonkey.pause();
      expect(ChaosMonkey.status().isPaused, isTrue);

      ChaosMonkey.resume();
      expect(ChaosMonkey.status().isPaused, isFalse);

      await ChaosMonkey.stop();
    });
  });

  group('ChaosMonkey.quickStart', () {
    test('starts with named params correctly', () async {
      await ChaosMonkey.quickStart(
        killDatabase: 0.05,
        slowNetwork: 0.20,
      );
      final status = ChaosMonkey.status();
      expect(status.isRunning, isTrue);
      expect(status.config?.killDatabase, equals(0.05));
      expect(status.config?.slowNetwork, equals(0.20));
      await ChaosMonkey.stop();
    });
  });

  group('ChaosReport', () {
    test('eventsByType groups correctly', () {
      final report = ChaosReport(
        config: const ChaosConfig(),
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(seconds: 10)),
        events: [
          ChaosEvent(
            experimentType: 'NetworkChaos',
            triggeredAt: DateTime.now(),
            description: 'slow',
          ),
          ChaosEvent(
            experimentType: 'NetworkChaos',
            triggeredAt: DateTime.now(),
            description: 'drop',
          ),
          ChaosEvent(
            experimentType: 'DatabaseChaos',
            triggeredAt: DateTime.now(),
            description: 'kill',
          ),
        ],
        totalEventsTriggered: 3,
      );

      expect(report.eventsByType['NetworkChaos'], equals(2));
      expect(report.eventsByType['DatabaseChaos'], equals(1));
    });

    test('eventsPerMinute calculates correctly', () {
      final start = DateTime.now();
      final end = start.add(const Duration(minutes: 2));
      final report = ChaosReport(
        config: const ChaosConfig(),
        startTime: start,
        endTime: end,
        events: const [],
        totalEventsTriggered: 60,
      );
      expect(report.eventsPerMinute, closeTo(30.0, 0.1));
    });

    test('toString contains key sections', () {
      final report = ChaosReport.empty();
      final s = report.toString();
      expect(s, contains('CHAOS MONKEY DART'));
      expect(s, contains('Duration'));
      expect(s, contains('Total events'));
    });
  });

  group('EventCollectorReporter', () {
    test('collects all events', () async {
      final collector = EventCollectorReporter();

      await ChaosMonkey.start(
        config: const ChaosConfig(
          slowNetwork: 1.0,
          networkDelayMs: 20,
          networkDelayJitterMs: 0,
          safetyGuard: false,
          seed: 42,
        ),
        reporter: collector,
      );

      final networkChaos = NetworkChaos(
        config: const ChaosConfig(
          slowNetwork: 1.0,
          networkDelayMs: 20,
          networkDelayJitterMs: 0,
          safetyGuard: false,
          seed: 42,
        ),
      );
      networkChaos.onEventTriggered = collector.onChaosEvent;
      await networkChaos.applyToRequest('https://test.com', 'GET');

      await ChaosMonkey.stop();

      expect(collector.eventCount, greaterThanOrEqualTo(1));
    });

    test('eventsFor filters by type', () {
      final collector = EventCollectorReporter();
      collector.onChaosEvent(ChaosEvent(
        experimentType: 'NetworkChaos',
        triggeredAt: DateTime.now(),
        description: 'test',
      ));
      collector.onChaosEvent(ChaosEvent(
        experimentType: 'DatabaseChaos',
        triggeredAt: DateTime.now(),
        description: 'test',
      ));

      expect(collector.eventsFor('NetworkChaos'), hasLength(1));
      expect(collector.eventsFor('DatabaseChaos'), hasLength(1));
      expect(collector.eventsFor('MemoryChaos'), isEmpty);
    });
  });

  group('EnvironmentGuard', () {
    test('assertNotProduction passes in debug mode', () {
      // isRelease = false simulates debug/test mode
      expect(
        () => EnvironmentGuard.assertNotProduction(isRelease: false),
        returnsNormally,
      );
    });

    test('assertNotProduction throws when isRelease = true', () {
      expect(
        () => EnvironmentGuard.assertNotProduction(isRelease: true),
        throwsA(isA<ChaosInProductionException>()),
      );
    });

    test('detect returns development by default', () {
      expect(
        EnvironmentGuard.detect(isRelease: false),
        equals(ChaosEnvironment.development),
      );
    });

    test('detect returns production when isRelease = true', () {
      expect(
        EnvironmentGuard.detect(isRelease: true),
        equals(ChaosEnvironment.production),
      );
    });

    test('custom check overrides built-in logic', () {
      EnvironmentGuard.setCustomProductionCheck(() => false);
      expect(
        EnvironmentGuard.detect(isRelease: true),
        equals(ChaosEnvironment.staging),
      );
      EnvironmentGuard.clearCustomCheck();
    });
  });
}
