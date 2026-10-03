[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / ChapterInformation

# Class: ChapterInformation

One chapter or timeline marker reported by the container.

## Implements

- [`ChapterInformationData`](../interfaces/ChapterInformationData.md)

## Constructors

### Constructor

> **new ChapterInformation**(`data`): `ChapterInformation`

Creates a chapter wrapper from native FFprobe data.

#### Parameters

##### data

[`ChapterInformationData`](../interfaces/ChapterInformationData.md)

#### Returns

`ChapterInformation`

## Properties

### allPropertiesJson?

> `optional` **allPropertiesJson?**: `string`

Serialized full chapter object; prefer `allProperties`.

#### Implementation of

[`ChapterInformationData`](../interfaces/ChapterInformationData.md).[`allPropertiesJson`](../interfaces/ChapterInformationData.md#allpropertiesjson)

***

### end?

> `optional` **end?**: `number`

End timestamp in chapter time-base units.

#### Implementation of

[`ChapterInformationData`](../interfaces/ChapterInformationData.md).[`end`](../interfaces/ChapterInformationData.md#end)

***

### endTime?

> `optional` **endTime?**: `string`

End time in seconds as FFprobe text.

#### Implementation of

[`ChapterInformationData`](../interfaces/ChapterInformationData.md).[`endTime`](../interfaces/ChapterInformationData.md#endtime)

***

### id?

> `optional` **id?**: `number`

Chapter identifier reported by the container.

#### Implementation of

[`ChapterInformationData`](../interfaces/ChapterInformationData.md).[`id`](../interfaces/ChapterInformationData.md#id)

***

### start?

> `optional` **start?**: `number`

Start timestamp in chapter time-base units.

#### Implementation of

[`ChapterInformationData`](../interfaces/ChapterInformationData.md).[`start`](../interfaces/ChapterInformationData.md#start)

***

### startTime?

> `optional` **startTime?**: `string`

Start time in seconds as FFprobe text.

#### Implementation of

[`ChapterInformationData`](../interfaces/ChapterInformationData.md).[`startTime`](../interfaces/ChapterInformationData.md#starttime)

***

### tagsJson?

> `optional` **tagsJson?**: `string`

Serialized chapter tags; prefer `tags` for parsed values.

#### Implementation of

[`ChapterInformationData`](../interfaces/ChapterInformationData.md).[`tagsJson`](../interfaces/ChapterInformationData.md#tagsjson)

***

### timeBase?

> `optional` **timeBase?**: `string`

Chapter time base as an FFprobe rational string.

#### Implementation of

[`ChapterInformationData`](../interfaces/ChapterInformationData.md).[`timeBase`](../interfaces/ChapterInformationData.md#timebase)

## Accessors

### allProperties

#### Get Signature

> **get** **allProperties**(): `Record`\<`string`, `unknown`\> \| `undefined`

Complete parsed FFprobe chapter object.

##### Returns

`Record`\<`string`, `unknown`\> \| `undefined`

***

### tags

#### Get Signature

> **get** **tags**(): `Record`\<`string`, `unknown`\> \| `undefined`

Parsed chapter tags, or `undefined` when unavailable.

##### Returns

`Record`\<`string`, `unknown`\> \| `undefined`
