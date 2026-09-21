import 'dart:async';

import 'package:meta/meta.dart';

/// Deduplicates one initialization attempt while allowing a failed attempt to
/// be replaced by a later call.
@visibleForTesting
final class RetryableInitialization<T extends Object> {
  T? _value;
  Future<T>? _initializing;

  bool get initialized => _value != null;

  T get value {
    final value = _value;
    if (value == null) {
      throw StateError('Initialization has not completed successfully.');
    }
    return value;
  }

  Future<T> initialize(Future<T> Function() load) {
    final value = _value;
    if (value != null) return Future<T>.value(value);

    final active = _initializing;
    if (active != null) return active;

    late final Future<T> attempt;
    attempt = Future<T>.sync(load)
        .then((value) {
          _value = value;
          return value;
        })
        .whenComplete(() {
          if (_value == null && identical(_initializing, attempt)) {
            _initializing = null;
          }
        });
    _initializing = attempt;
    return attempt;
  }
}
