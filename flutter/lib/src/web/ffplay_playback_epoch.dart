/// Playback identity helpers for the Web FFplay surface.
library;

/// Monotonically identifies successful high-level FFplay startup handoffs.
final class FFplayWebPlaybackEpoch {
  int _value = 0;

  int get value => _value;

  int beginPlayback() => ++_value;
}

/// Accepts a frame once per `(playback epoch, native generation)` identity.
final class FFplayWebFrameIdentity {
  int _lastEpoch = -1;
  int _lastGeneration = -1;

  bool accept({required int epoch, required int generation}) {
    if (epoch != _lastEpoch) {
      _lastEpoch = epoch;
      _lastGeneration = -1;
    }
    if (generation == _lastGeneration) return false;
    _lastGeneration = generation;
    return true;
  }
}

/// Reports when a surface must clear its decoded image for a new epoch.
final class FFplayWebSurfaceEpoch {
  int _observedEpoch = -1;

  bool observe(int epoch) {
    if (epoch == _observedEpoch) return false;
    _observedEpoch = epoch;
    return true;
  }
}
