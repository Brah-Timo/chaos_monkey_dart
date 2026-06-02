/// Example: Complete http package integration for chaos_monkey_dart.
///
/// Add to your pubspec.yaml:
/// ```yaml
/// dependencies:
///   http: ^1.2.0
///   chaos_monkey_dart:
///     path: ../
/// ```

// NOTE: Requires `http: ^1.2.0` in the consumer's pubspec.yaml.
// Wrapped in a comment block since http is not in this package's deps.

/*

import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

/// A drop-in replacement for [http.Client] that injects chaos.
///
/// ```dart
/// // Before (normal):
/// final client = http.Client();
///
/// // After (chaos-aware):
/// final client = ChaosAwareHttpClient(
///   config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.03),
/// );
///
/// // Use identically to http.Client:
/// final response = await client.get(Uri.parse('https://api.example.com'));
/// print(response.statusCode);
///
/// client.close();
/// ```
class ChaosAwareHttpClient extends http.BaseClient {
  ChaosAwareHttpClient({
    required this.config,
    http.Client? inner,
  }) : _inner = inner ?? http.Client();

  final ChaosConfig config;
  final http.Client _inner;
  late final _interceptor = ChaosHttpInterceptor(config: config);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final decision = await _interceptor.process(
      url: request.url.toString(),
      method: request.method,
    );

    if (decision.isDropped) {
      throw NetworkDropException(
        decision.message ??
            'chaos_monkey: connection dropped for '
                '${request.method} ${request.url}',
        statusCode: decision.statusCode ?? config.networkErrorCode,
      );
    }

    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Example: A service class that uses [ChaosAwareHttpClient].
///
/// In production, pass a normal [http.Client].
/// In staging/debug, pass a [ChaosAwareHttpClient].
class PostsService {
  PostsService({required this.client});

  final http.Client client;

  Future<String> getPost(int id) async {
    try {
      final response = await client.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/$id'),
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on NetworkDropException catch (e) {
      // Chaos-injected drop — handle the same as a real network error.
      throw Exception('Network unavailable: ${e.statusCode}');
    }
  }
}

/// Demonstrates the full flow:
Future<void> runHttpExample() async {
  final client = ChaosAwareHttpClient(
    config: const ChaosConfig(
      slowNetwork: 0.30,
      networkDelayMs: 2000,
      dropNetwork: 0.10,
    ),
  );

  final service = PostsService(client: client);

  for (var i = 1; i <= 5; i++) {
    try {
      final post = await service.getPost(i);
      print('Post $i: ${post.substring(0, 50)}...');
    } catch (e) {
      print('Post $i failed: $e');
    }
  }

  client.close();
}

*/

// Placeholder so the file is valid Dart without the http import.
// ignore: avoid_print
void _httpDemoPlaceholder() {
  // ignore: avoid_print
  print('Add http: ^1.2.0 to pubspec.yaml and uncomment the code above.');
}
