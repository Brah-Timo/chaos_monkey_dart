# Safety Guide

## ⛔ Golden rule

> **NEVER run chaos_monkey_dart in production.**
>
> It deliberately corrupts data, drops connections, and throws
> unexpected exceptions.  Even with `safetyGuard: true`, all real
> protections depend on correct calling code.

---

## Built-in production guard

By default `ChaosConfig.safetyGuard = true`.  When `ChaosMonkey.start()`
is called with `isRelease: true`, it calls
`EnvironmentGuard.assertNotProduction()` which throws
`ChaosInProductionException` immediately.

```dart
// Flutter — pass kReleaseMode so the guard works:
await ChaosMonkey.start(
  config: config,
  isRelease: kReleaseMode,   // ← required for production guard
);
```

If you forget `isRelease: kReleaseMode`, the guard cannot detect
Flutter's release mode because this package deliberately avoids importing
`package:flutter/foundation.dart`.

---

## Detection priority

`EnvironmentGuard.detect()` evaluates in this order:

1. **Custom check** — `setCustomProductionCheck(() => myFlags.isProd)`
2. **`isRelease` flag** — from `kReleaseMode`
3. **`CHAOS_MONKEY_ALLOW_PRODUCTION=true`** env var — escape hatch
4. **`APP_ENV` compile-time constant** — `--dart-define=APP_ENV=production`
5. **Default** — assumes development (safe for local runs)

---

## Wrapping pattern — always guard

```dart
// ✅ Correct
if (kDebugMode) {
  await ChaosMonkey.start(config: config, isRelease: kReleaseMode);
}

// ✅ Also correct
if (!kReleaseMode) {
  await ChaosMonkey.start(config: config, isRelease: false);
}

// ❌ Wrong — no guard
await ChaosMonkey.start(config: config);
```

---

## Environment variables

```sh
# In unusual staging pipelines that run in release mode:
flutter run --release --dart-define=CHAOS_MONKEY_ALLOW_PRODUCTION=true

# Mark environment as staging explicitly:
flutter run --dart-define=APP_ENV=staging
```

---

## Custom check for feature-flag-driven rollout

```dart
EnvironmentGuard.setCustomProductionCheck(
  () => remoteConfig.getBool('is_production_build'),
);

// Clear it later:
EnvironmentGuard.clearCustomCheck();
```

---

## `safetyGuard: false` — when is it acceptable?

Only in:
- **Internal tools / CLIs** that can never reach production users.
- **Load testing scripts** running on an isolated staging environment
  with no real user data.

Always document **why** you disabled the guard in code comments.

---

## File chaos — extra caution

`FileChaos` can permanently delete files.  Always scope it tightly:

```dart
// ✅ Safe — only targets known temp files
ChaosConfig(
  targetFilePatterns: ['*.cache', '*.tmp', 'draft_*'],
  deleteRandomFile: 0.05,
)

// ❌ Dangerous — could delete database files
ChaosConfig(
  targetFilePatterns: ['*'],
  deleteRandomFile: 0.10,
)
```

---

## Memory chaos — cap allocation

`memoryAllocationMb` is capped at **512 MB** internally, but keep it
well below available device RAM.  A value of 50–100 MB is usually
sufficient to trigger GC pressure.

---

## CI checklist

Before merging code that calls `ChaosMonkey.start()`:

- [ ] `isRelease: kReleaseMode` passed
- [ ] Wrapped in `if (kDebugMode)` or equivalent guard
- [ ] `safetyGuard` is `true` (default)
- [ ] `targetFilePatterns` is scoped to safe temp files
- [ ] `memoryAllocationMb` ≤ 100 for mobile targets
- [ ] `seed` set for deterministic test runs
