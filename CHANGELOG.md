# Changelog

All notable changes to `chaos_monkey_dart` are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-06-01

### Added

#### Core
- `ChaosMonkey` singleton controller with `start` / `stop` / `pause` / `resume` / `status` / `quickStart` / `updateConfig` static API.
- `ChaosConfig` immutable configuration with 20+ parameters and compile-time `assert` validation.
- `ChaosConfig` factory presets: `light`, `medium`, `heavy`, `nuclear`.
- `ChaosConfig.copyWith` for incremental reconfiguration.
- `ChaosReport` — aggregated session report with `eventsByType`, `eventsPerMinute`, `totalDuration`.
- `ChaosStatus` — lightweight real-time status snapshot.
- `ChaosEvent` — structured event record with metadata and tags.

#### Experiments
- `NetworkChaos` — HTTP request delay (with jitter) and drop simulation.
- `DatabaseChaos` — connection kill, slow query, corrupt read.
- `FileChaos` — random file deletion and corruption (pattern-scoped).
- `MemoryChaos` — heap pressure via large array allocation.
- `CpuChaos` — tight-loop CPU spike simulation.
- `ExceptionChaos` — random exception injection from configurable pool.
- `LatencyChaos` — generic latency injection for any async operation.
- `BaseExperiment` abstract base with `rollFor`, `emitEvent`, `execute`, `cleanup` contract.

#### Interceptors
- `ChaosDioInterceptor` + `DioChaosBridge` — Dio HTTP interceptor integration.
- `ChaosHttpInterceptor` — transport-agnostic http package decision engine.
- `ChaosHttpClient` — drop-in chaos-aware http.BaseClient wrapper.
- `NetworkOutcome`, `DioRequestDecision`, `HttpChaosDecision` value objects.

#### Reporters
- `ChaosReporter` abstract interface.
- `ConsoleReporter` — ANSI-coloured ASCII-art console output.
- `FileReporter` — JSON Lines or plain-text log file output.
- `CallbackReporter` — user-supplied callback hooks.
- `EventCollectorReporter` — in-memory event collection for test assertions.
- `MultiReporter` — fan-out to multiple reporters simultaneously.
- `SilentReporter` — no-op reporter for headless environments.

#### Schedulers
- `ChaosScheduler` — fixed-interval periodic experiment scheduler.
- `RandomScheduler` — randomised inter-tick interval scheduler.

#### Utilities
- `Probability` — `roll`, `rollSeeded`, `expectedHits`, `atLeastOnceProbability`, `exactlyKProbability`, `confidenceInterval95`, `impactSummary`.
- `EnvironmentGuard` — multi-layer production environment detection.
- `ChaosLogger` — structured `logging`-based internal logger with SHOUT level for chaos events.
- `ChaosEnvironment` enum with `isChaosAllowed` / `isProduction` helpers.

#### Safety
- `ChaosInProductionException` — thrown when `safetyGuard = true` and release mode is detected.
- Production guard supports: `kReleaseMode`, `APP_ENV` dart-define, `CHAOS_MONKEY_ALLOW_PRODUCTION` escape hatch, and custom check callbacks.

#### Testing
- `mock_helpers.dart` with `alwaysTriggerConfig`, `alwaysKillDatabaseConfig`, `alwaysDropNetworkConfig`, `alwaysThrowConfig`, `silentConfig`, `withChaosCollector`.
- Full test suites: `chaos_monkey_test.dart`, `chaos_config_test.dart`, `network_chaos_test.dart`, `database_chaos_test.dart`, `probability_test.dart`.

#### Documentation
- `README.md` — full usage guide with API reference table.
- `doc/getting_started.md` — step-by-step setup guide.
- `doc/experiments_reference.md` — per-experiment reference.
- `doc/configuration_guide.md` — all config parameters explained.
- `doc/safety_guide.md` — production safety best practices.
- `example/main.dart` — 8-demo standalone Dart example.
- `example/lib/example_with_dio.dart` — complete Dio integration example.
- `example/lib/example_with_http.dart` — complete http package example.

---

## [0.9.0-beta] — 2026-04-15

### Added
- Initial beta release.
- Basic `NetworkChaos` and `DatabaseChaos`.
- `ChaosConfig` with probability fields.
- `ConsoleReporter`.

### Changed
- n/a (first release)

### Fixed
- n/a (first release)
