import 'dart:io';
import 'dart:math';
import '../chaos_monkey.dart' show ChaosEvent;
import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import 'base_experiment.dart';

/// Simulates file-system failures: random file deletion and file corruption.
///
/// Only files matching [ChaosConfig.targetFilePatterns] are targeted.
/// If [targetFilePatterns] is empty this experiment does nothing — which is
/// the safe default.
///
/// **Recommended patterns for safe testing:**
/// ```dart
/// targetFilePatterns: ['*.cache', '*.tmp', 'draft_*'],
/// ```
///
/// ⚠️  Never add patterns that match critical app data (databases, prefs).
class FileChaos extends BaseExperiment {
  /// Creates a [FileChaos] experiment.
  FileChaos({required super.config, super.seed});

  @override
  String get name => 'FileChaos';

  @override
  String get description =>
      'Randomly deletes or corrupts files matching the configured '
      'targetFilePatterns to test app resilience against missing data.';

  // ── Core fault-injection ──────────────────────────────────────────────────

  /// Scans [directory] for files matching [ChaosConfig.targetFilePatterns]
  /// and applies either deletion or corruption based on configured
  /// probabilities.
  ///
  /// Returns the list of [FileChaosResult]s (one per affected file).
  Future<List<FileChaosResult>> apply(Directory directory) async {
    if (!config.enabled) return const [];
    if (config.targetFilePatterns.isEmpty) return const [];
    if (!await directory.exists()) return const [];

    final results = <FileChaosResult>[];
    final candidates = await _findCandidates(directory);
    if (candidates.isEmpty) return const [];

    for (final file in candidates) {
      if (rollFor(config.deleteRandomFile)) {
        final result = await _deleteFile(file);
        if (result != null) results.add(result);
      } else if (rollFor(config.corruptRandomFile)) {
        final result = await _corruptFile(file);
        if (result != null) results.add(result);
      }
    }
    return results;
  }

  // ── Scheduler-driven execution ────────────────────────────────────────────

  @override
  Future<void> execute({void Function(ChaosEvent event)? onEvent}) async {
    await super.execute(onEvent: onEvent);
    // The scheduler just logs intent; actual targeting requires a directory.
    // In a real Flutter app, provide the docs directory at startup.
    if (!shouldTrigger()) return;

    final event = ChaosEvent(
      experimentType: name,
      triggeredAt: DateTime.now(),
      description: 'Scheduler: file chaos tick — no directory bound',
      metadata: {
        'source': 'scheduler',
        'patterns': config.targetFilePatterns,
      },
      tags: config.tags,
    );
    emitEvent(event, onEvent: onEvent);
    ChaosLogger.chaos('📁📅 Scheduler file event (no directory bound)');
  }

  @override
  bool shouldTrigger() =>
      config.enabled &&
      config.targetFilePatterns.isNotEmpty &&
      (config.deleteRandomFile > 0 || config.corruptRandomFile > 0);

  @override
  Future<void> cleanup() async {
    ChaosLogger.info('FileChaos cleanup complete.');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<List<File>> _findCandidates(Directory dir) async {
    final files = <File>[];
    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          for (final pattern in config.targetFilePatterns) {
            if (_matchesGlob(name, pattern)) {
              files.add(entity);
              break;
            }
          }
        }
      }
    } catch (e) {
      ChaosLogger.warning('FileChaos: failed to list directory: $e');
    }
    return files;
  }

  Future<FileChaosResult?> _deleteFile(File file) async {
    try {
      await file.delete();
      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'Deleted ${file.path}',
        metadata: {'path': file.path, 'fault': 'delete'},
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('📁🗑️  DELETE  ${file.path}');
      return FileChaosResult(path: file.path, action: FileChaosAction.deleted);
    } catch (e) {
      ChaosLogger.warning('FileChaos: could not delete ${file.path}: $e');
      return null;
    }
  }

  Future<FileChaosResult?> _corruptFile(File file) async {
    try {
      final originalSize = await file.length();
      // Write random bytes (75% of original size to remain realistic).
      final corruptSize = max(1, (originalSize * 0.75).round());
      final garbage = List<int>.generate(
        corruptSize,
        (_) => Random().nextInt(256),
      );
      await file.writeAsBytes(garbage, flush: true);

      final event = ChaosEvent(
        experimentType: name,
        triggeredAt: DateTime.now(),
        description: 'Corrupted ${file.path}  ($corruptSize bytes written)',
        metadata: {
          'path': file.path,
          'originalSize': originalSize,
          'corruptSize': corruptSize,
          'fault': 'corrupt',
        },
        tags: config.tags,
      );
      emitEvent(event);
      ChaosLogger.chaos('📁🔥 CORRUPT  ${file.path}');
      return FileChaosResult(
        path: file.path,
        action: FileChaosAction.corrupted,
      );
    } catch (e) {
      ChaosLogger.warning('FileChaos: could not corrupt ${file.path}: $e');
      return null;
    }
  }

  /// Minimal glob matching: supports `*` wildcard at prefix/suffix/both.
  bool _matchesGlob(String filename, String pattern) {
    if (pattern == '*') return true;
    if (!pattern.contains('*')) return filename == pattern;
    final parts = pattern.split('*');
    if (parts.length == 2) {
      final prefix = parts[0];
      final suffix = parts[1];
      return filename.startsWith(prefix) && filename.endsWith(suffix);
    }
    // Fallback: simple contains check.
    return filename.contains(pattern.replaceAll('*', ''));
  }
}

// ── Value objects ────────────────────────────────────────────────────────────

/// The type of action taken on a file.
enum FileChaosAction { deleted, corrupted }

/// Result of a single file chaos operation.
class FileChaosResult {
  /// Creates the result.
  const FileChaosResult({required this.path, required this.action});

  /// Absolute path of the affected file.
  final String path;

  /// Whether the file was deleted or corrupted.
  final FileChaosAction action;

  @override
  String toString() => 'FileChaosResult(${action.name}: $path)';
}
