let playbackEpoch = 0;
let playbackSessionId: number | undefined;

/** Advances the identity and records the native source for a Web FFplay run. */
export function beginFFplayPlayback(sessionId: number): void {
  playbackEpoch += 1;
  playbackSessionId = sessionId;
}

/** Returns the current Web FFplay playback epoch. */
export function currentFFplayPlaybackEpoch(): number {
  return playbackEpoch;
}

/** Returns the native session that owns the current Web FFplay source. */
export function currentFFplayPlaybackSessionId(): number | undefined {
  return playbackSessionId;
}

/** Resets playback identity for isolated tests. */
export function resetFFplayPlaybackEpochForTests(): void {
  playbackEpoch = 0;
  playbackSessionId = undefined;
}
