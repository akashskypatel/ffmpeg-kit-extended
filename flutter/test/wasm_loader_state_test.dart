import 'dart:async';

import 'package:ffmpeg_kit_extended_flutter/src/platform/web/retryable_initialization.dart';
import 'package:test/test.dart';

void main() {
  test(
    'concurrent callers share one attempt and success is idempotent',
    () async {
      final state = RetryableInitialization<Object>();
      final completer = Completer<Object>();
      var attempts = 0;

      final first = state.initialize(() {
        attempts++;
        return completer.future;
      });
      final second = state.initialize(() {
        attempts++;
        return Future<Object>.value(Object());
      });

      expect(identical(first, second), isTrue);
      expect(attempts, 1);
      expect(state.initialized, isFalse);

      final value = Object();
      completer.complete(value);
      expect(await first, same(value));
      expect(state.value, same(value));

      final later = state.initialize(() {
        attempts++;
        return Future<Object>.value(Object());
      });
      expect(await later, same(value));
      expect(attempts, 1);
    },
  );

  test(
    'failed binding or native initialization leaves retry authority',
    () async {
      final state = RetryableInitialization<Object>();
      final failure = StateError('binding initialization failed');
      var attempts = 0;
      var fail = true;

      Future<Object> load() async {
        attempts++;
        if (fail) throw failure;
        return Object();
      }

      await expectLater(state.initialize(load), throwsA(same(failure)));
      expect(state.initialized, isFalse);

      fail = false;
      await state.initialize(load);
      expect(state.initialized, isTrue);
      expect(attempts, 2);
    },
  );
}
