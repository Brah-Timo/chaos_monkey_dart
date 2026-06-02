# Configuration Guide

## Complete Parameter Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `slowNetwork` | `double` | `0.0` | Probability (0–1) that an HTTP request is delayed |
| `networkDelayMs` | `int` | `5000` | Base delay in ms |
| `networkDelayJitterMs` | `int` | `2000` | ±Jitter added to base delay |
| `dropNetwork` | `double` | `0.0` | Probability that request is dropped entirely |
| `networkErrorCode` | `int` | `503` | HTTP code returned on drop |
| `networkTimeoutMs` | `int` | `0` | Extra timeout simulation (0 = disabled) |
| `killDatabase` | `double` | `0.0` | Probability DB connection is killed |
| `slowDatabase` | `double` | `0.0` | Probability DB query is slowed |
| `databaseDelayMs` | `int` | `3000` | DB slow query delay in ms |
| `corruptDatabaseRead` | `double` | `0.0` | Probability read returns null |
| `deleteRandomFile` | `double` | `0.0` | Probability a matching file is deleted |
| `corruptRandomFile` | `double` | `0.0` | Probability a matching file is corrupted |
| `targetFilePatterns` | `List<String>` | `[]` | Glob patterns for eligible files |
| `memoryPressure` | `double` | `0.0` | Probability memory-pressure event fires |
| `memoryAllocationMb` | `int` | `50` | MB to allocate during pressure (max 512) |
| `cpuSpike` | `double` | `0.0` | Probability CPU spike fires |
| `cpuSpikeDurationMs` | `int` | `2000` | Duration of CPU spike in ms |
| `cpuSpikeIterations` | `int` | `5000000` | Tight-loop iterations per spike |
| `throwRandomException` | `double` | `0.0` | Probability random exception is thrown |
| `customExceptions` | `List<Exception>` | `[]` | Pool to sample from (falls back to built-ins) |
| `injectLatency` | `double` | `0.0` | Probability latency is injected into wrapped call |
| `latencyMinMs` | `int` | `100` | Minimum injected latency |
| `latencyMaxMs` | `int` | `3000` | Maximum injected latency |
| `enabled` | `bool` | `true` | Master on/off switch |
| `safetyGuard` | `bool` | `true` | Block production environments |
| `schedulerIntervalSeconds` | `int` | `60` | Scheduler tick interval |
| `maxConcurrentExperiments` | `int` | `1` | Max parallel experiments |
| `reporter` | `ReporterConfig` | Console | Reporter to use |
| `seed` | `int?` | `null` | RNG seed for reproducibility |
| `verbose` | `bool` | `true` | Emit per-event log output |
| `tags` | `List<String>` | `[]` | Labels attached to all events |

## Choosing Probabilities

| Traffic rate | Probability | Expected hits |
|---|---|---|
| 100 req/min | 0.05 | 5 / min |
| 100 req/min | 0.20 | 20 / min |
| 1000 req/min | 0.01 | 10 / min |

Use `Probability.impactSummary(p, requestsPerMinute)` to compute before deploying.

## The `totalChaosIntensity` Score

```
intensity = (sum of all probability fields) / 11
```

| Score | Label | Use |
|---|---|---|
| 0 | SILENT | Config has no effect |
| 0–5% | LIGHT | Safe for daily CI |
| 5–15% | MEDIUM | Weekly resilience gates |
| 15–30% | HEAVY | Dedicated sprint |
| >30% | NUCLEAR 🔥 | Chaos Days only |
