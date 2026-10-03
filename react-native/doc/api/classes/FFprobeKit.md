[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFprobeKit

# Class: FFprobeKit

High-level FFprobe API for inspecting media files, URLs, streams, and devices.

Call `FFmpegKitExtended.initialize()` once before use. Commands omit the
`ffprobe` executable name. For common structured metadata, prefer
`getMediaInformation()` over manually parsing FFprobe JSON output.

## Constructors

### Constructor

> **new FFprobeKit**(): `FFprobeKit`

#### Returns

`FFprobeKit`

## Methods

### cancel()

> `static` **cancel**(`session`): `Promise`\<`void`\>

Requests cancellation of a created, queued, or running FFprobe session.

#### Parameters

##### session

[`FFprobeSession`](FFprobeSession.md)

#### Returns

`Promise`\<`void`\>

***

### createMediaInformationSession()

> `static` **createMediaInformationSession**(`path`, `timeoutMs?`): [`MediaInformationSession`](MediaInformationSession.md)

Creates a structured media-information session without starting it.

#### Parameters

##### path

`string`

Local path, content-accessible path, or protocol URL supported
by the selected FFmpegKit bundle.

##### timeoutMs?

`number` = `500`

Native probe timeout in milliseconds. Defaults to 500.

#### Returns

[`MediaInformationSession`](MediaInformationSession.md)

***

### createSession()

> `static` **createSession**(`command`): [`FFprobeSession`](FFprobeSession.md)

Creates an FFprobe session without starting it.

#### Parameters

##### command

`string`

#### Returns

[`FFprobeSession`](FFprobeSession.md)

***

### execute()

> `static` **execute**(`command`, `options?`): `Promise`\<[`FFprobeSession`](FFprobeSession.md)\>

Alias of `executeAsync()`; resolves when FFprobe finishes.

#### Parameters

##### command

`string`

##### options?

[`ExecuteOptions`](../interfaces/ExecuteOptions.md)\<[`FFprobeSession`](FFprobeSession.md)\> = `{}`

#### Returns

`Promise`\<[`FFprobeSession`](FFprobeSession.md)\>

***

### executeAsync()

> `static` **executeAsync**(`command`, `options?`): `Promise`\<[`FFprobeSession`](FFprobeSession.md)\>

Creates, queues, and executes an FFprobe command.

Use the session output for custom probes. For standard format, stream, and
chapter metadata, use `getMediaInformation()`.

#### Parameters

##### command

`string`

##### options?

[`ExecuteOptions`](../interfaces/ExecuteOptions.md)\<[`FFprobeSession`](FFprobeSession.md)\> = `{}`

#### Returns

`Promise`\<[`FFprobeSession`](FFprobeSession.md)\>

***

### getFFprobeSessions()

> `static` **getFFprobeSessions**(): [`FFprobeSession`](FFprobeSession.md)[]

Returns FFprobe sessions currently retained in native history.

#### Returns

[`FFprobeSession`](FFprobeSession.md)[]

***

### getLastFFprobeSession()

> `static` **getLastFFprobeSession**(): [`FFprobeSession`](FFprobeSession.md) \| `undefined`

Returns the newest FFprobe session retained in native history.

#### Returns

[`FFprobeSession`](FFprobeSession.md) \| `undefined`

***

### getMediaInformation()

> `static` **getMediaInformation**(`path`, `timeoutMs?`): `Promise`\<[`MediaInformationSession`](MediaInformationSession.md)\>

Probes one input and resolves with a completed media-information session.
Call `session.getMediaInformation()` to obtain the typed result.

#### Parameters

##### path

`string`

##### timeoutMs?

`number` = `500`

#### Returns

`Promise`\<[`MediaInformationSession`](MediaInformationSession.md)\>
