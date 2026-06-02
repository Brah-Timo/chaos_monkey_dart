import 'dart:io';
import '../chaos_monkey.dart' show ChaosEvent, ChaosReport;
import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import 'chaos_reporter.dart';

/// Configuration token for [FileReporter].
class FileReporterConfig extends ReporterConfig {
  /// Creates the config.
  const FileReporterConfig({
    required this.logPath,
    this.format = FileReporterFormat.jsonLines,
    this.appendMode = true,
  });

  /// Absolute path to the output log file.
  final String logPath;

  /// Output format (JSON Lines or plain text).
  final FileReporterFormat format;

  /// If `true`, appends to an existing file.  If `false`, overwrites.
  final bool appendMode;
}

/// Output format for [FileReporter].
enum FileReporterFormat {
  /// One JSON object per line (NDJSON / JSON Lines).
  jsonLines,

  /// Plain human-readable text.
  plainText,
}

/// Writes chaos events to a log file on disk.
///
/// ## Setup
///
/// ```dart
/// await ChaosMonkey.start(
///   config: config,
///   reporter: FileReporter(logPath: '/tmp/chaos_log.json'),
/// );
/// ```
///
/// ## JSON Lines output example
///
/// ```json
/// {"type":"started","timestamp":"2026-06-01T10:00:00.000Z","intensity":0.095}
/// {"type":"event","experiment":"NetworkChaos",
///  "description":"Slowed GET /api/users +5200ms","durationMs":5200}
/// {"type":"stopped","totalEvents":42,"durationSeconds":1800}
/// ```
class FileReporter implements ChaosReporter {
  /// Creates a [FileReporter] that writes to [logPath].
  FileReporter({
    required this.logPath,
    this.format = FileReporterFormat.jsonLines,
    this.appendMode = true,
  }) {
    _file = File(logPath);
  }

  /// Path to the output log file.
  final String logPath;

  /// Output format.
  final FileReporterFormat format;

  /// Whether to append to an existing file.
  final bool appendMode;

  late final File _file;

  @override
  void onChaosStarted(ChaosConfig config) {
    _write(
      format == FileReporterFormat.jsonLines
          ? '{"type":"started","timestamp":"${_ts()}",'
              '"intensity":${config.totalChaosIntensity},'
              '"intensityLabel":"${config.intensityLabel}"}\n'
          : '[${_ts()}] CHAOS STARTED — intensity '
              '${(config.totalChaosIntensity * 100).toStringAsFixed(1)}%\n',
    );
  }

  @override
  void onChaosEvent(ChaosEvent event) {
    _write(
      format == FileReporterFormat.jsonLines
          ? '{"type":"event"'
              ',"timestamp":"${event.triggeredAt.toIso8601String()}"'
              ',"experiment":"${event.experimentType}",'
              '"description":${_jsonString(event.description)},'
              '"durationMs":${event.durationMs ?? 'null'},'
              '"metadata":${_jsonMap(event.metadata)}}\n'
          : '[${event.triggeredAt.toIso8601String()}] '
              '${event.experimentType}: ${event.description}'
              '${event.durationMs != null ? " (+${event.durationMs}ms)" : ""}'
              '\n',
    );
  }

  @override
  void onChaosStopped(ChaosReport report) {
    final breakdown = report.eventsByType.entries
        .map((e) => '"${e.key}":${e.value}')
        .join(',');

    _write(
      format == FileReporterFormat.jsonLines
          ? '{"type":"stopped","timestamp":"${_ts()}",'
              '"totalEvents":${report.totalEventsTriggered},'
              '"durationSeconds":${report.totalDuration.inSeconds},'
              '"eventsPerMinute":${report.eventsPerMinute.toStringAsFixed(2)},'
              '"breakdown":{$breakdown}}\n'
          : '[${_ts()}] CHAOS STOPPED — '
              '${report.totalEventsTriggered} events  '
              '${report.totalDuration.inSeconds}s\n',
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _write(String content) {
    try {
      final sink = _file.openSync(
        mode: appendMode ? FileMode.append : FileMode.write,
      );
      sink.writeStringSync(content);
      sink.closeSync();
    } catch (e) {
      ChaosLogger.warning('FileReporter: failed to write to $logPath: $e');
    }
  }

  String _ts() => DateTime.now().toUtc().toIso8601String();

  String _jsonString(String s) =>
      '"${s.replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';

  String _jsonMap(Map<String, dynamic> m) {
    final entries = m.entries
        .map(
          (e) => '"${e.key}":'
              '${e.value is String ? _jsonString(e.value as String) : e.value}',
        )
        .join(',');
    return '{$entries}';
  }
}
