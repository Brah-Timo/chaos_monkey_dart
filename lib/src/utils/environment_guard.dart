import '../config/chaos_environment.dart';
import 'chaos_logger.dart';

// We deliberately avoid importing `package:flutter/foundation.dart` so that
// this package works in plain Dart (server-side, CLI) without Flutter.
// The caller passes `isRelease` explicitly when Flutter is available.

/// Prevents [ChaosMonkey] from running in live production environments.
///
/// ## Detection strategy (in priority order)
///
/// 1. **Custom check**: if [setCustomProductionCheck] has been called, use it.
/// 2. **`isRelease` flag** passed explicitly by the caller (from `kReleaseMode`
///    in Flutter apps).
/// 3. **`APP_ENV` compile-time constant**:
///    `--dart-define=APP_ENV=production` blocks chaos.
/// 4. **`CHAOS_MONKEY_ALLOW_PRODUCTION=true`** overrides all of the above
///    (escape hatch for unusual staging pipelines that compile in
///    release mode).
///
/// ## Recommended Flutter usage
///
/// ```dart
/// // Pass kReleaseMode explicitly — no Flutter import required in this lib.
/// EnvironmentGuard.assertNotProduction(isRelease: kReleaseMode);
/// ```
abstract class EnvironmentGuard {
  EnvironmentGuard._();

  // ── State ─────────────────────────────────────────────────────────────────

  static bool Function()? _customCheck;

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Registers a custom predicate that overrides all built-in detection logic.
  ///
  /// Return `true` from [check] to indicate a production environment
  /// (chaos will be blocked).
  ///
  /// ```dart
  /// EnvironmentGuard.setCustomProductionCheck(
  ///   () => myFeatureFlags.isProduction,
  /// );
  /// ```
  static void setCustomProductionCheck(bool Function() check) {
    _customCheck = check;
    ChaosLogger.info('EnvironmentGuard: custom production check registered.');
  }

  /// Clears any previously registered custom check, restoring built-in logic.
  static void clearCustomCheck() => _customCheck = null;

  // ── Detection ─────────────────────────────────────────────────────────────

  /// Detects the current [ChaosEnvironment] using all available signals.
  ///
  /// [isRelease] should be set to `kReleaseMode` in Flutter apps.
  static ChaosEnvironment detect({bool isRelease = false}) {
    // 1. Custom check takes priority.
    if (_customCheck != null) {
      return _customCheck!()
          ? ChaosEnvironment.production
          : ChaosEnvironment.staging;
    }

    // 2. Explicit escape hatch — overrides even release mode.
    const forceAllow =
        String.fromEnvironment('CHAOS_MONKEY_ALLOW_PRODUCTION');
    if (forceAllow.toLowerCase() == 'true') {
      ChaosLogger.warning(
        'EnvironmentGuard: CHAOS_MONKEY_ALLOW_PRODUCTION=true — '
        'production guard bypassed!',
      );
      return ChaosEnvironment.staging;
    }

    // 3. Flutter release mode = production.
    if (isRelease) return ChaosEnvironment.production;

    // 4. APP_ENV compile-time constant.
    const appEnv = String.fromEnvironment('APP_ENV');
    switch (appEnv.toLowerCase()) {
      case 'production':
      case 'prod':
        return ChaosEnvironment.production;
      case 'staging':
      case 'stage':
        return ChaosEnvironment.staging;
      case 'ci':
      case 'test':
        return ChaosEnvironment.ci;
      case 'pre-production':
      case 'preprod':
      case 'uat':
        return ChaosEnvironment.preProduction;
      case 'development':
      case 'dev':
        return ChaosEnvironment.development;
    }

    // 5. Default — assume development (safest for local runs).
    return ChaosEnvironment.development;
  }

  /// Returns `true` when the current environment is production.
  ///
  /// [isRelease] should be `kReleaseMode` in Flutter apps.
  static bool isProduction({bool isRelease = false}) =>
      detect(isRelease: isRelease).isProduction;

  /// Throws [ChaosInProductionException] if running in production.
  ///
  /// Call this at the start of [ChaosMonkey.start] when `safetyGuard` is
  /// enabled.
  ///
  /// ```dart
  /// EnvironmentGuard.assertNotProduction(isRelease: kReleaseMode);
  /// ```
  static void assertNotProduction({bool isRelease = false}) {
    final env = detect(isRelease: isRelease);
    if (env.isProduction) {
      throw ChaosInProductionException(env);
    }
    ChaosLogger.info(
      'EnvironmentGuard: environment is ${env.label} — chaos permitted.',
    );
  }

  /// Human-readable description of the detected environment.
  static String describe({bool isRelease = false}) =>
      detect(isRelease: isRelease).label;
}

// ── Exceptions ───────────────────────────────────────────────────────────────

/// Thrown when [ChaosMonkey] detects it is being started in production.
///
/// Extend or catch this to add custom alerting / logging in your CI pipeline.
class ChaosInProductionException implements Exception {
  /// Creates the exception for the detected [environment].
  const ChaosInProductionException(this.environment);

  /// The environment that triggered the guard.
  final ChaosEnvironment environment;

  @override
  String toString() => '''
⛔  ChaosInProductionException
    Detected environment : ${environment.label}
    ChaosMonkey refuses to run in production to protect real users.

    To fix this:
      • Wrap with:  if (!kReleaseMode) await ChaosMonkey.start(...)
      • Or pass:    --dart-define=APP_ENV=staging
      • Or set:     config.safetyGuard = false  (NOT recommended)
      • Or use:     EnvironmentGuard.setCustomProductionCheck(...)
''';
}
