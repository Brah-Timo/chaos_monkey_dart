// ignore_for_file: lines_longer_than_80_chars
// The banner strings below contain ANSI-coloured interpolations that cannot
// be broken across lines without losing the visual alignment.
import '../chaos_monkey.dart' show ChaosEvent, ChaosReport;
import '../config/chaos_config.dart';
import 'chaos_reporter.dart';

/// Configuration token for [ConsoleReporter].
class ConsoleReporterConfig extends ReporterConfig {
  /// Creates the config.
  const ConsoleReporterConfig({this.verbose = true, this.useAnsiColors = true});

  /// If `true`, every individual [ChaosEvent] is printed.
  final bool verbose;

  /// If `true`, ANSI color codes are used for visual distinction.
  final bool useAnsiColors;
}

/// Prints chaos events to stdout with formatted ASCII-art banners.
///
/// Example output:
/// ```
/// ╔══════════════════════════════════════════════════════════════╗
/// ║   🐒💥 CHAOS MONKEY DART — STARTED                          ║
/// ║   Intensity: 9.5% [MEDIUM]                                  ║
/// ╚══════════════════════════════════════════════════════════════╝
///
/// [🐒 CHAOS] 2026-06-01T10:00:01.000Z NetworkChaos: Slowed GET / +5200ms
/// ```
class ConsoleReporter implements ChaosReporter {
  /// Creates a [ConsoleReporter].
  const ConsoleReporter({this.verbose = true, this.useAnsiColors = true});

  /// If `true`, individual events are printed as they arrive.
  final bool verbose;

  /// If `true`, ANSI colors are used where available.
  final bool useAnsiColors;

  // ANSI codes
  static const _reset = '\x1B[0m';
  static const _orange = '\x1B[33m';
  static const _red = '\x1B[31m';
  static const _cyan = '\x1B[36m';
  static const _green = '\x1B[32m';
  static const _bold = '\x1B[1m';

  String _c(String code, String text) =>
      useAnsiColors ? '$code$text$_reset' : text;

  @override
  void onChaosStarted(ChaosConfig config) {
    // ignore: avoid_print
    print(_c(_bold, '''
╔══════════════════════════════════════════════════════════════╗
║   🐒💥  CHAOS MONKEY DART — STARTED                         ║
╠══════════════════════════════════════════════════════════════╣
║   ${_c(_orange, '⚠️  WARNING: Intentional failures will be injected')}        ║
║   ${_c(_orange, '⚠️  This is STAGING / TESTING mode only')}                   ║
║   ${_c(_red, '⚠️  DO NOT use in production')}                              ║
╠══════════════════════════════════════════════════════════════╣
║   Intensity      : ${_c(_orange, '${(config.totalChaosIntensity * 100).toStringAsFixed(1)}% [${config.intensityLabel}]')}
║   Network slow   : ${_c(_cyan, '${(config.slowNetwork * 100).toStringAsFixed(1)}%  (+${config.networkDelayMs}ms)')}
║   Network drop   : ${_c(_cyan, '${(config.dropNetwork * 100).toStringAsFixed(1)}%')}
║   DB kill        : ${_c(_cyan, '${(config.killDatabase * 100).toStringAsFixed(1)}%')}
║   DB slow        : ${_c(_cyan, '${(config.slowDatabase * 100).toStringAsFixed(1)}%')}
║   File delete    : ${_c(_cyan, '${(config.deleteRandomFile * 100).toStringAsFixed(1)}%')}
║   File corrupt   : ${_c(_cyan, '${(config.corruptRandomFile * 100).toStringAsFixed(1)}%')}
║   Memory         : ${_c(_cyan, '${(config.memoryPressure * 100).toStringAsFixed(1)}%  (${config.memoryAllocationMb}MB)')}
║   CPU spike      : ${_c(_cyan, '${(config.cpuSpike * 100).toStringAsFixed(1)}%  (${config.cpuSpikeDurationMs}ms)')}
║   Exceptions     : ${_c(_cyan, '${(config.throwRandomException * 100).toStringAsFixed(1)}%')}
║   Latency        : ${_c(_cyan, '${(config.injectLatency * 100).toStringAsFixed(1)}%  (${config.latencyMinMs}–${config.latencyMaxMs}ms)')}
╚══════════════════════════════════════════════════════════════╝'''));
  }

  @override
  void onChaosEvent(ChaosEvent event) {
    if (!verbose) return;
    // ignore: avoid_print
    print(_c(_orange, '[🐒 CHAOS] $event'));
  }

  @override
  void onChaosStopped(ChaosReport report) {
    // ignore: avoid_print
    print(_c(_green, report.toString()));
  }
}
