/// chaos_monkey_dart — Comprehensive Dart (non-Flutter) example
///
/// This example shows all major features without requiring Flutter or a
/// real HTTP/database backend.  Run with:
///
/// ```bash
/// cd example
/// dart pub get
/// dart run main.dart
/// ```

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

void main() async {
  // ── 1. Enable logging output ──────────────────────────────────────────────
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) {
    // ignore: avoid_print
    print('[${r.level.name.padRight(7)}] ${r.message}');
    if (r.error != null) print('  ↳ error: ${r.error}');
  });

  print('''
╔══════════════════════════════════════════════════════════╗
║       chaos_monkey_dart — Full Feature Demo              ║
╚══════════════════════════════════════════════════════════╝
''');

  // ── 2. Demo 1: Quick-start API ────────────────────────────────────────────
  await _demo1QuickStart();

  // ── 3. Demo 2: Manual config with all experiments ─────────────────────────
  await _demo2AllExperiments();

  // ── 4. Demo 3: DatabaseChaos wrapping ─────────────────────────────────────
  await _demo3DatabaseChaos();

  // ── 5. Demo 4: NetworkChaos manual wrapping ───────────────────────────────
  await _demo4NetworkChaos();

  // ── 6. Demo 5: LatencyChaos on any async call ─────────────────────────────
  await _demo5LatencyChaos();

  // ── 7. Demo 6: ExceptionChaos wrapping ────────────────────────────────────
  await _demo6ExceptionChaos();

  // ── 8. Demo 7: EventCollectorReporter for test assertions ─────────────────
  await _demo7CollectorReporter();

  // ── 9. Demo 8: Presets comparison ─────────────────────────────────────────
  await _demo8Presets();

  print('\n✅  All demos completed successfully.\n');
}

// ── Demo 1 ─────────────────────────────────────────────────────────────────

Future<void> _demo1QuickStart() async {
  _heading('Demo 1: quickStart API');

  await ChaosMonkey.quickStart(
    killDatabase: 0.05,
    slowNetwork: 0.15,
    networkDelayMs: 500,
  );

  final status = ChaosMonkey.status();
  print('  isRunning         : ${status.isRunning}');
  print('  experiments count : ${status.activeExperimentsCount}');

  final report = await ChaosMonkey.stop();
  print('  Session duration  : ${report.totalDuration.inMilliseconds}ms\n');
  ChaosMonkey.reset();
}

// ── Demo 2 ─────────────────────────────────────────────────────────────────

Future<void> _demo2AllExperiments() async {
  _heading('Demo 2: Full ChaosConfig — medium preset');

  final collector = EventCollectorReporter();

  await ChaosMonkey.start(
    config: ChaosConfig.medium().copyWith(
      schedulerIntervalSeconds: 1000, // don't fire scheduler in demo
      safetyGuard: false,
    ),
    reporter: MultiReporter([
      ConsoleReporter(verbose: false),
      collector,
    ]),
  );

  print('  Active config:\n${ChaosMonkey.status().config}');

  // Pause → resume cycle
  ChaosMonkey.pause();
  print('\n  Monkey paused: ${ChaosMonkey.status().isPaused}');
  ChaosMonkey.resume();
  print('  Monkey resumed: ${ChaosMonkey.status().isPaused}');

  final report = await ChaosMonkey.stop();
  print('\n  Report:\n$report\n');
  ChaosMonkey.reset();
}

// ── Demo 3 ─────────────────────────────────────────────────────────────────

Future<void> _demo3DatabaseChaos() async {
  _heading('Demo 3: DatabaseChaos wrapping');

  const config = ChaosConfig(
    killDatabase: 0.50,
    slowDatabase: 0.30,
    databaseDelayMs: 100,
    safetyGuard: false,
    seed: 42,
  );

  final chaos = DatabaseChaos(config: config);
  var killed = 0;
  var slowed = 0;
  var passed = 0;

  for (var i = 0; i < 20; i++) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await chaos.wrap<String>(
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'row_$i';
        },
        label: 'users.get[$i]',
      );
      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds >= 90) {
        slowed++;
      } else {
        passed++;
      }
      // ignore: avoid_print
      print('  [$i] result=$result  (${stopwatch.elapsedMilliseconds}ms)');
    } on DatabaseKillException {
      killed++;
      // ignore: avoid_print
      print('  [$i] 💀 DB killed — handled gracefully');
    }
  }

  print('\n  Summary: killed=$killed  slowed=$slowed  passed=$passed\n');
}

// ── Demo 4 ─────────────────────────────────────────────────────────────────

Future<void> _demo4NetworkChaos() async {
  _heading('Demo 4: NetworkChaos.applyTo manual wrapping');

  const config = ChaosConfig(
    slowNetwork: 0.40,
    networkDelayMs: 200,
    networkDelayJitterMs: 50,
    dropNetwork: 0.20,
    networkErrorCode: 503,
    safetyGuard: false,
    seed: 7,
  );

  final chaos = NetworkChaos(config: config);
  var dropped = 0;
  var slowed = 0;
  var passed = 0;

  for (var i = 0; i < 15; i++) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await chaos.applyTo(
        () async => 'api_response_$i',
        url: 'https://api.example.com/item/$i',
        method: 'GET',
      );
      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds >= 150) {
        slowed++;
        print('  [$i] ⏳ slowed → "$result"  (+${stopwatch.elapsedMilliseconds}ms)');
      } else {
        passed++;
        print('  [$i] ✅ passed → "$result"');
      }
    } on NetworkDropException catch (e) {
      dropped++;
      print('  [$i] 💀 dropped [${e.statusCode}]');
    }
  }

  print('\n  Summary: dropped=$dropped  slowed=$slowed  passed=$passed\n');
}

