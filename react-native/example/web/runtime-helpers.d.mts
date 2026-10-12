export type ImportedPathRetention = {
  selectedPath?: string;
  hasMediaInfoRead: boolean;
  hasActiveJobs: boolean;
};

export function shouldRetainImportedPath(
  path: string,
  state: ImportedPathRetention,
): boolean;

export function readDurationSeconds(value: unknown): number | undefined;

export function advanceTranscodeProgressPercent(
  positionMilliseconds: number,
  durationSeconds: number | undefined,
  previousPercent?: number,
): number | undefined;
