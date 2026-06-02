import 'dart:math';
import 'package:test/test.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

void main() {
  group('Probability.roll', () {
    test('p = 0.0 → never fires', () {
      var hits = 0;
      for (var i = 0; i < 100000; i++) {
        if (Probability.roll(0.0, Random(i))) hits++;
      }
      expect(hits, equals(0));
    });

    test('p = 1.0 → always fires', () {
      var hits = 0;
      for (var i = 0; i < 100000; i++) {
        if (Probability.roll(1.0, Random(i))) hits++;
      }
      expect(hits, equals(100000));
    });

    test('p = 0.05 → fires ~5 % of the time (within 0.5 %)', () {
      var hits = 0;
      final rng = Random(42);
      const n = 200000;
      for (var i = 0; i < n; i++) {
        if (Probability.roll(0.05, rng)) hits++;
      }
      final rate = hits / n;
      expect(rate, closeTo(0.05, 0.005));
    });

    test('p = 0.20 → fires ~20 % of the time (within 0.5 %)', () {
      var hits = 0;
      final rng = Random(99);
      const n = 200000;
      for (var i = 0; i < n; i++) {
        if (Probability.roll(0.20, rng)) hits++;
      }
      final rate = hits / n;
      expect(rate, closeTo(0.20, 0.005));
    });

    test('p < 0 is treated as 0', () {
      expect(Probability.roll(-0.1, Random()), isFalse);
    });

    test('p > 1 is treated as 1', () {
      expect(Probability.roll(1.5, Random()), isTrue);
    });
  });

  group('Probability.rollSeeded', () {
    test('same seed + index always returns same result', () {
      final r1 = Probability.rollSeeded(0.5, 42, 0);
      final r2 = Probability.rollSeeded(0.5, 42, 0);
      expect(r1, equals(r2));
    });

    test('different indices return different results', () {
      final results = List.generate(
        20,
        (i) => Probability.rollSeeded(0.5, 42, i),
      );
      // At least some should differ
      expect(results.toSet().length, greaterThan(1));
    });
  });

  group('Probability.expectedHits', () {
    test('0.05 × 1000 = 50', () {
      expect(Probability.expectedHits(0.05, 1000), closeTo(50.0, 0.001));
    });
  });

  group('Probability.atLeastOnceProbability', () {
    test('p = 0 → 0', () {
      expect(Probability.atLeastOnceProbability(0.0, 100), equals(0.0));
    });

    test('p = 1 → 1', () {
      expect(Probability.atLeastOnceProbability(1.0, 1), equals(1.0));
    });

    test('p = 0.05, n = 20 → ≈ 64.1%', () {
      expect(
        Probability.atLeastOnceProbability(0.05, 20),
        closeTo(0.641, 0.001),
      );
    });
  });

  group('Probability.impactSummary', () {
    test('formats correctly', () {
      final s = Probability.impactSummary(0.05, 100);
      expect(s, contains('5.0/min'));
      expect(s, contains('300/hr'));
    });
  });
}
