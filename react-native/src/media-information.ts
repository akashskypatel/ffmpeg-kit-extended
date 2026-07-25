/**
 * Structured FFprobe media metadata returned by
 * `FFprobeKit.getMediaInformation()`.
 *
 * FFprobe represents many numeric values as strings to preserve its exact JSON
 * output and avoid precision/format changes. Convert fields such as `duration`,
 * `bitrate`, `size`, and `sampleRate` only when your application needs numeric
 * arithmetic, and handle missing values because containers and streams expose
 * different metadata.
 */
/** Raw stream fields supplied by the native media-information parser. */
export interface StreamInformationData {
  /** Zero-based stream index in the container. */
  index?: number;
  /** Stream type such as `video`, `audio`, or `subtitle`. */
  type?: string;
  /** Short codec name, for example `h264` or `aac`. */
  codec?: string;
  /** Human-readable codec description. */
  codecLong?: string;
  /** Pixel format, sample format, or related stream format value. */
  format?: string;
  /** Coded video width in pixels when this is a video stream. */
  width?: number;
  /** Coded video height in pixels when this is a video stream. */
  height?: number;
  /** Stream bitrate as reported by FFprobe, usually bits per second. */
  bitrate?: string;
  /** Audio sample rate in hertz, represented as FFprobe text. */
  sampleRate?: string;
  /** Audio sample format such as `fltp` or `s16`. */
  sampleFormat?: string;
  /** Audio channel layout such as `stereo` or `5.1`. */
  channelLayout?: string;
  /** Encoded sample aspect ratio, commonly expressed as `num:den`. */
  sampleAspectRatio?: string;
  /** Display aspect ratio, commonly expressed as `num:den`. */
  displayAspectRatio?: string;
  /** Average video frame rate as an FFprobe rational string. */
  averageFrameRate?: string;
  /** Nominal/raw video frame rate as an FFprobe rational string. */
  realFrameRate?: string;
  /** Stream time base as an FFprobe rational string. */
  timeBase?: string;
  /** Codec time base when exposed by the selected FFmpeg build. */
  codecTimeBase?: string;
  /** Serialized stream tags. Prefer the parsed `tags` getter. */
  tagsJson?: string;
  /** Serialized full FFprobe stream object. Prefer `allProperties`. */
  allPropertiesJson?: string;
}

/**
 * One audio, video, subtitle, data, or attachment stream.
 *
 * Fields mirror FFprobe output and are optional. `tags` and `allProperties`
 * safely parse their JSON forms and return `undefined` for absent/malformed
 * objects.
 */
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

  /** Parsed stream metadata tags, or `undefined` when unavailable. */
  get tags(): Record<string, unknown> | undefined {
    return parseJsonObject(this.tagsJson);
  }

  /** Complete parsed FFprobe stream object, including unmodeled fields. */
  get allProperties(): Record<string, unknown> | undefined {
    return parseJsonObject(this.allPropertiesJson);
  }
}

/** Raw chapter fields supplied by the native media-information parser. */
export interface ChapterInformationData {
  /** Chapter identifier reported by the container. */
  id?: number;
  /** Chapter time base as an FFprobe rational string. */
  timeBase?: string;
  /** Start timestamp in chapter time-base units. */
  start?: number;
  /** Start time in seconds as formatted by FFprobe. */
  startTime?: string;
  /** End timestamp in chapter time-base units. */
  end?: number;
  /** End time in seconds as formatted by FFprobe. */
  endTime?: string;
  /** Serialized chapter tags. Prefer the parsed `tags` getter. */
  tagsJson?: string;
  /** Serialized full FFprobe chapter object. Prefer `allProperties`. */
  allPropertiesJson?: string;
}

/** One chapter or timeline marker reported by the container. */
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

  /** Parsed chapter tags, or `undefined` when unavailable. */
  get tags(): Record<string, unknown> | undefined {
    return parseJsonObject(this.tagsJson);
  }

  /** Complete parsed FFprobe chapter object. */
  get allProperties(): Record<string, unknown> | undefined {
    return parseJsonObject(this.allPropertiesJson);
  }
}

/** Raw container-level fields supplied by the native parser. */
export interface MediaInformationData {
  /** Input filename, path, or URL reported by FFprobe. */
  filename?: string;
  /** Short container format name, which may contain comma-separated aliases. */
  format?: string;
  /** Human-readable container format description. */
  longFormat?: string;
  /** Media duration in seconds as FFprobe text. */
  duration?: string;
  /** Container start time in seconds as FFprobe text. */
  startTime?: string;
  /** Overall bitrate as FFprobe text, usually bits per second. */
  bitrate?: string;
  /** Input size in bytes as FFprobe text. */
  size?: string;
  /** Serialized container tags. Prefer the parsed `tags` getter. */
  tagsJson?: string;
  /** Serialized full FFprobe format object. Prefer `allProperties`. */
  allPropertiesJson?: string;
  /** Streams contained in the input. */
  streams?: StreamInformationData[];
  /** Chapters contained in the input. */
  chapters?: ChapterInformationData[];
}

/**
 * Container-level metadata plus typed stream and chapter collections.
 *
 * Obtain this from a completed `MediaInformationSession`:
 *
 * ```ts
 * const session = await FFprobeKit.getMediaInformation(path);
 * const media = session.getMediaInformation();
 * console.log(media?.format, media?.streams);
 * ```
 */
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

  /** Parsed container tags, or `undefined` when unavailable. */
  get tags(): Record<string, unknown> | undefined {
    return parseJsonObject(this.tagsJson);
  }

  /** Complete parsed FFprobe format object, including unmodeled fields. */
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
