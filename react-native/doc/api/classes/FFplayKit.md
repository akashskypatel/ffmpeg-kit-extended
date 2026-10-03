[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFplayKit

# Class: FFplayKit

High-level FFplay API for native audio and video playback.

Mount `FFplayView` before starting video playback. Audio-only commands do not
require a view. Playback controls are session-based; retain the returned
`FFplaySession` when your UI needs pause, resume, seek, stop, position, or
volume operations.

## Constructors

### Constructor

> **new FFplayKit**(): `FFplayKit`

#### Returns

`FFplayKit`

## Accessors

### currentSession

#### Get Signature

> **get** `static` **currentSession**(): [`FFplaySession`](FFplaySession.md) \| `undefined`

Property form of `getCurrentSession()`.

##### Returns

[`FFplaySession`](FFplaySession.md) \| `undefined`

***

### paused

#### Get Signature

> **get** `static` **paused**(): `boolean`

Whether the current high-level session reports a paused state.

##### Returns

`boolean`

***

### playing

#### Get Signature

> **get** `static` **playing**(): `boolean`

Whether the current high-level session reports active playback.

##### Returns

`boolean`

## Methods

### cancel()

> `static` **cancel**(`session`): `Promise`\<`void`\>

Requests cancellation of a created, queued, or running playback session.

#### Parameters

##### session

[`FFplaySession`](FFplaySession.md)

#### Returns

`Promise`\<`void`\>

***

### createSession()

> `static` **createSession**(`command`, `timeoutMs?`): [`FFplaySession`](FFplaySession.md)

Creates a playback session without starting it.

#### Parameters

##### command

`string`

FFplay arguments without the `ffplay` executable name.

##### timeoutMs?

`number` = `500`

Native startup/operation timeout in milliseconds.

#### Returns

[`FFplaySession`](FFplaySession.md)

***

### createSessionFromArguments()

> `static` **createSessionFromArguments**(`arguments_`, `timeoutMs?`): [`FFplaySession`](FFplaySession.md)

Creates a playback session from pre-tokenized FFplay arguments.

#### Parameters

##### arguments\_

readonly `string`[]

##### timeoutMs?

`number` = `500`

#### Returns

[`FFplaySession`](FFplaySession.md)

***

### execute()

> `static` **execute**(`command`, `options?`, `timeoutMs?`): `Promise`\<[`FFplaySession`](FFplaySession.md)\>

Alias of `executeAsync()`; resolves when playback ends or is stopped.

#### Parameters

##### command

`string`

##### options?

[`ExecuteOptions`](../interfaces/ExecuteOptions.md)\<[`FFplaySession`](FFplaySession.md)\> = `{}`

##### timeoutMs?

`number` = `500`

#### Returns

`Promise`\<[`FFplaySession`](FFplaySession.md)\>

***

### executeAsync()

> `static` **executeAsync**(`command`, `options?`, `timeoutMs?`): `Promise`\<[`FFplaySession`](FFplaySession.md)\>

Creates, marks active, queues, and starts an FFplay session.

The promise normally remains pending for the playback lifetime. Keep the
session from `createSession()` when controls are needed before completion,
or read `currentSession` after calling this method. The current global
control owner is the newest submitted high-level FFplay session whose
execution Promise remains unsettled. When that newest session settles,
control falls back to the next newest unsettled session. Retain an
explicitly created `FFplaySession` when controlling a particular playback
identity.

#### Parameters

##### command

`string`

##### options?

[`ExecuteOptions`](../interfaces/ExecuteOptions.md)\<[`FFplaySession`](FFplaySession.md)\> = `{}`

##### timeoutMs?

`number` = `500`

#### Returns

`Promise`\<[`FFplaySession`](FFplaySession.md)\>

***

### getCurrentSession()

> `static` **getCurrentSession**(): [`FFplaySession`](FFplaySession.md) \| `undefined`

Returns the most recently submitted high-level FFplay session whose
`executeAsync()` Promise has not yet settled.

#### Returns

[`FFplaySession`](FFplaySession.md) \| `undefined`

***

### getFFplaySessions()

> `static` **getFFplaySessions**(): [`FFplaySession`](FFplaySession.md)[]

Returns FFplay sessions currently retained in native history.

#### Returns

[`FFplaySession`](FFplaySession.md)[]

***

### hasVideoStream()

> `static` **hasVideoStream**(`path`): `boolean`

Synchronously checks whether an input contains a video stream.

Use this to decide whether a visible `FFplayView` is required before
starting playback.

#### Parameters

##### path

`string`

#### Returns

`boolean`
