let playbackEpoch = 0;

/** Advances the identity used to distinguish sequential Web FFplay runs. */
export function beginFFplayPlayback(): void {
  playbackEpoch += 1;
}

/** Returns the current Web FFplay playback epoch. */
export function currentFFplayPlaybackEpoch(): number {
  return playbackEpoch;
}

/** Resets playback identity for isolated tests. */
export function resetFFplayPlaybackEpochForTests(): void {
  playbackEpoch = 0;
}
