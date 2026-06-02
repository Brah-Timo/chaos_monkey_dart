/// Example: Complete Dio integration for chaos_monkey_dart.
///
/// This file is intentionally separated from main.dart so that the `dio`
/// import does not pollute projects that only use the `http` package.
///
/// Add to your pubspec.yaml:
/// ```yaml
/// dependencies:
///   dio: ^5.4.0
///   chaos_monkey_dart:
///     path: ../
/// ```
///
/// Then in your DI setup or main():
/// ```dart
/// import 'example_with_dio.dart';
///
/// final dio = buildChaosAwareDio(
///   config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.05),
/// );
/// ```

// NOTE: This file requires `dio` in the consumer's pubspec.yaml.
// The package itself does NOT list `dio` as a hard dependency.

// ignore_for_file: depend_on_referenced_packages

// The code below is intentionally wrapped in a comment block because
// `dio` is not available in this package's test environment.
// Uncomment when `dio: ^5.4.0` is added to example/pubspec.yaml.

/*

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

/// A Dio [Interceptor] that applies chaos rules to every HTTP call.
///
/// ```dart
/// final dio = Dio();
/// if (!kReleaseMode) {
///   dio.interceptors.add(
///     ChaosMonkeyDioInterceptor(
///       config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.05),
///     ),
///   );
/// }
/// ```
class ChaosMonkeyDioInterceptor extends Interceptor {
  ChaosMonkeyDioInterceptor({required this.config});

  final ChaosConfig config;
  late final _bridge = ChaosDioInterceptor(config: config);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final decision = await _bridge.processRequest(
      options.uri.toString(),
      options.method,
    );

    if (!decision.shouldProceed) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: decision.error?.message,
          message: decision.error?.message ?? 'chaos_monkey: request dropped',
        ),
        true,
      );
      return;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Optionally log chaos errors differently from real errors.
    if (err.message?.startsWith('chaos_monkey:') == true) {
      // Chaos-injected error — treat as a network error.
      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.connectionError,
          message: err.message,
        ),
      );
      return;
    }
    handler.next(err);
  }
}

/// Builds a [Dio] instance with chaos injection pre-configured.
///
/// In release mode the chaos interceptor is NOT added.
Dio buildChaosAwareDio({
  required ChaosConfig config,
  BaseOptions? options,
}) {
  final dio = Dio(options ?? BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  if (!kReleaseMode) {
    dio.interceptors.add(
      ChaosMonkeyDioInterceptor(config: config),
    );
  }

  return dio;
}

/// Example usage in a Flutter widget or service class:
///
/// ```dart
/// class UserRepository {
///   UserRepository() {
///     _dio = buildChaosAwareDio(
///       config: ChaosConfig(
///         slowNetwork: 0.20,
///         networkDelayMs: 10000,
///         dropNetwork: 0.05,
///       ),
///     );
///   }
///
///   late final Dio _dio;
///
///   Future<List<User>> getUsers() async {
///     try {
///       final response = await _dio.get('https://api.example.com/users');
///       return (response.data as List).map(User.fromJson).toList();
///     } on DioException catch (e) {
///       // This catches BOTH real errors AND chaos-injected drops
///       throw NetworkException(e.message ?? 'Unknown network error');
///     }
///   }
/// }
/// ```

*/

// Placeholder export so the file is valid Dart without the dio import.
// ignore: avoid_print
void _dioDemoPlaceholder() {
  // ignore: avoid_print
  print('Add dio: ^5.4.0 to pubspec.yaml and uncomment the code above.');
}
