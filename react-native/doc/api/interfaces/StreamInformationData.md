[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / StreamInformationData

# Interface: StreamInformationData

Raw stream fields supplied by the native media-information parser.

## Properties

### allPropertiesJson?

> `optional` **allPropertiesJson?**: `string`

Serialized full FFprobe stream object. Prefer `allProperties`.

***

### averageFrameRate?

> `optional` **averageFrameRate?**: `string`

Average video frame rate as an FFprobe rational string.

***

### bitrate?

> `optional` **bitrate?**: `string`

Stream bitrate as reported by FFprobe, usually bits per second.

***

### channelLayout?

> `optional` **channelLayout?**: `string`

Audio channel layout such as `stereo` or `5.1`.

***

### codec?

> `optional` **codec?**: `string`

Short codec name, for example `h264` or `aac`.

***

### codecLong?

> `optional` **codecLong?**: `string`

Human-readable codec description.

***

### codecTimeBase?

> `optional` **codecTimeBase?**: `string`

Codec time base when exposed by the selected FFmpeg build.

***

### displayAspectRatio?

> `optional` **displayAspectRatio?**: `string`

Display aspect ratio, commonly expressed as `num:den`.

***

### format?

> `optional` **format?**: `string`

Pixel format, sample format, or related stream format value.

***

### height?

> `optional` **height?**: `number`

Coded video height in pixels when this is a video stream.

***

### index?

> `optional` **index?**: `number`

Zero-based stream index in the container.

***

### realFrameRate?

> `optional` **realFrameRate?**: `string`

Nominal/raw video frame rate as an FFprobe rational string.

***

### sampleAspectRatio?

> `optional` **sampleAspectRatio?**: `string`

Encoded sample aspect ratio, commonly expressed as `num:den`.

***

### sampleFormat?

> `optional` **sampleFormat?**: `string`

Audio sample format such as `fltp` or `s16`.

***

### sampleRate?

> `optional` **sampleRate?**: `string`

Audio sample rate in hertz, represented as FFprobe text.

***

### tagsJson?

> `optional` **tagsJson?**: `string`

Serialized stream tags. Prefer the parsed `tags` getter.

***

### timeBase?

> `optional` **timeBase?**: `string`

Stream time base as an FFprobe rational string.

***

### type?

> `optional` **type?**: `string`

Stream type such as `video`, `audio`, or `subtitle`.

***

### width?

> `optional` **width?**: `number`

Coded video width in pixels when this is a video stream.
