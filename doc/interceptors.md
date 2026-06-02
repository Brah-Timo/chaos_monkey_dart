# Interceptors

`chaos_monkey_dart` ships two interceptor families — one for
**Dio** and one for the **`http`** package.  Neither family adds `dio`
or `http` as a hard dependency of this package; you add them to your
own `pubspec.yaml`.

---

## Dio — `ChaosDioInterceptor` / `DioChaosBridge`

### Add `dio` to your project

```yaml
# your app's pubspec.yaml
dependencies:
  dio: ^5.4.0
```

### Full integration (extend `Interceptor`)

```dart
// lib/core/network/chaos_interceptor.dart
import 'package:dio/dio.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

class ChaosInterceptor extends Interceptor {
  ChaosInterceptor(this._bridge);
  final DioChaosBridge _bridge;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final decision = await _bridge.handleRequest(
      options.uri.toString(),
      options.method,
    );

    if (!decision.shouldProceed) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: decision.error?.message,
        ),
      );
      return;
    }
    handler.next(options);
  }
}

// Usage:
final dio = Dio()
  ..interceptors.add(
    ChaosInterceptor(
      DioChaosBridge(
        config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.05),
      ),
    ),
  );
```

See `example/lib/example_with_dio.dart` for a complete runnable version.

---

## http — `ChaosHttpClient` / `ChaosHttpInterceptor`

### Add `http` to your project

```yaml
# your app's pubspec.yaml
dependencies:
  http: ^1.2.0
```

### Extend `http.BaseClient`

```dart
// lib/core/network/chaos_http_client.dart
import 'package:http/http.dart' as http;
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

class MyChaosHttpClient extends http.BaseClient {
  MyChaosHttpClient(this._inner, this._chaos);

  final http.Client _inner;
  final ChaosHttpClient _chaos;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _chaos.send(
      url: request.url.toString(),
      method: request.method,
      inner: () async => ChaosHttpResponse(statusCode: 200),
    );
    return _inner.send(request);
  }
}

// Usage:
final client = MyChaosHttpClient(
  http.Client(),
  ChaosHttpClient(
    config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.03),
  ),
);
```

See `example/lib/example_with_http.dart` for the full implementation.

---

## Decision objects

### `DioRequestDecision`

| Property | Type | Description |
|----------|------|-------------|
| `shouldProceed` | `bool` | `true` = continue; `false` = abort |
| `error` | `DioErrorInfo?` | Present when `shouldProceed` is `false` |

### `DioErrorInfo`

| Property | Type |
|----------|------|
| `url` | `String` |
| `method` | `String` |
| `errorCode` | `int` |
| `message` | `String` |
| `chaosType` | `String` (`'drop'` or `'slow'`) |

### `HttpChaosDecision`

| Property | Type | Description |
|----------|------|-------------|
| `isPassthrough` | `bool` | No chaos was applied |
| `isSlowed` | `bool` | Delay was injected |
| `isDropped` | `bool` | Request should be aborted |
| `delayMs` | `int?` | Milliseconds slowed |
| `statusCode` | `int?` | Error code when dropped |
| `message` | `String?` | Error message when dropped |

---

## `NetworkOutcome` (from `NetworkChaos.applyToRequest`)

```dart
final outcome = await networkChaos.applyToRequest(url, 'GET');
switch (true) {
  case _ when outcome.isDropped:
    throw NetworkDropException('dropped', statusCode: outcome.errorCode!);
  case _ when outcome.isSlowed:
    print('Delayed ${outcome.delayMs}ms — proceeding');
  default:
    // passthrough
}
```
