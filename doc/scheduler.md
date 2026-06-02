# Scheduler

The scheduler drives chaos **autonomously** — independently of whether
your interceptors are receiving traffic.  It fires experiments on a
regular cadence so memory pressure, CPU spikes, and other non-HTTP faults
are tested even during quiet periods.

---

## `ChaosScheduler` — fixed interval

Fires one randomly-selected experiment every `intervalSeconds` seconds.

```
   0s           60s          120s          180s
   │             │             │             │
   ▼             ▼             ▼             ▼
[warm-up 5s] → tick 1       tick 2        tick 3
               (CpuChaos)   (MemoryChaos) (skipped: paused)
```

### Concurrency guard

If the previous experiment is still running when the next tick fires and
`_runningCount >= maxConcurrent`, the tick is **skipped** silently.  This
prevents compounding failures that make root-cause analysis impossible.

### Diagnostics

```dart
final scheduler = ChaosScheduler(...);
print(scheduler.tickCount);    // total ticks fired
print(scheduler.runningCount); // currently executing
```

---

## `RandomScheduler` — jittered interval

Fires at intervals drawn uniformly from
`[minIntervalSeconds, maxIntervalSeconds]`.  Produces more realistic
patterns because real-world failures do not follow a predictable schedule.

```dart
final scheduler = RandomScheduler(
  experiments: myExperiments,
  minIntervalSeconds: 15,
  maxIntervalSeconds: 90,
  onEvent: handleEvent,
  isPausedCallback: () => monkey.isPaused,
  seed: 42,                  // reproducible in tests
);
await scheduler.start();
// ...
await scheduler.stop();
```

---

## Scheduler inside `ChaosMonkey`

`ChaosMonkey.start()` creates a `ChaosScheduler` automatically based on
`ChaosConfig.schedulerIntervalSeconds` and
`ChaosConfig.maxConcurrentExperiments`.  You only need to create a
scheduler manually if you are building a custom harness.

---

## Warm-up delay

`ChaosScheduler.start()` waits **5 seconds** before the first tick so
the application finishes initialising before faults begin.  This avoids
confusing start-up logs with chaos events.

---

## Experiment selection

Each tick picks one experiment at random (uniform distribution across the
registered pool).  The selected experiment then calls its own
`rollFor(probability)` to decide whether to actually fire.  This two-step
design means a tick does not guarantee a fault — it only gives the
experiment a chance.

---

## Using `RandomScheduler` as the primary scheduler

```dart
class MyApp {
  late final RandomScheduler _scheduler;

  Future<void> start() async {
    final experiments = [
      MemoryChaos(config: config),
      CpuChaos(config: config),
    ];

    _scheduler = RandomScheduler(
      experiments: experiments,
      minIntervalSeconds: 30,
      maxIntervalSeconds: 120,
      maxConcurrent: 2,
      onEvent: (event) => print(event),
      isPausedCallback: () => false,
    );
    await _scheduler.start();
  }

  Future<void> stop() => _scheduler.stop();
}
```
