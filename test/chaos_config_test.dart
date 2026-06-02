import 'package:test/test.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

void main() {
  group('ChaosConfig defaults', () {
    test('all probabilities default to 0.0', () {
      const c = ChaosConfig();
      expect(c.slowNetwork, equals(0.0));
      expect(c.dropNetwork, equals(0.0));
      expect(c.killDatabase, equals(0.0));
      expect(c.slowDatabase, equals(0.0));
      expect(c.throwRandomException, equals(0.0));
      expect(c.injectLatency, equals(0.0));
    });

    test('enabled defaults to true', () {
      expect(const ChaosConfig().enabled, isTrue);
    });

    test('safetyGuard defaults to true', () {
      expect(const ChaosConfig().safetyGuard, isTrue);
    });

    test('hasActiveChaos is false for default config', () {
      expect(const ChaosConfig().hasActiveChaos, isFalse);
    });

    test('totalChaosIntensity is 0.0 for default config', () {
      expect(const ChaosConfig().totalChaosIntensity, equals(0.0));
    });

    test('intensityLabel is SILENT for default config', () {
      expect(const ChaosConfig().intensityLabel, equals('SILENT'));
    });
  });

  group('ChaosConfig validation asserts', () {
    test('slowNetwork > 1.0 throws AssertionError', () {
      expect(
        () => ChaosConfig(slowNetwork: 1.5),
        throwsA(isA<AssertionError>()),
      );
    });

    test('killDatabase < 0.0 throws AssertionError', () {
      expect(
        () => ChaosConfig(killDatabase: -0.1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('memoryAllocationMb > 512 throws AssertionError', () {
      expect(
        () => ChaosConfig(memoryPressure: 0.1, memoryAllocationMb: 600),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ChaosConfig.copyWith', () {
    test('modifies only specified fields', () {
      const original = ChaosConfig(slowNetwork: 0.20, killDatabase: 0.05);
      final modified = original.copyWith(slowNetwork: 0.40);
      expect(modified.slowNetwork, equals(0.40));
      expect(modified.killDatabase, equals(0.05)); // unchanged
      expect(modified.enabled, isTrue); // unchanged default
    });

    test('seed is preserved', () {
      const c = ChaosConfig(seed: 99);
      final copy = c.copyWith(slowNetwork: 0.1);
      expect(copy.seed, equals(99));
    });
  });

  group('ChaosConfig factory presets', () {
    test('light has valid probabilities', () {
      final c = ChaosConfig.light();
      expect(c.slowNetwork, inInclusiveRange(0.0, 1.0));
      expect(c.totalChaosIntensity, lessThan(0.10));
      expect(c.intensityLabel, equals('LIGHT'));
    });

    test('medium has moderate intensity', () {
      final c = ChaosConfig.medium();
      expect(c.totalChaosIntensity, greaterThan(0.05));
      expect(c.totalChaosIntensity, lessThan(0.20));
    });

    test('heavy has higher intensity than medium', () {
      final heavy = ChaosConfig.heavy();
      final medium = ChaosConfig.medium();
      expect(heavy.totalChaosIntensity, greaterThan(medium.totalChaosIntensity));
    });

    test('nuclear has maximum intensity', () {
      final c = ChaosConfig.nuclear();
      expect(c.totalChaosIntensity, greaterThan(0.30));
    });

    test('all presets pass assert validation', () {
      expect(() => ChaosConfig.light(), returnsNormally);
      expect(() => ChaosConfig.medium(), returnsNormally);
      expect(() => ChaosConfig.heavy(), returnsNormally);
      expect(() => ChaosConfig.nuclear(), returnsNormally);
    });
  });

  group('ChaosConfig.totalChaosIntensity', () {
    test('single field contributes ~1/11 of total', () {
      const c = ChaosConfig(slowNetwork: 1.0);
      expect(c.totalChaosIntensity, closeTo(1 / 11, 0.001));
    });

    test('all fields at 1.0 → intensity = 1.0', () {
      const c = ChaosConfig(
        slowNetwork: 1.0,
        dropNetwork: 1.0,
        killDatabase: 1.0,
        slowDatabase: 1.0,
        corruptDatabaseRead: 1.0,
        deleteRandomFile: 1.0,
        corruptRandomFile: 1.0,
        memoryPressure: 1.0,
        cpuSpike: 1.0,
        throwRandomException: 1.0,
        injectLatency: 1.0,
      );
      expect(c.totalChaosIntensity, closeTo(1.0, 0.001));
    });
  });

  group('ChaosConfig toString', () {
    test('contains all section headers', () {
      final s = ChaosConfig.medium().toString();
      expect(s, contains('Network'));
      expect(s, contains('Database'));
      expect(s, contains('Memory'));
      expect(s, contains('CPU'));
      expect(s, contains('intensity'));
    });
  });
}
