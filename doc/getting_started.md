# Getting Started

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  chaos_monkey_dart: ^1.0.0
```

Then run:

```sh
dart pub get
# or
flutter pub get
```

### Optional peer dependencies

`chaos_monkey_dart` does **not** force `http` or `dio` into your project.
Add whichever you already use:

```yaml
dependencies:
  http: ^1.2.0       # if you use the http package
  dio: ^5.4.0        # if you use Dio
```

---

## 1. Minimal setup (Flutter)

```dart
import 'package:flutter/foundation.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    await ChaosMonkey.start(
      config: ChaosConfig(
        slowNetwork: 0.20,
        networkDelayMs: 6000,
        killDatabase: 0.05,
      ),
      isRelease: kReleaseMode, // production guard
    );
  }

  runApp(const MyApp());
}
```

Stop when you are done (e.g. in a test `tearDown`):

```dart
final report = await ChaosMonkey.stop();
print(report);
```

---

## 2. Using a preset

```dart
// Light — good for daily CI
await ChaosMonkey.start(config: ChaosConfig.light());

// Medium — weekly resilience gate
await ChaosMonkey.start(config: ChaosConfig.medium());

// Heavy — dedicated resilience sprint
await ChaosMonkey.start(config: ChaosConfig.heavy());

// Nuclear — maximum chaos (Chaos Day events only)
await ChaosMonkey.start(config: ChaosConfig.nuclear());
```

---

## 3. Network chaos with Dio

```dart
import 'package:dio/dio.dart';
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

final dio = Dio();

// In your DI layer / main():
final bridge = DioChaosBridge(
  config: ChaosConfig(slowNetwork: 0.25, dropNetwork: 0.05),
);
// Wrap requests manually (see example/lib/example_with_dio.dart
// for a full Interceptor subclass):
final decision = await bridge.handleRequest(url, method);
if (!decision.shouldProceed) {
  throw Exception(decision.error?.message);
}
```

---

## 4. Network chaos with `http`

```dart
import 'package:http/http.dart' as http;
import 'package:chaos_monkey_dart/chaos_monkey_dart.dart';

// Wrap your real client:
final chaosClient = ChaosHttpClient(
  config: ChaosConfig(slowNetwork: 0.20, dropNetwork: 0.03),
);

final response = await chaosClient.send(
  url: 'https://api.example.com/users',
  method: 'GET',
  inner: () async {
    final r = await http.get(Uri.parse('https://api.example.com/users'));
    return ChaosHttpResponse(statusCode: r.statusCode, body: r.body);
  },
);
```

---

## 5. Database chaos

```dart
final dbChaos = DatabaseChaos(config: config);

// Wrap every DB call:
final users = await dbChaos.wrap(
  () => database.query('SELECT * FROM users'),
  label: 'users.getAll',
);
// users may be null (corrupt), delayed (slow), or throw (kill)
```

---

## 6. Latency on any async call

```dart
final latency = LatencyChaos(config: config);

final profile = await latency.wrap(
  () => userRepository.getProfile(userId),
  label: 'UserRepository.getProfile',
);
```

---

## 7. Exception chaos

```dart
final exChaos = ExceptionChaos(
  config: ChaosConfig(
    throwRandomException: 0.05,
    customExceptions: [
      NetworkException('simulated network failure'),
      AuthException('simulated token expired'),
    ],
  ),
);

final result = await exChaos.wrap(
  () => myService.fetchData(),
  label: 'myService.fetchData',
);
```

---

## 8. Pause / resume / update config at runtime

```dart
// Temporarily suppress chaos (e.g. during a critical user journey):
ChaosMonkey.pause();
await criticalPaymentFlow();
ChaosMonkey.resume();

// Update config on-the-fly without restarting:
ChaosMonkey.updateConfig(
  ChaosConfig.medium().copyWith(slowNetwork: 0.40),
);

// Inspect live status:
final status = ChaosMonkey.status();
print('Running: ${status.isRunning}, '
    'events so far: ${status.totalEventsTriggered}');
```

---

## Tear-down in tests

```dart
setUp(() async {
  await ChaosMonkey.start(config: ChaosConfig.light(), isRelease: false);
});

tearDown(() async {
  await ChaosMonkey.stop();
  ChaosMonkey.reset(); // clears the singleton for next test
});
```
