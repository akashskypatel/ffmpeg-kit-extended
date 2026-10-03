[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFmpegKitExtended

# Class: FFmpegKitExtended

Central lifecycle, session-history, build-introspection, and native utility
facade.

Call `initialize()` near application startup before invoking FFmpegKit APIs.
Successful initialization is idempotent, and failed attempts can be retried.
Most command execution should go through `FFmpegKit`, `FFprobeKit`, or
`FFplayKit`; the session factory methods here are useful for framework-style
integrations.

## Constructors

### Constructor

> **new FFmpegKitExtended**(): `FFmpegKitExtended`

#### Returns

`FFmpegKitExtended`

## Accessors

### initialized

#### Get Signature

> **get** `static` **initialized**(): `boolean`

Whether `initialize()` has completed in this JavaScript runtime.

##### Returns

`boolean`

## Methods

### cancelAllSessions()

> `static` **cancelAllSessions**(): `Promise`\<`void`\>

Clears queued work and requests cancellation of all active sessions.
Queue cleanup and active delivery start together; the returned promise
settles only after every initiated branch has settled.

#### Returns

`Promise`\<`void`\>

***

### cancelSession()

> `static` **cancelSession**(`sessionId`): `Promise`\<`void`\>

Requests queue-aware cancellation by session ID.

ID `0` cancels all queued and active managed sessions. A matching managed
session uses the same durable-intent transaction as object cancellation;
an unsubmitted history wrapper is used only when no managed object exists.
Missing IDs are compatibility no-ops, while lookup/state/native failures for
an existing identity are propagated to the caller.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### clearSessions()

> `static` **clearSessions**(): `Promise`\<`void`\>

Clears the native session registry and retained session history.

Do not call this while sessions are running. Clearing sessions can
cancel/invalidate active session handles, and Session getters for cleared
IDs may subsequently fail.

#### Returns

`Promise`\<`void`\>

***

### closeFFmpegPipe()

> `static` **closeFFmpegPipe**(`path`): `Promise`\<`void`\>

Closes/removes a pipe created by `registerNewFFmpegPipe()`.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`void`\>

***

### createFFmpegSession()

> `static` **createFFmpegSession**(`command`): [`FFmpegSession`](FFmpegSession.md)

Creates an unstarted FFmpeg processing session.

#### Parameters

##### command

`string`

#### Returns

[`FFmpegSession`](FFmpegSession.md)

***

### createFFplaySession()

> `static` **createFFplaySession**(`command`, `timeoutMs?`): [`FFplaySession`](FFplaySession.md)

Creates an unstarted FFplay session with a native timeout in milliseconds.

#### Parameters

##### command

`string`

##### timeoutMs?

`number` = `500`

#### Returns

[`FFplaySession`](FFplaySession.md)

***

### createFFprobeSession()

> `static` **createFFprobeSession**(`command`): [`FFprobeSession`](FFprobeSession.md)

Creates an unstarted FFprobe command session.

#### Parameters

##### command

`string`

#### Returns

[`FFprobeSession`](FFprobeSession.md)

***

### createMediaInformationSession()

> `static` **createMediaInformationSession**(`command`, `timeoutMs?`): [`MediaInformationSession`](MediaInformationSession.md)

Creates an unstarted structured media-information session from a complete
FFprobe command string.

#### Parameters

##### command

`string`

##### timeoutMs?

`number` = `500`

#### Returns

[`MediaInformationSession`](MediaInformationSession.md)

***

### disableRedirection()

> `static` **disableRedirection**(): `Promise`\<`void`\>

Disables native log redirection.

#### Returns

`Promise`\<`void`\>

***

### enableRedirection()

> `static` **enableRedirection**(): `Promise`\<`void`\>

Enables native log redirection used by per-session callbacks.

#### Returns

`Promise`\<`void`\>

***

### getBuildConfiguration()

> `static` **getBuildConfiguration**(): `string`

Returns the upstream FFmpeg configure command/options.

#### Returns

`string`

***

### getBuildDate()

> `static` **getBuildDate**(): `string`

Returns the native bundle build date text.

#### Returns

`string`

***

### getBuildStamp()

> `static` **getBuildStamp**(): `string`

Returns the native bundle build stamp used for diagnostics.

#### Returns

`string`

***

### getBundleType()

> `static` **getBundleType**(): `string`

Returns the selected bundle type, such as shared/static build metadata.

#### Returns

`string`

***

### getExternalLibraries()

> `static` **getExternalLibraries**(): `string`

Lists external libraries enabled in the selected native bundle.

#### Returns

`string`

***

### getFFmpegArchitecture()

> `static` **getFFmpegArchitecture**(): `string`

Returns the architecture reported by the native FFmpeg build.

#### Returns

`string`

***

### getFFmpegSessions()

> `static` **getFFmpegSessions**(): [`FFmpegSession`](FFmpegSession.md)[]

Returns retained FFmpeg processing sessions.

#### Returns

[`FFmpegSession`](FFmpegSession.md)[]

***

### getFFmpegVersion()

> `static` **getFFmpegVersion**(): `string`

Returns the bundled upstream FFmpeg version.

#### Returns

`string`

***

### getFFplaySessions()

> `static` **getFFplaySessions**(): [`FFplaySession`](FFplaySession.md)[]

Returns retained FFplay sessions.

#### Returns

[`FFplaySession`](FFplaySession.md)[]

***

### getFFprobeSessions()

> `static` **getFFprobeSessions**(): [`FFprobeSession`](FFprobeSession.md)[]

Returns retained FFprobe command sessions.

#### Returns

[`FFprobeSession`](FFprobeSession.md)[]

***

### getLastFFmpegSession()

> `static` **getLastFFmpegSession**(): [`FFmpegSession`](FFmpegSession.md) \| `undefined`

Returns the newest retained FFmpeg session.

#### Returns

[`FFmpegSession`](FFmpegSession.md) \| `undefined`

***

### getLastFFplaySession()

> `static` **getLastFFplaySession**(): [`FFplaySession`](FFplaySession.md) \| `undefined`

Returns the newest retained FFplay session.

#### Returns

[`FFplaySession`](FFplaySession.md) \| `undefined`

***

### getLastFFprobeSession()

> `static` **getLastFFprobeSession**(): [`FFprobeSession`](FFprobeSession.md) \| `undefined`

Returns the newest retained FFprobe session.

#### Returns

[`FFprobeSession`](FFprobeSession.md) \| `undefined`

***

### getLastMediaInformationSession()

> `static` **getLastMediaInformationSession**(): [`MediaInformationSession`](MediaInformationSession.md) \| `undefined`

Returns the newest retained media-information session.

#### Returns

[`MediaInformationSession`](MediaInformationSession.md) \| `undefined`

***

### getLastSession()

> `static` **getLastSession**(): [`Session`](Session.md) \| `undefined`

Returns the newest retained session of any type.

#### Returns

[`Session`](Session.md) \| `undefined`

***

### getLogLevel()

> `static` **getLogLevel**(): [`LogLevel`](../enumerations/LogLevel.md)

Returns the process-wide FFmpeg log level.

#### Returns

[`LogLevel`](../enumerations/LogLevel.md)

***

### getMediaInformationSessions()

> `static` **getMediaInformationSessions**(): [`MediaInformationSession`](MediaInformationSession.md)[]

Returns retained structured media-information sessions.

#### Returns

[`MediaInformationSession`](MediaInformationSession.md)[]

***

### getPackageName()

> `static` **getPackageName**(): `string`

Returns the configured native package name.

#### Returns

`string`

***

### getRegisteredBitstreamFilters()

> `static` **getRegisteredBitstreamFilters**(): `string`

Returns the native FFmpeg bitstream-filter registry text.

#### Returns

`string`

***

### getRegisteredCodecs()

> `static` **getRegisteredCodecs**(): `string`

Returns the native FFmpeg codec registry text.

#### Returns

`string`

***

### getRegisteredDecoders()

> `static` **getRegisteredDecoders**(): `string`

Returns the native FFmpeg decoder registry text.

#### Returns

`string`

***

### getRegisteredDemuxers()

> `static` **getRegisteredDemuxers**(): `string`

Returns the native FFmpeg demuxer registry text.

#### Returns

`string`

***

### getRegisteredEncoders()

> `static` **getRegisteredEncoders**(): `string`

Returns the native FFmpeg encoder registry text.

#### Returns

`string`

***

### getRegisteredFilters()

> `static` **getRegisteredFilters**(): `string`

Returns the native FFmpeg filter registry text.

#### Returns

`string`

***

### getRegisteredMuxers()

> `static` **getRegisteredMuxers**(): `string`

Returns the native FFmpeg muxer registry text.

#### Returns

`string`

***

### getRegisteredProtocols()

> `static` **getRegisteredProtocols**(): `string`

Returns the native FFmpeg protocol registry text.

#### Returns

`string`

***

### getSession()

> `static` **getSession**(`sessionId`): [`Session`](Session.md) \| `undefined`

Looks up one retained session by ID.

#### Parameters

##### sessionId

`number`

#### Returns

[`Session`](Session.md) \| `undefined`

***

### getSessionHistorySize()

> `static` **getSessionHistorySize**(): `number`

Returns the native session-history capacity.

#### Returns

`number`

***

### getSessions()

> `static` **getSessions**(): [`Session`](Session.md)[]

Returns all sessions retained in native history.

#### Returns

[`Session`](Session.md)[]

***

### getVersion()

> `static` **getVersion**(): `string`

Returns the FFmpegKit Extended wrapper version.

#### Returns

`string`

***

### ignoreSignal()

> `static` **ignoreSignal**(`signal`): `Promise`\<`void`\>

Configures the native runtime to ignore a supported signal.

#### Parameters

##### signal

[`Signal`](../enumerations/Signal.md)

#### Returns

`Promise`\<`void`\>

***

### initialize()

> `static` **initialize**(`options?`): `Promise`\<`void`\>

Loads and initializes the configured native FFmpegKit bundle.
Repeated calls are ignored after successful JavaScript initialization.

#### Parameters

##### options?

[`FFmpegKitInitializeOptions`](../interfaces/FFmpegKitInitializeOptions.md)

#### Returns

`Promise`\<`void`\>

***

### isGpl()

> `static` **isGpl**(): `boolean`

Whether the selected native bundle includes GPL components.

#### Returns

`boolean`

***

### isNonfree()

> `static` **isNonfree**(): `boolean`

Whether the selected native bundle includes nonfree components.

#### Returns

`boolean`

***

### listAudioOutputDevices()

> `static` **listAudioOutputDevices**(): `string`

Lists native audio output devices in backend-defined text form.

#### Returns

`string`

***

### listSessions()

> `static` **listSessions**(): [`Session`](Session.md)[]

Alias of `getSessions()`.

#### Returns

[`Session`](Session.md)[]

***

### messagesInTransmit()

> `static` **messagesInTransmit**(`sessionId`): `number`

Returns native callback messages still in transit for a session.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### registerNewFFmpegPipe()

> `static` **registerNewFFmpegPipe**(): `string` \| `undefined`

Creates a native FFmpeg FIFO/pipe and returns its path when supported.

#### Returns

`string` \| `undefined`

***

### requireInitialized()

> `static` **requireInitialized**(): `void`

Throws a descriptive error when initialization has not occurred.

#### Returns

`void`

***

### setAudioOutputDevice()

> `static` **setAudioOutputDevice**(`deviceName`): `Promise`\<`void`\>

Selects a native audio output device by backend-provided name.

#### Parameters

##### deviceName

`string`

#### Returns

`Promise`\<`void`\>

***

### setEnvironmentVariable()

> `static` **setEnvironmentVariable**(`name`, `value`): `Promise`\<`void`\>

Sets a native environment variable for FFmpeg and linked libraries.

#### Parameters

##### name

`string`

##### value

`string`

#### Returns

`Promise`\<`void`\>

***

### setFontDirectory()

> `static` **setFontDirectory**(`path`, `mapping?`): `Promise`\<`void`\>

Registers fonts for FFmpeg filters, with an optional family-to-file map.

#### Parameters

##### path

`string`

##### mapping?

`Record`\<`string`, `string`\>

#### Returns

`Promise`\<`void`\>

***

### setLogLevel()

> `static` **setLogLevel**(`level`): `Promise`\<`void`\>

Sets the process-wide FFmpeg log level.

#### Parameters

##### level

[`LogLevel`](../enumerations/LogLevel.md)

#### Returns

`Promise`\<`void`\>

***

### setSessionHistorySize()

> `static` **setSessionHistorySize**(`size`): `Promise`\<`void`\>

Sets the number of sessions retained in native history.

#### Parameters

##### size

`number`

#### Returns

`Promise`\<`void`\>
