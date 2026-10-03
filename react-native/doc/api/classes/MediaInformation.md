[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / MediaInformation

# Class: MediaInformation

Container-level metadata plus typed stream and chapter collections.

Obtain this from a completed `MediaInformationSession`:

```ts
const session = await FFprobeKit.getMediaInformation(path);
const media = session.getMediaInformation();
console.log(media?.format, media?.streams);
```

## Constructors

### Constructor

> **new MediaInformation**(`data`): `MediaInformation`

Creates a media-information wrapper from native FFprobe data.

#### Parameters

##### data

[`MediaInformationData`](../interfaces/MediaInformationData.md)

#### Returns

`MediaInformation`

## Properties

### allPropertiesJson?

> `readonly` `optional` **allPropertiesJson?**: `string`

Serialized full format object; prefer `allProperties`.

***

### bitrate?

> `readonly` `optional` **bitrate?**: `string`

Overall bitrate as FFprobe text, usually bits per second.

***

### chapters

> `readonly` **chapters**: [`ChapterInformation`](ChapterInformation.md)[]

Typed chapter metadata in the order reported by FFprobe.

***

### duration?

> `readonly` `optional` **duration?**: `string`

Media duration in seconds as FFprobe text.

***

### filename?

> `readonly` `optional` **filename?**: `string`

Input filename, path, or URL reported by FFprobe.

***

### format?

> `readonly` `optional` **format?**: `string`

Short container format name, possibly containing aliases.

***

### longFormat?

> `readonly` `optional` **longFormat?**: `string`

Human-readable container format description.

***

### size?

> `readonly` `optional` **size?**: `string`

Input size in bytes as FFprobe text.

***

### startTime?

> `readonly` `optional` **startTime?**: `string`

Container start time in seconds as FFprobe text.

***

### streams

> `readonly` **streams**: [`StreamInformation`](StreamInformation.md)[]

Typed stream metadata in the order reported by FFprobe.

***

### tagsJson?

> `readonly` `optional` **tagsJson?**: `string`

Serialized container tags; prefer `tags` for parsed values.

## Accessors

### allProperties

#### Get Signature

> **get** **allProperties**(): `Record`\<`string`, `unknown`\> \| `undefined`

Complete parsed FFprobe format object, including unmodeled fields.

##### Returns

`Record`\<`string`, `unknown`\> \| `undefined`

***

### tags

#### Get Signature

> **get** **tags**(): `Record`\<`string`, `unknown`\> \| `undefined`

Parsed container tags, or `undefined` when unavailable.

##### Returns

`Record`\<`string`, `unknown`\> \| `undefined`
