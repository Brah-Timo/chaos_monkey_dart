import '../config/chaos_config.dart';
import '../utils/chaos_logger.dart';
import 'chaos_http_interceptor.dart';
import '../experiments/network_chaos.dart';

/// A drop-in replacement for the `http` package's `Client` that transparently
/// injects network chaos into every request.
///
/// ## Usage
///
/// Replace your normal `http.Client()` with `ChaosHttpClient`:
///
/// ```dart
/// import 'package:http/http.dart' as http;
/// import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';
///
/// // Normal:  final client = http.Client();
/// // Chaos:
/// final client = ChaosHttpClient(
///   config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.03),
/// );
///
/// // Use exactly like http.Client:
/// final response = await client.get(
///   Uri.parse('https://api.example.com/data'),
/// );
/// print(response.statusCode);
///
/// client.close();
/// ```
///
/// ## Notes
///
/// - This file does NOT import `package:http` directly so the package stays
///   lean.  Consumers add `http: ^1.2.0` to their own `pubspec.yaml`.
///
/// - A complete, runnable implementation is provided in
///   `example/lib/example_with_http.dart` which does import `http` and
///   extends `http.BaseClient`.
///
/// - The chaos logic is fully isolated in [ChaosHttpInterceptor] and is
///   independent of the transport layer.
class ChaosHttpClient {
  /// Creates a [ChaosHttpClient] with the given [config].
  ChaosHttpClient({required this.config})
      : _interceptor = ChaosHttpInterceptor(config: config);

  /// The configuration governing this client.
  final ChaosConfig config;

  final ChaosHttpInterceptor _interceptor;

  bool _closed = false;

  // ── Public send API ───────────────────────────────────────────────────────

  /// Mirrors the signature of `http.BaseClient.send`.
  ///
  /// Applies chaos rules before delegating to the real [inner] transport.
  ///
  /// [inner] is a callback that performs the actual HTTP request and returns
  /// a response.  Use `Future<ChaosHttpResponse>` as the portable return type.
  ///
  /// ```dart
  /// final response = await chaosClient.send(
  ///   url: request.url.toString(),
  ///   method: request.method,
  ///   inner: () async {
  ///     final streamedResponse = await realClient.send(request);
  ///     return ChaosHttpResponse(statusCode: streamedResponse.statusCode);
  ///   },
  /// );
  /// ```
  Future<ChaosHttpResponse> send({
    required String url,
    required String method,
    required Future<ChaosHttpResponse> Function() inner,
  }) async {
    if (_closed) {
      throw StateError('ChaosHttpClient has been closed.');
    }

    final decision = await _interceptor.process(url: url, method: method);

    if (decision.isDropped) {
      ChaosLogger.chaos(
        '🌐💀 [ChaosHttpClient] DROP  $method  $url',
      );
      throw NetworkDropException(
        decision.message ??
            'chaos_monkey: connection dropped for $method $url',
        statusCode: decision.statusCode ?? config.networkErrorCode,
      );
    }

    return inner();
  }

  /// Closes the client.  After calling this, [send] will throw [StateError].
  void close() {
    _closed = true;
    ChaosLogger.info('ChaosHttpClient closed.');
  }
}

// ── Portable response wrapper ────────────────────────────────────────────────

/// Minimal, transport-agnostic HTTP response value object.
///
/// The full `http.Response` or `http.StreamedResponse` should be wrapped by
/// the consumer after calling [ChaosHttpClient.send].
class ChaosHttpResponse {
  /// Creates a response.
  const ChaosHttpResponse({
    required this.statusCode,
    this.body = '',
    this.headers = const <String, String>{},
  });

  /// HTTP status code.
  final int statusCode;

  /// Response body as a string.
  final String body;

  /// Response headers.
  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() =>
      'ChaosHttpResponse(status=$statusCode, body=${body.length} chars)';
}
