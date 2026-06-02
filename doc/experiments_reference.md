# Experiments Reference

Each experiment extends `BaseExperiment` and can be triggered in two ways:

1. **Inline / manual** — call the experiment's API method directly at a call site.
2. **Scheduler-driven** — `ChaosScheduler` calls `execute()` periodically.

---

## NetworkChaos

Injects latency and connection drops into HTTP requests.

### Fault types

| Priority | Config param | Effect |
|----------|-------------|--------|
| 1st | `dropNetwork` | Throws `NetworkDropException` |
| 2nd | `slowNetwork` | Adds `networkDelayMs ± jitter` sleep |

### Manual usage

```dart
final networkChaos = NetworkChaos(config: config);

// Wrap any HTTP call:
final result = await networkChaos.applyTo(
  () => httpClient.get(Uri.parse('https://api.example.com/users')),
  url: 'https://api.example.com/users',
  method: 'GET',
);

// Or just check what would happen:
final outcome = await networkChaos.applyToRequest(url, method);
if (outcome.isDropped) { /* handle drop */ }
if (outcome.isSlowed)  { /* delay already applied */ }
```

### Exceptions

- `NetworkDropException(message, {required statusCode})` — thrown when
  `dropNetwork` fires.

---

## DatabaseChaos

Wraps database calls and injects kill / slow / corrupt faults.

### Fault order: Kill > Slow > Corrupt

```dart
final dbChaos = DatabaseChaos(config: config);

final result = await dbChaos.wrap<List<User>>(
  () => db.query('SELECT * FROM users'),
  label: 'users.getAll',
);
// result may be:
// • null           — corrupt read
// • delayed result — slow query
// • throws         — killed connection
```

### Exceptions

- `DatabaseKillException(message)` — thrown when `killDatabase` fires.
- `DatabaseTimeoutException(message)` — reserved for future use.

---

## FileChaos

Deletes or corrupts files in a given directory.

**Safety**: `targetFilePatterns` must be non-empty for any fault to fire.
Use patterns like `['*.cache', '*.tmp', 'draft_*']`.

```dart
final fileChaos = FileChaos(config: ChaosConfig(
  deleteRandomFile: 0.10,
  corruptRandomFile: 0.05,
  targetFilePatterns: ['*.cache', '*.tmp'],
));

final results = await fileChaos.apply(cacheDirectory);
for (final r in results) {
  print('${r.action.name}: ${r.path}');
}
```

### Return type: `List<FileChaosResult>`

Each `FileChaosResult` has:
- `path` — absolute file path
- `action` — `FileChaosAction.deleted` or `FileChaosAction.corrupted`

---

## MemoryChaos

Allocates large byte arrays to simulate memory pressure.

```dart
final memoryChaos = MemoryChaos(config: ChaosConfig(
  memoryPressure: 0.10,
  memoryAllocationMb: 100,  // allocate 100 MB
));

// Manual trigger:
final triggered = await memoryChaos.pressurize(holdDurationMs: 3000);
```

- Allocation is held for `holdDurationMs` ms, then released.
- Capped at 512 MB to protect the device.
- `heldAllocationSize` property reports current held chunks.

---

## CpuChaos

Runs a tight compute loop to simulate CPU spikes.

```dart
final cpuChaos = CpuChaos(config: ChaosConfig(
  cpuSpike: 0.05,
  cpuSpikeDurationMs: 2000,
  cpuSpikeIterations: 5000000,
));

final triggered = await cpuChaos.spike();
```

⚠️  Runs on the **same Dart isolate** as the app, deliberately stressing
the event loop to surface UI-blocking code.

---

## ExceptionChaos

Throws random exceptions at wrapped call sites.

```dart
final exChaos = ExceptionChaos(config: ChaosConfig(
  throwRandomException: 0.05,
  customExceptions: [
    NetworkException('simulated timeout'),
    AuthException('simulated 401'),
  ],
));

final data = await exChaos.wrap(
  () => apiService.fetchDashboard(),
  label: 'api.fetchDashboard',
);
```

If `customExceptions` is empty, one of seven built-in `ChaosException`
messages is used.

---

## LatencyChaos

Adds random delays to **any** async call — not just HTTP.

```dart
final latency = LatencyChaos(config: ChaosConfig(
  injectLatency: 0.15,
  latencyMinMs: 500,
  latencyMaxMs: 4000,
));

// Wrap a call:
final result = await latency.wrap(
  () => bleDevice.readCharacteristic(uuid),
  label: 'BLE.readCharacteristic',
);

// Or just delay the current execution context:
final delayMs = await latency.maybeDelay(label: 'stream.listen');
```

---

## BaseExperiment — extending the framework

```dart
class MyCustomChaos extends BaseExperiment {
  MyCustomChaos({required super.config, super.seed});

  @override
  String get name => 'MyCustomChaos';

  @override
  String get description => 'Injects custom faults specific to my app.';

  @override
  bool shouldTrigger() => config.enabled;

  @override
  Future<void> execute({void Function(ChaosEvent)? onEvent}) async {
    await super.execute(onEvent: onEvent);
    if (!rollFor(0.10)) return;

    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: DateTime.now(),
      description: 'Custom fault fired',
      tags: config.tags,
    );
    emitEvent(event, onEvent: onEvent);
  }

  @override
  Future<void> cleanup() async {}
}
```
