[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / StreamInformation

# Class: StreamInformation

One audio, video, subtitle, data, or attachment stream.

Fields mirror FFprobe output and are optional. `tags` and `allProperties`
safely parse their JSON forms and return `undefined` for absent/malformed
objects.

## Implements

- [`StreamInformationData`](../interfaces/StreamInformationData.md)

## Constructors

### Constructor

> **new StreamInformation**(`data`): `StreamInformation`

Creates a stream wrapper from native FFprobe data.

#### Parameters

##### data

[`StreamInformationData`](../interfaces/StreamInformationData.md)

#### Returns

`StreamInformation`

## Properties

### allPropertiesJson?

> `optional` **allPropertiesJson?**: `string`

Serialized full stream object; prefer `allProperties`.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`allPropertiesJson`](../interfaces/StreamInformationData.md#allpropertiesjson)

***

### averageFrameRate?

> `optional` **averageFrameRate?**: `string`

Average video frame rate as an FFprobe rational string.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`averageFrameRate`](../interfaces/StreamInformationData.md#averageframerate)

***

### bitrate?

> `optional` **bitrate?**: `string`

Stream bitrate as FFprobe text, usually bits per second.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`bitrate`](../interfaces/StreamInformationData.md#bitrate)

***

### channelLayout?

> `optional` **channelLayout?**: `string`

Audio channel layout such as `stereo` or `5.1`.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`channelLayout`](../interfaces/StreamInformationData.md#channellayout)

***

### codec?

> `optional` **codec?**: `string`

Short codec name reported by FFprobe.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`codec`](../interfaces/StreamInformationData.md#codec)

***

### codecLong?

> `optional` **codecLong?**: `string`

Human-readable codec description.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`codecLong`](../interfaces/StreamInformationData.md#codeclong)

***

### codecTimeBase?

> `optional` **codecTimeBase?**: `string`

Codec time base when exposed by the selected build.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`codecTimeBase`](../interfaces/StreamInformationData.md#codectimebase)

***

### displayAspectRatio?

> `optional` **displayAspectRatio?**: `string`

Display aspect ratio.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`displayAspectRatio`](../interfaces/StreamInformationData.md#displayaspectratio)

***

### format?

> `optional` **format?**: `string`

Pixel format, sample format, or related stream format.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`format`](../interfaces/StreamInformationData.md#format)

***

### height?

> `optional` **height?**: `number`

Coded video height in pixels when this is a video stream.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`height`](../interfaces/StreamInformationData.md#height)

***

### index?

> `optional` **index?**: `number`

Zero-based stream index in the container.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`index`](../interfaces/StreamInformationData.md#index)

***

### realFrameRate?

> `optional` **realFrameRate?**: `string`

Nominal/raw video frame rate as an FFprobe rational string.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`realFrameRate`](../interfaces/StreamInformationData.md#realframerate)

***

### sampleAspectRatio?

> `optional` **sampleAspectRatio?**: `string`

Encoded sample aspect ratio.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`sampleAspectRatio`](../interfaces/StreamInformationData.md#sampleaspectratio)

***

### sampleFormat?

> `optional` **sampleFormat?**: `string`

Audio sample format such as `fltp` or `s16`.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`sampleFormat`](../interfaces/StreamInformationData.md#sampleformat)

***

### sampleRate?

> `optional` **sampleRate?**: `string`

Audio sample rate as FFprobe text in hertz.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`sampleRate`](../interfaces/StreamInformationData.md#samplerate)

***

### tagsJson?

> `optional` **tagsJson?**: `string`

Serialized stream tags; prefer `tags` for parsed values.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`tagsJson`](../interfaces/StreamInformationData.md#tagsjson)

***

### timeBase?

> `optional` **timeBase?**: `string`

Stream time base as an FFprobe rational string.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`timeBase`](../interfaces/StreamInformationData.md#timebase)

***

### type?

> `optional` **type?**: `string`

Stream type such as `video`, `audio`, or `subtitle`.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`type`](../interfaces/StreamInformationData.md#type)

***

### width?

> `optional` **width?**: `number`

Coded video width in pixels when this is a video stream.

#### Implementation of

[`StreamInformationData`](../interfaces/StreamInformationData.md).[`width`](../interfaces/StreamInformationData.md#width)

## Accessors

### allProperties

#### Get Signature

> **get** **allProperties**(): `Record`\<`string`, `unknown`\> \| `undefined`

Complete parsed FFprobe stream object, including unmodeled fields.

##### Returns

`Record`\<`string`, `unknown`\> \| `undefined`

***

### tags

#### Get Signature

> **get** **tags**(): `Record`\<`string`, `unknown`\> \| `undefined`

Parsed stream metadata tags, or `undefined` when unavailable.

##### Returns

`Record`\<`string`, `unknown`\> \| `undefined`
