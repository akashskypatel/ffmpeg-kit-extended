[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFmpegKit

# Class: FFmpegKit

High-level FFmpeg command API for transcoding, filtering, muxing, capture,
analysis, and other media-processing operations.

Call `FFmpegKitExtended.initialize()` once before using this class. Commands
omit the `ffmpeg` executable name and execute asynchronously so the JavaScript
thread remains responsive.

## Constructors

### Constructor

> **new FFmpegKit**(): `FFmpegKit`

#### Returns

`FFmpegKit`

## Methods

### cancel()

> `static` **cancel**(`session`): `Promise`\<`void`\>

Requests cancellation of a created, queued, or running FFmpeg session.

#### Parameters

##### session

[`FFmpegSession`](FFmpegSession.md)

#### Returns

`Promise`\<`void`\>

***

### createSession()

> `static` **createSession**(`command`): [`FFmpegSession`](FFmpegSession.md)

Creates a session without starting it.

Use the returned object to install callbacks, inspect its ID, or enqueue it
later with `session.executeAsync()`.

#### Parameters

##### command

`string`

#### Returns

[`FFmpegSession`](FFmpegSession.md)

#### Throws

`Error` when `command` is blank.

***

### createSessionFromArguments()

> `static` **createSessionFromArguments**(`arguments_`): [`FFmpegSession`](FFmpegSession.md)

Creates a session from pre-tokenized FFmpeg arguments.

This avoids manual quoting for paths and values containing whitespace.

#### Parameters

##### arguments\_

readonly `string`[]

#### Returns

[`FFmpegSession`](FFmpegSession.md)

***

### execute()

> `static` **execute**(`command`, `options?`): `Promise`\<[`FFmpegSession`](FFmpegSession.md)\>

Executes an FFmpeg command asynchronously.

This is an alias of `executeAsync()` retained for API familiarity. Resolve
the returned promise, then inspect `getReturnCode()`, `getOutput()`, or the
supplied callbacks.

#### Parameters

##### command

`string`

##### options?

[`FFmpegExecuteOptions`](../interfaces/FFmpegExecuteOptions.md)\<[`FFmpegSession`](FFmpegSession.md)\> = `{}`

#### Returns

`Promise`\<[`FFmpegSession`](FFmpegSession.md)\>

***

### executeAsync()

> `static` **executeAsync**(`command`, `options?`): `Promise`\<[`FFmpegSession`](FFmpegSession.md)\>

Creates, queues, and executes an FFmpeg session.

The shared `SessionQueueManager` limits native concurrency. Log and
statistics callbacks are delivered from buffered native data while the
session runs. The promise resolves after final callbacks are delivered.

#### Parameters

##### command

`string`

##### options?

[`FFmpegExecuteOptions`](../interfaces/FFmpegExecuteOptions.md)\<[`FFmpegSession`](FFmpegSession.md)\> = `{}`

#### Returns

`Promise`\<[`FFmpegSession`](FFmpegSession.md)\>

***

### getFFmpegSessions()

> `static` **getFFmpegSessions**(): [`FFmpegSession`](FFmpegSession.md)[]

Returns FFmpeg sessions currently retained in native history.

#### Returns

[`FFmpegSession`](FFmpegSession.md)[]

***

### getLastFFmpegSession()

> `static` **getLastFFmpegSession**(): [`FFmpegSession`](FFmpegSession.md) \| `undefined`

Returns the newest FFmpeg session retained in native history.

#### Returns

[`FFmpegSession`](FFmpegSession.md) \| `undefined`
