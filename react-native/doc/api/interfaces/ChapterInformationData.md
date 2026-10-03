[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / ChapterInformationData

# Interface: ChapterInformationData

Raw chapter fields supplied by the native media-information parser.

## Properties

### allPropertiesJson?

> `optional` **allPropertiesJson?**: `string`

Serialized full FFprobe chapter object. Prefer `allProperties`.

***

### end?

> `optional` **end?**: `number`

End timestamp in chapter time-base units.

***

### endTime?

> `optional` **endTime?**: `string`

End time in seconds as formatted by FFprobe.

***

### id?

> `optional` **id?**: `number`

Chapter identifier reported by the container.

***

### start?

> `optional` **start?**: `number`

Start timestamp in chapter time-base units.

***

### startTime?

> `optional` **startTime?**: `string`

Start time in seconds as formatted by FFprobe.

***

### tagsJson?

> `optional` **tagsJson?**: `string`

Serialized chapter tags. Prefer the parsed `tags` getter.

***

### timeBase?

> `optional` **timeBase?**: `string`

Chapter time base as an FFprobe rational string.
