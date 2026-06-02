# 🐒 chaos_monkey_dart

[![pub version](https://img.shields.io/badge/pub-1.0.0-blue.svg)](https://pub.dev/packages/chaos_monkey_dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2.svg)](https://dart.dev)

> **"If you don't break it first, production will — at the worst possible moment."**

A production-grade **chaos engineering** package for Flutter & Dart.  
Deliberately injects network delays, database failures, file corruption, memory  
pressure, CPU spikes, and random exceptions to surface resilience weaknesses  
before real users encounter them.

Inspired by **Netflix Chaos Monkey** (2011).  
**Staging & testing only.  Never use in production.**

---



<img src="assets/images/chaos_monkey_dart.jpg" width="1268" height="844">


## Table of Contents

- [What is Chaos Engineering?](#what-is-chaos-engineering)
- [Features](#features)
- [Quick Start](#quick-start)
- [Presets](#presets)
- [Experiments](#experiments)
- [Interceptors](#interceptors)
- [Reporters](#reporters)
- [Scheduler](#scheduler)
- [API Reference](#api-reference)
- [Testing Utilities](#testing-utilities)
- [Safety](#safety)
- [Architecture](#architecture)
- [FAQ](#faq)

---

## What is Chaos Engineering?

Netflix invented Chaos Engineering in 2011 to validate that their distributed
systems could survive unexpected failures.  The core idea:

> **Deliberately inject failures in a controlled environment so you find
> weaknesses before your users do.**

`chaos_monkey_dart` brings this battle-tested practice to Flutter & Dart apps.

---

## Features

| Feature | Description |
|---------|-------------|
| 🌐 Network chaos | Delay (with jitter) or drop HTTP requests |
| 🗄️ Database chaos | Kill connections, slow queries, corrupt reads |
| 📁 File chaos | Delete or corrupt files matching glob patterns |
| 🧠 Memory chaos | Simulate heap pressure with large allocations |
| 💻 CPU chaos | Tight-loop spikes that freeze the event loop |
| 💥 Exception chaos | Randomly throw from a configurable exception pool |
| ⏱️ Latency chaos | Generic latency injection for any async call |
| 🛡️ Production guard | Refuses to run in `kReleaseMode` by default |
| 📊 Rich reporting | Console, file (JSON Lines), callback, collector |
| ⏰ Scheduler | Fixed-interval and random-interval autonomous firing |
| 🎛️ Presets | `light`, `medium`, `heavy`, `nuclear` out of the box |
| 🔁 Reproducible | Optional RNG seed for identical test replays |

---

## Quick Start

```dart
import 'package:flutter/foundation.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    await ChaosMonkey.start(
      config: ChaosConfig(
        killDatabase:   0.05,    // 5%  — DB connection dies
        slowNetwork:    0.20,    // 20% — request delayed 10s
        networkDelayMs: 10000,
        dropNetwork:    0.03,    // 3%  — request dropped entirely
        throwRandomException: 0.02,
      ),
      isRelease: kReleaseMode,
    );
  }

  runApp(const MyApp());
}
```

---

## Presets

```dart
// Gentle — safe for daily CI pipelines
await ChaosMonkey.start(config: ChaosConfig.light());

// Moderate — weekly resilience gate checks
await ChaosMonkey.start(config: ChaosConfig.medium());

// Aggressive — dedicated resilience sprints
await ChaosMonkey.start(config: ChaosConfig.heavy());

// Apocalyptic — "Chaos Day" events only 🔥
await ChaosMonkey.start(config: ChaosConfig.nuclear());
```

| Preset | Intensity | Network | DB | Exceptions |
|--------|-----------|---------|-----|-----------|
| light  | ~3%       | 5% slow | 1% kill | 1% |
| medium | ~9%       | 15% slow, 3% drop | 5% kill, 5% slow | 3% |
| heavy  | ~18%      | 30% slow, 10% drop | 10% kill | 8% |
| nuclear | ~45%     | 60% slow, 30% drop | 25% kill | 20% |

---

## Experiments

### NetworkChaos — HTTP delay & drop

```dart
// Automatic (via Dio interceptor — see Interceptors section below)

// Manual wrapping:
final chaos = NetworkChaos(config: config);
try {
  final result = await chaos.applyTo(
    () => http.get(Uri.parse('https://api.example.com/users')),
    url: 'https://api.example.com/users',
    method: 'GET',
  );
} on NetworkDropException catch (e) {
  showErrorBanner('Network unavailable [${e.statusCode}]');
}
```

### DatabaseChaos — kill / slow / corrupt

```dart
final dbChaos = DatabaseChaos(config: config);

Future<User?> getUser(int id) async {
  try {
    return await dbChaos.wrap(
      () => db.findUser(id),
      label: 'UserDao.findUser',
    );
  } on DatabaseKillException {
    return _cache.get(id); // fallback to local cache
  }
}
```

### LatencyChaos — any async call

```dart
final latency = LatencyChaos(config: config);

// Works on BLE, SQLite, file I/O — anything async:
final data = await latency.wrap(
  () => bleDevice.readCharacteristic(),
  label: 'BLE.readCharacteristic',
);
```

### ExceptionChaos — random exceptions

```dart
final exChaos = ExceptionChaos(
  config: ChaosConfig(
    throwRandomException: 0.05,
    customExceptions: [
      AuthException('token expired'),
      RateLimitException('429 too many requests'),
    ],
  ),
);

final profile = await exChaos.wrap(
  () => userService.getProfile(userId),
  label: 'UserService.getProfile',
);
```

---

## Interceptors

### Dio

```dart
// Copy ChaosMonkeyDioInterceptor from example/lib/example_with_dio.dart
// (requires dio: ^5.4.0 in your pubspec)

final dio = Dio();
if (!kReleaseMode) {
  dio.interceptors.add(
    ChaosMonkeyDioInterceptor(
      config: ChaosConfig(
        slowNetwork: 0.20,
        networkDelayMs: 10000,
        dropNetwork: 0.05,
      ),
    ),
  );
}
```

### http package

```dart
// Copy ChaosAwareHttpClient from example/lib/example_with_http.dart
// (requires http: ^1.2.0 in your pubspec)

final client = ChaosAwareHttpClient(
  config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.03),
);
final response = await client.get(Uri.parse('https://api.example.com'));
```

---

## Reporters

```dart
// Console (default) — coloured ASCII art
await ChaosMonkey.start(config: config, reporter: ConsoleReporter());

// File — JSON Lines
await ChaosMonkey.start(
  config: config,
  reporter: FileReporter(logPath: '/tmp/chaos_session.json'),
);

// Callback — custom observability pipeline
await ChaosMonkey.start(
  config: config,
  reporter: CallbackReporter(
    onEvent: (e) => analytics.track('chaos_event', e.metadata),
    onStopped: (r) => print('Session: ${r.totalEventsTriggered} events'),
  ),
);

// Collector — for test assertions
final collector = EventCollectorReporter();
await ChaosMonkey.start(config: config, reporter: collector);
// ... run test
await ChaosMonkey.stop();
expect(collector.eventsFor('NetworkChaos'), hasLength(greaterThan(0)));

// Multi — fan out to several reporters
await ChaosMonkey.start(
  config: config,
  reporter: MultiReporter([ConsoleReporter(), collector]),
);
```

---

## Scheduler

```dart
// Fixed interval (default — fires every 60s)
ChaosConfig(schedulerIntervalSeconds: 60)

// Random interval (more realistic)
final scheduler = RandomScheduler(
  experiments: myExperiments,
  minIntervalSeconds: 10,
  maxIntervalSeconds: 90,
  onEvent: handleEvent,
  isPausedCallback: () => ChaosMonkey.status().isPaused,
);
```

---

## API Reference

### ChaosMonkey static methods

| Method | Description |
|--------|-------------|
| `start({config, reporter, isRelease})` | Starts chaos with the given config |
| `quickStart({killDatabase, slowNetwork, ...})` | Convenience named-param start |
| `stop()` | Stops all experiments, returns `ChaosReport` |
| `pause()` | Suspends chaos without stopping the scheduler |
| `resume()` | Resumes after pause |
| `status()` | Returns lightweight `ChaosStatus` snapshot |
| `updateConfig(newConfig)` | Hot-swaps config while running |
| `reset()` | Resets singleton — **tests only** |

### Key config parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `slowNetwork` | `0.0` | Probability of request delay |
| `networkDelayMs` | `5000` | Delay magnitude in ms |
| `dropNetwork` | `0.0` | Probability of request drop |
| `killDatabase` | `0.0` | Probability of DB connection kill |
| `slowDatabase` | `0.0` | Probability of slow query |
| `throwRandomException` | `0.0` | Probability of random exception |
| `injectLatency` | `0.0` | Probability of generic latency |
| `enabled` | `true` | Master on/off switch |
| `safetyGuard` | `true` | Block production environments |
| `seed` | `null` | RNG seed for reproducibility |

Full parameter table: [doc/configuration_guide.md](doc/configuration_guide.md)

---

## Testing Utilities

```dart
import 'test/helpers/mock_helpers.dart';

// Always-trigger configs for deterministic tests:
final chaos = DatabaseChaos(config: alwaysKillDatabaseConfig());
expect(
  () => chaos.wrap(() async => 'result'),
  throwsA(isA<DatabaseKillException>()),
);

// Collect events during a test:
final events = await withChaosCollector(
  config: ChaosConfig(throwRandomException: 1.0, safetyGuard: false),
  body: () async => myService.doWork(),
);
expect(events.where((e) => e.experimentType == 'ExceptionChaos'), isNotEmpty);
```

---

## Safety

`chaos_monkey_dart` refuses to run in production by default.

```dart
// ✅ Safe — guard is active, release mode detected → throws
await ChaosMonkey.start(
  config: ChaosConfig(killDatabase: 0.05),
  isRelease: kReleaseMode, // kReleaseMode = true → ChaosInProductionException
);

// ✅ Safe — wrapped with debug check
if (kDebugMode) {
  await ChaosMonkey.start(config: config);
}

// ⚠️ Override — only if you have a custom staging-in-release setup
EnvironmentGuard.setCustomProductionCheck(() => myEnv.isProduction);
```

Full safety guide: [doc/safety_guide.md](doc/safety_guide.md)

---

## Architecture

```
ChaosMonkey (controller)
    │
    ├── ChaosConfig (immutable settings)
    │
    ├── Experiments
    │   ├── NetworkChaos    ← HTTP delay/drop
    │   ├── DatabaseChaos   ← DB kill/slow/corrupt
    │   ├── FileChaos       ← File delete/corrupt
    │   ├── MemoryChaos     ← Heap pressure
    │   ├── CpuChaos        ← CPU spike
    │   ├── ExceptionChaos  ← Random throws
    │   └── LatencyChaos    ← Generic async delay
    │
    ├── Interceptors
    │   ├── ChaosDioInterceptor   ← Dio pipeline
    │   ├── ChaosHttpInterceptor  ← http package
    │   └── ChaosHttpClient       ← Drop-in http.BaseClient
    │
    ├── Reporters
    │   ├── ConsoleReporter       ← ANSI console
    │   ├── FileReporter          ← JSON Lines / text
    │   ├── CallbackReporter      ← User hooks
    │   ├── EventCollectorReporter← In-memory (tests)
    │   ├── MultiReporter         ← Fan-out
    │   └── SilentReporter        ← No-op
    │
    ├── Scheduler
    │   ├── ChaosScheduler        ← Fixed interval
    │   └── RandomScheduler       ← Random interval
    │
    └── Utils
        ├── Probability           ← roll / statistics
        ├── EnvironmentGuard      ← Production detection
        └── ChaosLogger           ← Structured logging
```

---

## FAQ

**Q: Will this affect my release build?**  
A: No. With `safetyGuard: true` (default), the package throws if it detects `kReleaseMode = true`.  Wrap with `if (kDebugMode)` for belt-and-braces safety.

**Q: Can I use this with Riverpod / Bloc / GetX?**  
A: Yes — `ChaosMonkey` is framework-agnostic.  Wrap your repository methods with the experiment classes regardless of state management choice.

**Q: Does it work on web?**  
A: Network and exception chaos work everywhere.  File, memory, and CPU chaos use `dart:io` and require native platforms.

**Q: How do I get reproducible chaos in CI?**  
A: Pass `seed: 42` (or any fixed integer) to `ChaosConfig`.  Every call with the same seed produces identical outcomes.

**Q: How do I disable chaos without removing code?**  
A: Set `enabled: false` in `ChaosConfig`.  All experiments become silent no-ops.

---

## License

MIT — see [LICENSE](LICENSE).

---

> *"chaos_monkey_dart doesn't break your app — it reveals what was already broken."*
