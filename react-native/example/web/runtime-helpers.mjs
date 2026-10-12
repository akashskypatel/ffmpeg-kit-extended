export function shouldRetainImportedPath(
  path,
  { selectedPath, hasMediaInfoRead, hasActiveJobs },
) {
  return (
    path === selectedPath ||
    hasMediaInfoRead ||
    hasActiveJobs
  );
}

export async function withImportedPathReservation(
  path,
  { retainPath, releasePath, cleanupPath },
  operation,
) {
  retainPath(path);
  try {
    return await operation();
  } finally {
    releasePath(path);
    cleanupPath(path);
  }
}

export function readDurationSeconds(value) {
  if (typeof value !== "number" && typeof value !== "string") return undefined;
  if (typeof value === "string" && value.trim() === "") return undefined;
  const seconds = Number(value);
  return Number.isFinite(seconds) && seconds > 0 ? seconds : undefined;
}

export function advanceTranscodeProgressPercent(
  positionMilliseconds,
  durationSeconds,
  previousPercent = 0,
) {
  if (
    !Number.isFinite(positionMilliseconds) ||
    positionMilliseconds < 0 ||
    !Number.isFinite(durationSeconds) ||
    durationSeconds <= 0
  ) {
    return undefined;
  }
  const previous = Number.isFinite(previousPercent)
    ? Math.min(99, Math.max(0, previousPercent))
    : 0;
  const percent = (positionMilliseconds / 1000 / durationSeconds) * 100;
  return Math.min(99, Math.max(previous, percent));
}
