export interface StreamInformationData {
  index?: number;
  type?: string;
  codec?: string;
  codecLong?: string;
  format?: string;
  width?: number;
  height?: number;
  bitrate?: string;
  sampleRate?: string;
  sampleFormat?: string;
  channelLayout?: string;
  sampleAspectRatio?: string;
  displayAspectRatio?: string;
  averageFrameRate?: string;
  realFrameRate?: string;
  timeBase?: string;
  codecTimeBase?: string;
  tagsJson?: string;
  allPropertiesJson?: string;
}

export class StreamInformation implements StreamInformationData {
  index?: number;
  type?: string;
  codec?: string;
  codecLong?: string;
  format?: string;
  width?: number;
  height?: number;
  bitrate?: string;
  sampleRate?: string;
  sampleFormat?: string;
  channelLayout?: string;
  sampleAspectRatio?: string;
  displayAspectRatio?: string;
  averageFrameRate?: string;
  realFrameRate?: string;
  timeBase?: string;
  codecTimeBase?: string;
  tagsJson?: string;
  allPropertiesJson?: string;

  constructor(data: StreamInformationData) {
    Object.assign(this, data);
  }

  get tags(): Record<string, unknown> | undefined {
    return parseJsonObject(this.tagsJson);
  }

  get allProperties(): Record<string, unknown> | undefined {
    return parseJsonObject(this.allPropertiesJson);
  }
}

export interface ChapterInformationData {
  id?: number;
  timeBase?: string;
  start?: number;
  startTime?: string;
  end?: number;
  endTime?: string;
  tagsJson?: string;
  allPropertiesJson?: string;
}

export class ChapterInformation implements ChapterInformationData {
  id?: number;
  timeBase?: string;
  start?: number;
  startTime?: string;
  end?: number;
  endTime?: string;
  tagsJson?: string;
  allPropertiesJson?: string;

  constructor(data: ChapterInformationData) {
    Object.assign(this, data);
  }

  get tags(): Record<string, unknown> | undefined {
    return parseJsonObject(this.tagsJson);
  }

  get allProperties(): Record<string, unknown> | undefined {
    return parseJsonObject(this.allPropertiesJson);
  }
}

export interface MediaInformationData {
  filename?: string;
  format?: string;
  longFormat?: string;
  duration?: string;
  startTime?: string;
  bitrate?: string;
  size?: string;
  tagsJson?: string;
  allPropertiesJson?: string;
  streams?: StreamInformationData[];
  chapters?: ChapterInformationData[];
}

export class MediaInformation {
  readonly filename?: string;
  readonly format?: string;
  readonly longFormat?: string;
  readonly duration?: string;
  readonly startTime?: string;
  readonly bitrate?: string;
  readonly size?: string;
  readonly tagsJson?: string;
  readonly allPropertiesJson?: string;
  readonly streams: StreamInformation[];
  readonly chapters: ChapterInformation[];

  constructor(data: MediaInformationData) {
    this.filename = data.filename;
    this.format = data.format;
    this.longFormat = data.longFormat;
    this.duration = data.duration;
    this.startTime = data.startTime;
    this.bitrate = data.bitrate;
    this.size = data.size;
    this.tagsJson = data.tagsJson;
    this.allPropertiesJson = data.allPropertiesJson;
    this.streams = (data.streams ?? []).map(
      stream => new StreamInformation(stream),
    );
    this.chapters = (data.chapters ?? []).map(
      chapter => new ChapterInformation(chapter),
    );
  }

  get tags(): Record<string, unknown> | undefined {
    return parseJsonObject(this.tagsJson);
  }

  get allProperties(): Record<string, unknown> | undefined {
    return parseJsonObject(this.allPropertiesJson);
  }
}

function parseJsonObject(
  value: string | undefined,
): Record<string, unknown> | undefined {
  if (!value) return undefined;
  try {
    const parsed: unknown = JSON.parse(value);
    if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed as Record<string, unknown>;
    }
  } catch {
    // Keep parity with the Flutter models: malformed property JSON maps to null.
  }
  return undefined;
}