// ── Demo 5 ─────────────────────────────────────────────────────────────────

Future<void> _demo5LatencyChaos() async {
  _heading('Demo 5: LatencyChaos on any async call');

  const config = ChaosConfig(
    injectLatency: 0.60,
    latencyMinMs: 50,
    latencyMaxMs: 300,
    safetyGuard: false,
    seed: 13,
  );

  final chaos = LatencyChaos(config: config);
  var latencyInjected = 0;
  var passthrough = 0;

  for (var i = 0; i < 10; i++) {
    final stopwatch = Stopwatch()..start();
    await chaos.wrap(
      () async {
        // Simulates any slow async operation (Bluetooth, storage, etc.)
        await Future<void>.delayed(const Duration(milliseconds: 5));
      },
      label: 'bluetooth.scan[$i]',
    );
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 40) {
      latencyInjected++;
      print('  [$i] ⏱️  latency injected  (+${stopwatch.elapsedMilliseconds}ms)');
    } else {
      passthrough++;
      print('  [$i] ✅ passthrough  (${stopwatch.elapsedMilliseconds}ms)');
    }
  }

  print('\n  Summary: latencyInjected=$latencyInjected  passthrough=$passthrough\n');
}

// ── Demo 6 ─────────────────────────────────────────────────────────────────

Future<void> _demo6ExceptionChaos() async {
  _heading('Demo 6: ExceptionChaos wrapping');

  final config = ChaosConfig(
    throwRandomException: 0.50,
    safetyGuard: false,
    seed: 5,
    customExceptions: [
      Exception('Simulated AuthenticationException'),
      Exception('Simulated RateLimitException'),
      Exception('Simulated TimeoutException'),
    ],
  );

  final chaos = ExceptionChaos(config: config);
  var thrown = 0;
  var passed = 0;

  for (var i = 0; i < 12; i++) {
    try {
      final result = await chaos.wrap(
        () async => 'service_result_$i',
        label: 'UserService.getProfile[$i]',
      );
      passed++;
      print('  [$i] ✅ "$result"');
    } on Exception catch (e) {
      thrown++;
      print('  [$i] 💥 caught: ${e.toString().split('\n').first}');
    }
  }

  print('\n  Summary: thrown=$thrown  passed=$passed\n');
}

// ── Demo 7 ─────────────────────────────────────────────────────────────────

Future<void> _demo7CollectorReporter() async {
  _heading('Demo 7: EventCollectorReporter for test assertions');

  final collector = EventCollectorReporter();

  await ChaosMonkey.start(
    config: const ChaosConfig(
      killDatabase: 0.0, // ensure we can start
      slowNetwork: 0.0,
      safetyGuard: false,
    ),
    reporter: collector,
  );

  // Manually fire events for demonstration
  collector.onChaosEvent(ChaosEvent(
    experimentType: 'NetworkChaos',
    triggeredAt: DateTime.now(),
    description: 'Slowed GET /api/users +3200ms',
    durationMs: 3200,
  ));
  collector.onChaosEvent(ChaosEvent(
    experimentType: 'DatabaseChaos',
    triggeredAt: DateTime.now(),
    description: 'DB connection killed',
  ));
  collector.onChaosEvent(ChaosEvent(
    experimentType: 'NetworkChaos',
    triggeredAt: DateTime.now(),
    description: 'Dropped POST /api/orders [503]',
  ));

  await ChaosMonkey.stop();

  print('  Total events    : ${collector.eventCount}');
  print('  NetworkChaos    : ${collector.eventsFor("NetworkChaos").length}');
  print('  DatabaseChaos   : ${collector.eventsFor("DatabaseChaos").length}');
  print('  Final report    : ${collector.finalReport?.totalEventsTriggered ?? 0} events\n');

  ChaosMonkey.reset();
}

// ── Demo 8 ─────────────────────────────────────────────────────────────────

Future<void> _demo8Presets() async {
  _heading('Demo 8: Preset comparison');

  final presets = {
    'light': ChaosConfig.light(),
    'medium': ChaosConfig.medium(),
    'heavy': ChaosConfig.heavy(),
    'nuclear': ChaosConfig.nuclear(),
  };

  print('  ${'Preset'.padRight(10)} ${'Intensity'.padRight(12)} Label');
  print('  ${'─' * 40}');
  for (final entry in presets.entries) {
    final c = entry.value;
    final pct = '${(c.totalChaosIntensity * 100).toStringAsFixed(1)}%'.padRight(10);
    print('  ${entry.key.padRight(10)} $pct  ${c.intensityLabel}');
  }
  print('');
}

// ── Helpers ───────────────────────────────────────────────────────────────

void _heading(String title) {
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  $title');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}
