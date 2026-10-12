export type ImportedPathRetention = {
  selectedPath?: string;
  hasMediaInfoRead: boolean;
  hasActiveJobs: boolean;
};

export function shouldRetainImportedPath(
  path: string,
  state: ImportedPathRetention,
): boolean;

export function withImportedPathReservation<T>(
  path: string,
  reservation: {
    retainPath: (path: string) => void;
    releasePath: (path: string) => void;
    cleanupPath: (path: string) => void;
  },
  operation: () => Promise<T>,
): Promise<T>;

export function readDurationSeconds(value: unknown): number | undefined;

export function advanceTranscodeProgressPercent(
  positionMilliseconds: number,
  durationSeconds: number | undefined,
  previousPercent?: number,
): number | undefined;
