# Reporters

Reporters receive three lifecycle callbacks:

| Callback | When called |
|----------|-------------|
| `onChaosStarted(ChaosConfig)` | Once, when `ChaosMonkey.start()` completes |
| `onChaosEvent(ChaosEvent)` | Every time a fault is injected |
| `onChaosStopped(ChaosReport)` | Once, when `ChaosMonkey.stop()` is called |

---

## Built-in reporters

### `ConsoleReporter` (default)

Prints a formatted ASCII-art banner on start/stop and a one-liner for
every event.

```dart
await ChaosMonkey.start(
  config: ChaosConfig.medium(),
  reporter: ConsoleReporter(verbose: true, useAnsiColors: true),
);
```

Output sample:
```
╔══════════════════════════════════════════════════════════════╗
║   🐒💥  CHAOS MONKEY DART — STARTED                         ║
╠══════════════════════════════════════════════════════════════╣
║   ⚠️  WARNING: Intentional failures will be injected         ║
║   Intensity      : 9.1% [MEDIUM]                            ║
╚══════════════════════════════════════════════════════════════╝

[🐒 CHAOS] 2026-06-01T10:00:01Z NetworkChaos: Slowed GET /api +5200ms
```

### `FileReporter`

Writes events to a log file in JSON Lines or plain text.

```dart
await ChaosMonkey.start(
  config: config,
  reporter: FileReporter(
    logPath: '/tmp/chaos_log.ndjson',
    format: FileReporterFormat.jsonLines,
    appendMode: true,
  ),
);
```

JSON Lines output:
```json
{"type":"started","timestamp":"2026-06-01T10:00:00.000Z","intensity":0.091}
{"type":"event","experiment":"NetworkChaos","description":"Slowed GET /api +5200ms","durationMs":5200}
{"type":"stopped","totalEvents":14,"durationSeconds":600}
```

### `CallbackReporter`

Forwards events to your own code — perfect for analytics or Sentry.

```dart
await ChaosMonkey.start(
  config: config,
  reporter: CallbackReporter(
    onStarted: (c) => analytics.log('chaos_started'),
    onEvent:   (e) => Sentry.captureMessage('[chaos] ${e.description}'),
    onStopped: (r) => analytics.log('chaos_stopped',
                        {'events': r.totalEventsTriggered}),
  ),
);
```

### `SilentReporter`

Discards all output — ideal for headless CI.

```dart
reporter: SilentReporter()
```

### `MultiReporter`

Fans out to several reporters simultaneously.

```dart
reporter: MultiReporter([
  ConsoleReporter(),
  FileReporter(logPath: '/tmp/chaos.log'),
  CallbackReporter(onEvent: (e) => myMetrics.inc(e.experimentType)),
])
```

### `EventCollectorReporter`

Collects events in memory for post-run assertions in tests.

```dart
final collector = EventCollectorReporter();
await ChaosMonkey.start(config: ChaosConfig.light(), reporter: collector);

// ... run your test scenario ...

await ChaosMonkey.stop();

expect(collector.events, isNotEmpty);
expect(
  collector.eventsFor('NetworkChaos'),
  hasLength(greaterThan(0)),
);
expect(collector.finalReport!.totalEventsTriggered, greaterThan(0));
```

---

## Custom reporter

```dart
class MyReporter implements ChaosReporter {
  @override
  void onChaosStarted(ChaosConfig config) {
    myDashboard.show('Chaos started: ${config.intensityLabel}');
  }

  @override
  void onChaosEvent(ChaosEvent event) {
    myDashboard.increment(event.experimentType);
  }

  @override
  void onChaosStopped(ChaosReport report) {
    myDashboard.summary(report.eventsByType);
  }
}
```

---

## `ChaosReport` properties

| Property | Type | Description |
|----------|------|-------------|
| `config` | `ChaosConfig` | Active config during the session |
| `startTime` | `DateTime` | When `start()` was called |
| `endTime` | `DateTime` | When `stop()` was called |
| `events` | `List<ChaosEvent>` | All recorded events |
| `totalEventsTriggered` | `int` | Total count |
| `totalDuration` | `Duration` | `endTime - startTime` |
| `eventsByType` | `Map<String, int>` | Count by experiment name |
| `eventsPerMinute` | `double` | Average event rate |

---

## `ChaosEvent` properties

| Property | Type | Description |
|----------|------|-------------|
| `experimentType` | `String` | e.g. `'NetworkChaos'` |
| `triggeredAt` | `DateTime` | Wall-clock time |
| `description` | `String` | Human-readable summary |
| `durationMs` | `int?` | Fault duration (if applicable) |
| `metadata` | `Map<String, dynamic>` | URL, delay, label, etc. |
| `tags` | `List<String>` | From `ChaosConfig.tags` |
