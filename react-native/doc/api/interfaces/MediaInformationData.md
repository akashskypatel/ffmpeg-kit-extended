[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / MediaInformationData

# Interface: MediaInformationData

Raw container-level fields supplied by the native parser.

## Properties

### allPropertiesJson?

> `optional` **allPropertiesJson?**: `string`

Serialized full FFprobe format object. Prefer `allProperties`.

***

### bitrate?

> `optional` **bitrate?**: `string`

Overall bitrate as FFprobe text, usually bits per second.

***

### chapters?

> `optional` **chapters?**: [`ChapterInformationData`](ChapterInformationData.md)[]

Chapters contained in the input.

***

### duration?

> `optional` **duration?**: `string`

Media duration in seconds as FFprobe text.

***

### filename?

> `optional` **filename?**: `string`

Input filename, path, or URL reported by FFprobe.

***

### format?

> `optional` **format?**: `string`

Short container format name, which may contain comma-separated aliases.

***

### longFormat?

> `optional` **longFormat?**: `string`

Human-readable container format description.

***

### size?

> `optional` **size?**: `string`

Input size in bytes as FFprobe text.

***

### startTime?

> `optional` **startTime?**: `string`

Container start time in seconds as FFprobe text.

***

### streams?

> `optional` **streams?**: [`StreamInformationData`](StreamInformationData.md)[]

Streams contained in the input.

***

### tagsJson?

> `optional` **tagsJson?**: `string`

Serialized container tags. Prefer the parsed `tags` getter.
