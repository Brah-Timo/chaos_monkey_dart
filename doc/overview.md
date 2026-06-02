# chaos_monkey_dart — Overview

> **⚠️ STAGING / TESTING ONLY.  Never use in production.**

`chaos_monkey_dart` is a production-grade chaos engineering library for
Flutter and Dart applications.  Inspired by Netflix Chaos Monkey, it
deliberately injects faults — network delays, database failures, file
corruption, memory pressure, CPU spikes, random exceptions — so you can
discover resilience gaps **before** real users encounter them.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Your Application                    │
│                                                         │
│  ┌───────────┐  ┌──────────────┐  ┌───────────────┐   │
│  │ HTTP layer│  │  DB layer    │  │  App services │   │
│  │ (Dio/http)│  │ (sqflite…)   │  │  (any async)  │   │
│  └─────┬─────┘  └──────┬───────┘  └───────┬───────┘   │
│        │               │                  │            │
│  ┌─────▼───────────────▼──────────────────▼─────────┐  │
│  │              ChaosMonkey Controller               │  │
│  │  start() · stop() · pause() · resume() · status() │  │
│  └──────────────────────┬────────────────────────────┘  │
│                         │                              │
│     ┌───────────────────┼──────────────────────┐      │
│     │                   │                      │      │
│  ┌──▼─────────┐  ┌──────▼──────┐  ┌───────────▼──┐   │
│  │ Interceptors│  │ Experiments │  │  Scheduler   │   │
│  │ Dio / http  │  │ 7 types     │  │ periodic/rnd │   │
│  └─────────────┘  └─────────────┘  └──────────────┘   │
│                         │                              │
│                   ┌─────▼──────┐                       │
│                   │  Reporters │                       │
│                   │ console/   │                       │
│                   │ file/      │                       │
│                   │ callback   │                       │
│                   └────────────┘                       │
└─────────────────────────────────────────────────────────┘
```

---

## Experiment types

| Class | Config field | Fault injected |
|-------|-------------|----------------|
| `NetworkChaos` | `slowNetwork` / `dropNetwork` | HTTP delay or drop |
| `DatabaseChaos` | `killDatabase` / `slowDatabase` / `corruptDatabaseRead` | DB kill / slow / corrupt |
| `FileChaos` | `deleteRandomFile` / `corruptRandomFile` | File delete / corrupt |
| `MemoryChaos` | `memoryPressure` | Large heap allocation |
| `CpuChaos` | `cpuSpike` | Tight compute loop |
| `ExceptionChaos` | `throwRandomException` | Random exception thrown |
| `LatencyChaos` | `injectLatency` | Any async call delayed |

---

## Quick start

```dart
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

void main() async {
  if (kDebugMode) {
    await ChaosMonkey.start(
      config: ChaosConfig(
        slowNetwork: 0.20,      // 20% of requests delayed
        networkDelayMs: 8000,   // 8-second base delay
        killDatabase: 0.05,     // 5% DB connection kills
        throwRandomException: 0.02,
      ),
      isRelease: kReleaseMode,
    );
  }

  runApp(const MyApp());
}
```

---

## Navigation

| Document | What it covers |
|----------|---------------|
| [getting_started.md](getting_started.md) | Installation, setup, 8 usage examples |
| [configuration.md](configuration.md) | `ChaosConfig` all fields + presets |
| [experiments_reference.md](experiments_reference.md) | Each experiment in depth |
| [interceptors.md](interceptors.md) | Dio and http interceptor integration |
| [reporters.md](reporters.md) | Console, file, and callback reporters |
| [scheduler.md](scheduler.md) | `ChaosScheduler` and `RandomScheduler` |
| [safety_guide.md](safety_guide.md) | Production guards and best practices |
| [api_reference.md](api_reference.md) | Full public API listing |
