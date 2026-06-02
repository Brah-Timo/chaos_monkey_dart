# Configuration Guide

`ChaosConfig` is an immutable value object.  Every field has a safe
default of `0.0` / `false` — the package does **nothing** unless you
raise at least one probability above zero.

---

## Full field reference

### Network

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `slowNetwork` | `double` | `0.0` | Probability an intercepted request is delayed |
| `networkDelayMs` | `int` | `5000` | Base delay in milliseconds |
| `networkDelayJitterMs` | `int` | `2000` | ± jitter added to base delay |
| `dropNetwork` | `double` | `0.0` | Probability a request is dropped entirely |
| `networkErrorCode` | `int` | `503` | HTTP status code used for dropped requests |
| `networkTimeoutMs` | `int` | `0` | Extra socket-timeout simulation (0 = disabled) |

### Database

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `killDatabase` | `double` | `0.0` | Probability `DatabaseChaos.wrap()` throws |
| `slowDatabase` | `double` | `0.0` | Probability `DatabaseChaos.wrap()` is delayed |
| `databaseDelayMs` | `int` | `3000` | Delay added for slow queries |
| `corruptDatabaseRead` | `double` | `0.0` | Probability `DatabaseChaos.wrap()` returns `null` |

### File System

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `deleteRandomFile` | `double` | `0.0` | Probability a matching file is deleted |
| `corruptRandomFile` | `double` | `0.0` | Probability a matching file is overwritten with garbage |
| `targetFilePatterns` | `List<String>` | `[]` | Glob patterns scoping file chaos (empty = disabled) |

### Memory

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `memoryPressure` | `double` | `0.0` | Probability of a memory-pressure event |
| `memoryAllocationMb` | `int` | `50` | Megabytes to allocate (max 512) |

### CPU

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `cpuSpike` | `double` | `0.0` | Probability of a CPU-spike event |
| `cpuSpikeDurationMs` | `int` | `2000` | Duration of the spike |
| `cpuSpikeIterations` | `int` | `5000000` | Tight-loop iterations per spike |

### Exceptions

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `throwRandomException` | `double` | `0.0` | Probability an exception is thrown at a wrapped site |
| `customExceptions` | `List<Exception>` | `[]` | Pool of exceptions to sample from |

### Latency

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `injectLatency` | `double` | `0.0` | Probability a `LatencyChaos.wrap()` call is delayed |
| `latencyMinMs` | `int` | `100` | Minimum delay |
| `latencyMaxMs` | `int` | `3000` | Maximum delay |

### Global

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | `bool` | `true` | Master enable switch |
| `safetyGuard` | `bool` | `true` | Block chaos in release mode |
| `schedulerIntervalSeconds` | `int` | `60` | Seconds between scheduler ticks |
| `maxConcurrentExperiments` | `int` | `1` | Max simultaneously-running experiments |
| `seed` | `int?` | `null` | RNG seed for reproducible scenarios |
| `verbose` | `bool` | `true` | Detailed per-event logging |
| `tags` | `List<String>` | `[]` | Tags attached to every `ChaosEvent` |

---

## Built-in presets

### `ChaosConfig.light()` — ~3% total intensity
Suitable for **daily CI pipelines**.  Only network and minor exceptions.

```dart
ChaosConfig(
  slowNetwork: 0.05,
  networkDelayMs: 3000,
  killDatabase: 0.01,
  throwRandomException: 0.01,
  injectLatency: 0.02,
)
```

### `ChaosConfig.medium()` — ~9% total intensity
Suitable for **weekly resilience gates**.

```dart
ChaosConfig(
  slowNetwork: 0.15,
  networkDelayMs: 5000,
  dropNetwork: 0.03,
  killDatabase: 0.05,
  slowDatabase: 0.05,
  databaseDelayMs: 2000,
  throwRandomException: 0.03,
  injectLatency: 0.05,
)
```

### `ChaosConfig.heavy()` — ~18% total intensity
Suitable for **dedicated resilience sprints**.

### `ChaosConfig.nuclear()` — ~45% total intensity
For **Chaos Day events** only.  Never run in a production-adjacent
environment.

---

## `copyWith` — incremental overrides

```dart
final tuned = ChaosConfig.medium().copyWith(
  slowNetwork: 0.40,   // crank up network delay only
  seed: 42,            // make it reproducible
);
```

---

## Computed properties

```dart
config.totalChaosIntensity  // 0.0–1.0 normalised mean
config.intensityLabel       // "SILENT" | "LIGHT" | "MEDIUM" | "HEAVY" | "NUCLEAR"
config.hasActiveChaos       // true if any probability > 0
```

---

## Reproducible tests with `seed`

```dart
final config = ChaosConfig(
  slowNetwork: 0.30,
  seed: 12345,  // same sequence every run
);
```

With a fixed seed every `Probability.roll()` call returns the same
sequence, making flaky test investigations deterministic.
