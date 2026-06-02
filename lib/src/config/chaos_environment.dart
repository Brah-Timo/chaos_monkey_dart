/// Describes the runtime environment in which the application is executing.
///
/// Used by [EnvironmentGuard] to decide whether chaos injection is permitted.
enum ChaosEnvironment {
  /// Local developer machine — full chaos allowed.
  development,

  /// Automated CI pipeline — chaos allowed, verbose output recommended.
  ci,

  /// Shared staging / QA server — chaos allowed with coordinator approval.
  staging,

  /// Pre-production / UAT environment — chaos allowed with extra caution.
  preProduction,

  /// Live production environment — chaos is **FORBIDDEN**.
  production,

  /// Environment could not be determined.
  unknown,
}

/// Extension helpers for [ChaosEnvironment].
extension ChaosEnvironmentX on ChaosEnvironment {
  /// Returns `true` if chaos injection should be blocked in this environment.
  bool get isProduction => this == ChaosEnvironment.production;

  /// Returns `true` if chaos injection is considered safe.
  bool get isChaosAllowed =>
      this == ChaosEnvironment.development ||
      this == ChaosEnvironment.ci ||
      this == ChaosEnvironment.staging ||
      this == ChaosEnvironment.preProduction;

  /// A short human-readable label for log output.
  String get label {
    switch (this) {
      case ChaosEnvironment.development:
        return 'DEVELOPMENT';
      case ChaosEnvironment.ci:
        return 'CI';
      case ChaosEnvironment.staging:
        return 'STAGING';
      case ChaosEnvironment.preProduction:
        return 'PRE-PRODUCTION';
      case ChaosEnvironment.production:
        return 'PRODUCTION ⛔';
      case ChaosEnvironment.unknown:
        return 'UNKNOWN';
    }
  }
}
