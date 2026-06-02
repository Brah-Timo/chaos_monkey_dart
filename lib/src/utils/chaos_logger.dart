import 'package:logging/logging.dart';

/// Internal structured logger for chaos_monkey_dart.
///
/// Uses the Dart `logging` package so host applications can attach their own
/// [Logger.onRecord] listener to redirect output to their preferred sink
/// (e.g. Firebase Crashlytics, Sentry, a file, etc.).
///
/// Levels used:
/// | Level   | Meaning                                      |
/// |---------|----------------------------------------------|
/// | FINE    | Detailed internal trace (verbose mode only)  |
/// | INFO    | Lifecycle events (start, stop, scheduler)    |
/// | WARNING | Unexpected but non-fatal conditions          |
/// | SEVERE  | Errors that should never happen              |
/// | SHOUT   | Active chaos event fired (most important)    |
class ChaosLogger {
  ChaosLogger._();

  static final Logger _log = Logger('chaos_monkey_dart');

  /// Whether to emit [Level.FINE] trace messages.
  static bool verbose = true;

  /// Attaches a simple stdout handler if no handler is already registered.
  ///
  /// Call once at app startup if you want console output without configuring
  /// the `logging` package yourself.
  static void enableDefaultConsoleOutput() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print('[${record.level.name}] ${record.loggerName}: ${record.message}');
      if (record.error != null) {
        // ignore: avoid_print
        print('  error: ${record.error}');
      }
    });
  }

  /// Logs a detailed trace message (only when [verbose] is `true`).
  static void trace(String message) {
    if (verbose) _log.fine(message);
  }

  /// Logs a lifecycle or informational message.
  static void info(String message) => _log.info(message);

  /// Logs a warning about unexpected but recoverable conditions.
  static void warning(String message) => _log.warning(message);

  /// Logs a severe / unexpected error.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log.severe(message, error, stackTrace);

  /// Logs an active chaos event (uses SHOUT level so it stands out).
  ///
  /// Prefixes are used to make console scanning easy:
  /// - 🌐  Network
  /// - 🗄️   Database
  /// - 📁  File system
  /// - 🧠  Memory
  /// - 💻  CPU
  /// - 💥  Exception
  /// - ⏱️   Latency
  static void chaos(String message) => _log.shout('🐒 $message');
}
