import 'dart:math';

/// Pure-function probability utilities used throughout the experiments.
///
/// Every public method is `static` so no instantiation is required.
///
/// ## Core formula
///
/// `roll(p, random)` returns `true` with probability `p`:
///
/// ```
/// P(trigger) = p,   where 0.0 ≤ p ≤ 1.0
/// ```
///
/// ## Expected hits over N calls
///
/// ```
/// E(triggers) = p × n
/// ```
///
/// ## Probability of at least one trigger in N calls
///
/// ```
/// P(≥1 trigger) = 1 − (1 − p)^n
/// ```
class Probability {
  /// Private constructor — this class is purely static.
  Probability._();

  // ── Core roll ──────────────────────────────────────────────────────────────

  /// Returns `true` with probability [p] using the supplied [random] instance.
  ///
  /// Boundary behaviour:
  /// - `p ≤ 0.0` → always `false`  (no chaos)
  /// - `p ≥ 1.0` → always `true`   (guaranteed chaos)
  ///
  /// Using the caller's [Random] instance keeps tests deterministic when a
  /// seeded generator is passed in.
  static bool roll(double p, Random random) {
    if (p <= 0.0) return false;
    if (p >= 1.0) return true;
    return random.nextDouble() < p;
  }

  /// Seeded convenience roll for reproducible single-call tests.
  ///
  /// Combines [seed] with [callIndex] so successive calls yield different but
  /// reproducible results.
  static bool rollSeeded(double p, int seed, int callIndex) {
    final seededRandom = Random(seed ^ (callIndex * 2654435761));
    return roll(p, seededRandom);
  }

  // ── Statistical helpers ───────────────────────────────────────────────────

  /// Expected number of chaos triggers over [trials] independent calls.
  ///
  /// ```
  /// E(X) = p × n
  /// ```
  static double expectedHits(double p, int trials) => p * trials;

  /// Probability that chaos fires **at least once** across [trials] calls.
  ///
  /// ```
  /// P(X ≥ 1) = 1 − (1 − p)^n
  /// ```
  static double atLeastOnceProbability(double p, int trials) {
    if (p <= 0.0) return 0.0;
    if (p >= 1.0) return 1.0;
    return 1.0 - pow(1.0 - p, trials);
  }

  /// Probability that chaos fires **exactly [k] times** across [trials] calls
  /// (Binomial distribution PMF).
  ///
  /// ```
  /// P(X = k) = C(n,k) × p^k × (1-p)^(n-k)
  /// ```
  static double exactlyKProbability(double p, int trials, int k) {
    if (k < 0 || k > trials) return 0.0;
    return _binomialCoefficient(trials, k) *
        pow(p, k) *
        pow(1 - p, trials - k);
  }

  /// Confidence interval half-width at the 95 % level using the normal
  /// approximation to the binomial distribution.
  ///
  /// ```
  /// ±z × √(p(1−p)/n),   z = 1.96
  /// ```
  static double confidenceInterval95(double p, int trials) {
    if (trials <= 0) return 0.0;
    const z = 1.96;
    return z * sqrt(p * (1 - p) / trials);
  }

  /// Returns a human-readable impact summary for use in log output.
  ///
  /// Example output:
  /// ```
  /// "~1.0/min  (~60/hr)  at 5.0%"
  /// ```
  static String impactSummary(double p, int requestsPerMinute) {
    final perMin = p * requestsPerMinute;
    final perHour = perMin * 60;
    final pctStr = '${(p * 100).toStringAsFixed(1)}%';
    return '~${perMin.toStringAsFixed(1)}/min '
        '(~${perHour.toStringAsFixed(0)}/hr) at $pctStr';
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static double _binomialCoefficient(int n, int k) {
    if (k == 0 || k == n) return 1;
    if (k > n - k) k = n - k; // use smaller k for efficiency
    double result = 1;
    for (var i = 0; i < k; i++) {
      result *= (n - i) / (i + 1);
    }
    return result;
  }
}
