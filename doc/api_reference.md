# Public API Reference

Full listing of every exported class, factory, method, and property.

---

## `ChaosMonkey` (static facade)

| Method / Property | Signature | Description |
|-------------------|-----------|-------------|
| `start` | `static Future<void> start({required ChaosConfig, ChaosReporter?, bool isRelease})` | Start chaos |
| `quickStart` | `static Future<void> quickStart({double killDatabase, ...})` | Start with named params |
| `stop` | `static Future<ChaosReport> stop()` | Stop and return report |
| `pause` | `static void pause()` | Suppress new faults |
| `resume` | `static void resume()` | Re-enable after pause |
| `status` | `static ChaosStatus status()` | Live status snapshot |
| `updateConfig` | `static void updateConfig(ChaosConfig)` | Hot-swap config |
| `reset` | `static void reset()` | Reset singleton (tests only) |
| `instance` | `static ChaosMonkey get instance` | The singleton |
| `config` | `ChaosConfig get config` | Current config |
| `isRunning` | `bool get isRunning` | |
| `isPaused` | `bool get isPaused` | |
| `eventHistory` | `List<ChaosEvent> get eventHistory` | Immutable snapshot |
| `totalEventsTriggered` | `int get totalEventsTriggered` | |

---

## `ChaosConfig`

### Constructors / Factories

| Name | Description |
|------|-------------|
| `const ChaosConfig({...})` | Full constructor, all fields optional |
| `ChaosConfig.light()` | ~3% intensity preset |
| `ChaosConfig.medium()` | ~9% intensity preset |
| `ChaosConfig.heavy()` | ~18% intensity preset |
| `ChaosConfig.nuclear()` | ~45% intensity preset |

### Key methods

| Method | Returns | Description |
|--------|---------|-------------|
| `copyWith({...})` | `ChaosConfig` | Override selected fields |
| `totalChaosIntensity` | `double` | Mean of all probabilities |
| `intensityLabel` | `String` | SILENT / LIGHT / MEDIUM / HEAVY / NUCLEAR |
| `hasActiveChaos` | `bool` | Any probability > 0 |

---

## Experiments

### `NetworkChaos`
| Method | Returns | Description |
|--------|---------|-------------|
| `applyToRequest(url, method)` | `Future<NetworkOutcome>` | Evaluate and apply chaos |
| `applyTo<T>(call, {url, method})` | `Future<T>` | Wrap an HTTP call |
| `pause()` / `resume()` | `void` | Instance-level pause |

### `DatabaseChaos`
| Method | Returns | Description |
|--------|---------|-------------|
| `wrap<T>(operation, {label})` | `Future<T?>` | Wrap a DB call |

### `FileChaos`
| Method | Returns | Description |
|--------|---------|-------------|
| `apply(Directory)` | `Future<List<FileChaosResult>>` | Apply to a directory |

### `MemoryChaos`
| Method | Returns | Description |
|--------|---------|-------------|
| `pressurize({holdDurationMs})` | `Future<bool>` | Manual trigger |
| `heldAllocationSize` | `int` | Current held MB chunks |

### `CpuChaos`
| Method | Returns | Description |
|--------|---------|-------------|
| `spike()` | `Future<bool>` | Manual trigger |

### `ExceptionChaos`
| Method | Returns | Description |
|--------|---------|-------------|
| `wrap<T>(operation, {label})` | `Future<T>` | May throw before executing |

### `LatencyChaos`
| Method | Returns | Description |
|--------|---------|-------------|
| `wrap<T>(operation, {label})` | `Future<T>` | Wrap any async call |
| `maybeDelay({label})` | `Future<int?>` | Delay without a call |

---

## Interceptors

### `ChaosDioInterceptor`
| Method | Returns |
|--------|---------|
| `processRequest(url, method)` | `Future<DioRequestDecision>` |

### `DioChaosBridge`
| Method | Returns |
|--------|---------|
| `handleRequest(url, method)` | `Future<DioRequestDecision>` |

### `ChaosHttpInterceptor`
| Method | Returns |
|--------|---------|
| `process({url, method})` | `Future<HttpChaosDecision>` |

### `ChaosHttpClient`
| Method | Returns |
|--------|---------|
| `send({url, method, inner})` | `Future<ChaosHttpResponse>` |
| `close()` | `void` |

---

## Reporters

| Class | Notes |
|-------|-------|
| `ConsoleReporter` | Default; ANSI-coloured console output |
| `FileReporter` | JSON Lines or plain text file |
| `CallbackReporter` | Forwards to user callbacks |
| `SilentReporter` | No-op |
| `MultiReporter` | Fan-out to N reporters |
| `EventCollectorReporter` | In-memory list, for tests |

---

## Schedulers

| Class | Key params |
|-------|-----------|
| `ChaosScheduler` | `experiments`, `intervalSeconds`, `maxConcurrent` |
| `RandomScheduler` | `experiments`, `minIntervalSeconds`, `maxIntervalSeconds` |

---

## Utilities

### `Probability`

| Method | Returns |
|--------|---------|
| `roll(p, random)` | `bool` |
| `rollSeeded(p, seed, callIndex)` | `bool` |
| `expectedHits(p, trials)` | `double` |
| `atLeastOnceProbability(p, trials)` | `double` |
| `exactlyKProbability(p, trials, k)` | `double` |
| `confidenceInterval95(p, trials)` | `double` |
| `impactSummary(p, requestsPerMinute)` | `String` |

### `EnvironmentGuard`

| Method | Returns |
|--------|---------|
| `detect({isRelease})` | `ChaosEnvironment` |
| `isProduction({isRelease})` | `bool` |
| `assertNotProduction({isRelease})` | `void` — throws in production |
| `setCustomProductionCheck(check)` | `void` |
| `clearCustomCheck()` | `void` |
| `describe({isRelease})` | `String` |

### `ChaosLogger`

| Method | Level |
|--------|-------|
| `trace(message)` | FINE (verbose only) |
| `info(message)` | INFO |
| `warning(message)` | WARNING |
| `error(message, {error, stackTrace})` | SEVERE |
| `chaos(message)` | SHOUT |
| `enableDefaultConsoleOutput()` | Sets up stdout handler |

---

## Exceptions

| Class | Thrown by |
|-------|----------|
| `NetworkDropException` | `NetworkChaos.applyTo` |
| `DatabaseKillException` | `DatabaseChaos.wrap` |
| `DatabaseTimeoutException` | Reserved |
| `ChaosException` | `ExceptionChaos.wrap` (built-in pool) |
| `ChaosInProductionException` | `EnvironmentGuard.assertNotProduction` |

All experiment exceptions extend `ChaosExperimentException`:

```dart
try {
  await dbChaos.wrap(myQuery);
} on ChaosExperimentException catch (e) {
  // handles all chaos-related exceptions
  log('Chaos fault: $e');
}
```
