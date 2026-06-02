import 'package:test/test.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';
import 'helpers/mock_helpers.dart';

void main() {
  group('DatabaseChaos.wrap', () {
    test('passes through when config.enabled = false', () async {
      final chaos = DatabaseChaos(config: silentConfig);
      final result = await chaos.wrap(() async => 'real_result');
      expect(result, equals('real_result'));
    });

    test('throws DatabaseKillException when killDatabase = 1.0', () async {
      final chaos = DatabaseChaos(config: alwaysKillDatabaseConfig());
      expect(
        () async => chaos.wrap(() async => 'ignored', label: 'test'),
        throwsA(isA<DatabaseKillException>()),
      );
    });

    test('returns real result when killDatabase = 0.0', () async {
      final chaos = DatabaseChaos(
        config: const ChaosConfig(killDatabase: 0.0, safetyGuard: false),
      );
      final result = await chaos.wrap(() async => 42);
      expect(result, equals(42));
    });

    test('applies delay when slowDatabase = 1.0', () async {
      final chaos = DatabaseChaos(
        config: const ChaosConfig(
          slowDatabase: 1.0,
          databaseDelayMs: 100,
          safetyGuard: false,
          seed: 42,
        ),
      );
      final stopwatch = Stopwatch()..start();
      await chaos.wrap(() async => 'ok', label: 'slow_test');
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(90));
    });

    test('returns null when corruptDatabaseRead = 1.0', () async {
      final chaos = DatabaseChaos(
        config: const ChaosConfig(
          corruptDatabaseRead: 1.0,
          safetyGuard: false,
          seed: 42,
        ),
      );
      final result = await chaos.wrap<String>(() async => 'should be null');
      expect(result, isNull);
    });

    test('emits event when fault fires', () async {
      final events = <ChaosEvent>[];
      final chaos = DatabaseChaos(
        config: const ChaosConfig(killDatabase: 1.0, safetyGuard: false),
      );
      chaos.onEventTriggered = events.add;

      try {
        await chaos.wrap(() async => 'x');
      } on DatabaseKillException {
        // expected
      }

      expect(events, hasLength(1));
      expect(events.first.experimentType, equals('DatabaseChaos'));
    });

    test('shouldTrigger is true when any db param > 0', () {
      expect(
        DatabaseChaos(
          config: const ChaosConfig(killDatabase: 0.01, safetyGuard: false),
        ).shouldTrigger(),
        isTrue,
      );
    });

    test('shouldTrigger is false for default config', () {
      expect(
        DatabaseChaos(config: silentConfig).shouldTrigger(),
        isFalse,
      );
    });
  });

  group('DatabaseKillException', () {
    test('toString includes message', () {
      const e = DatabaseKillException('test error');
      expect(e.toString(), contains('test error'));
    });
  });
}
