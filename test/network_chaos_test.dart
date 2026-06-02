import 'package:test/test.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';
import 'helpers/mock_helpers.dart';

void main() {
  group('NetworkChaos.applyToRequest', () {
    test('returns passthrough when config.enabled = false', () async {
      final chaos = NetworkChaos(config: silentConfig);
      final outcome = await chaos.applyToRequest('https://api.test/x', 'GET');
      expect(outcome.isPassthrough, isTrue);
    });

    test('returns passthrough when all network probs = 0.0', () async {
      final chaos = NetworkChaos(
        config: const ChaosConfig(
          slowNetwork: 0.0,
          dropNetwork: 0.0,
          safetyGuard: false,
        ),
      );
      final outcome = await chaos.applyToRequest('https://api.test/x', 'GET');
      expect(outcome.isPassthrough, isTrue);
    });

    test('returns dropped when dropNetwork = 1.0', () async {
      final chaos = NetworkChaos(config: alwaysDropNetworkConfig());
      final outcome = await chaos.applyToRequest('https://api.test/x', 'GET');
      expect(outcome.isDropped, isTrue);
      expect(outcome.errorCode, equals(503));
    });

    test('returns slowed when slowNetwork = 1.0 and dropNetwork = 0.0',
        () async {
      final chaos = NetworkChaos(
        config: const ChaosConfig(
          slowNetwork: 1.0,
          networkDelayMs: 50,
          networkDelayJitterMs: 0,
          dropNetwork: 0.0,
          safetyGuard: false,
          seed: 42,
        ),
      );
      final stopwatch = Stopwatch()..start();
      final outcome =
          await chaos.applyToRequest('https://api.test/x', 'GET');
      stopwatch.stop();

      expect(outcome.isSlowed, isTrue);
      expect(outcome.delayMs, greaterThanOrEqualTo(50));
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(40));
    });

    test('emits event on drop', () async {
      final events = <ChaosEvent>[];
      final chaos = NetworkChaos(config: alwaysDropNetworkConfig());
      chaos.onEventTriggered = events.add;

      await chaos.applyToRequest('https://test.com', 'POST');

      expect(events, hasLength(1));
      expect(events.first.experimentType, equals('NetworkChaos'));
      expect(events.first.metadata['fault'], equals('drop'));
    });

    test('emits event on slow', () async {
      final events = <ChaosEvent>[];
      final chaos = NetworkChaos(
        config: const ChaosConfig(
          slowNetwork: 1.0,
          networkDelayMs: 50,
          networkDelayJitterMs: 0,
          safetyGuard: false,
          seed: 42,
        ),
      );
      chaos.onEventTriggered = events.add;
      await chaos.applyToRequest('https://test.com', 'GET');

      expect(events, hasLength(1));
      expect(events.first.metadata['fault'], equals('slow'));
    });
  });

  group('NetworkChaos.applyTo', () {
    test('throws NetworkDropException when dropped', () async {
      final chaos = NetworkChaos(config: alwaysDropNetworkConfig());
      expect(
        () async => chaos.applyTo(
          () async => 'response',
          url: 'https://api.test/drop',
          method: 'GET',
        ),
        throwsA(isA<NetworkDropException>()),
      );
    });

    test('returns call result when passthrough', () async {
      final chaos = NetworkChaos(config: silentConfig);
      final result = await chaos.applyTo(
        () async => 'hello',
        url: 'https://api.test/ok',
        method: 'GET',
      );
      expect(result, equals('hello'));
    });
  });

  group('NetworkDropException', () {
    test('toString includes status code', () {
      const e = NetworkDropException('dropped', statusCode: 503);
      expect(e.toString(), contains('503'));
    });
  });
}
