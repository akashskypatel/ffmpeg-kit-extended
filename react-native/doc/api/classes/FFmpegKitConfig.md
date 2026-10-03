[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFmpegKitConfig

# Class: FFmpegKitConfig

Global FFmpegKit runtime configuration and utility methods.

Settings apply process-wide and affect subsequently executed sessions. Call
`FFmpegKitExtended.initialize()` before using native configuration methods.

## Methods

### argumentsToString()

> `static` **argumentsToString**(`arguments_`): `string`

Quotes pre-tokenized arguments as one FFmpegKit command string.

#### Parameters

##### arguments\_

readonly `string`[]

#### Returns

`string`

***

### clearSessions()

> `static` **clearSessions**(): `Promise`\<`void`\>

Clears the native session registry and retained session history using the
same lifecycle-aware transaction as `FFmpegKitExtended.clearSessions()`.

After the backend clear succeeds, restored observer/callback state and
cancellation-delivery bookkeeping are invalidated. Do not call this while
sessions are running. Clearing sessions can cancel/invalidate active
session handles, and Session getters for cleared IDs may subsequently fail.

#### Returns

`Promise`\<`void`\>

***

### closeFFmpegPipe()

> `static` **closeFFmpegPipe**(`path`): `Promise`\<`void`\>

Closes and removes a pipe created by `registerNewFFmpegPipe()`.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`void`\>

***

### disableRedirection()

> `static` **disableRedirection**(): `Promise`\<`void`\>

Explicitly disables process-wide native log redirection.

This is authoritative even when a session has an optional log consumer;
completion transport remains independent of log/statistics delivery.

#### Returns

`Promise`\<`void`\>

***

### enableRedirection()

> `static` **enableRedirection**(): `Promise`\<`void`\>

Explicitly enables process-wide native log redirection.

Installing an internal completion/log/statistics bridge does not call this
method implicitly; the native redirection setting remains user authority.

#### Returns

`Promise`\<`void`\>

***

### getFFmpegVersion()

> `static` **getFFmpegVersion**(): `string`

Returns the bundled upstream FFmpeg version.

#### Returns

`string`

***

### getLogLevel()

> `static` **getLogLevel**(): [`LogLevel`](../enumerations/LogLevel.md)

Returns the current process-wide FFmpeg log level.

#### Returns

[`LogLevel`](../enumerations/LogLevel.md)

***

### getMaxConcurrentSessions()

> `static` **getMaxConcurrentSessions**(): `number`

Returns the JavaScript session queue concurrency limit.

#### Returns

`number`

***

### getPackageName()

> `static` **getPackageName**(): `string`

Returns the selected native package/bundle name.

#### Returns

`string`

***

### getSessionHistorySize()

> `static` **getSessionHistorySize**(): `number`

Returns the native session-history capacity.

#### Returns

`number`

***

### getVersion()

> `static` **getVersion**(): `string`

Returns the FFmpegKit Extended wrapper version.

#### Returns

`string`

***

### ignoreSignal()

> `static` **ignoreSignal**(`signal`): `Promise`\<`void`\>

Configures the native runtime to ignore one supported process signal.

#### Parameters

##### signal

[`Signal`](../enumerations/Signal.md)

#### Returns

`Promise`\<`void`\>

***

### listAudioOutputDevices()

> `static` **listAudioOutputDevices**(): `string`

Returns native audio output devices in the wrapper's serialized text form.
The exact device names and formatting are platform/backend dependent.

#### Returns

`string`

***

### logLevelToString()

> `static` **logLevelToString**(`level`): `string`

Converts a numeric `LogLevel` to the native display name.

#### Parameters

##### level

[`LogLevel`](../enumerations/LogLevel.md)

#### Returns

`string`

***

### messagesInTransmit()

> `static` **messagesInTransmit**(`sessionId`): `number`

Returns the count of native log/statistics messages still being delivered
for a session. This is primarily useful for shutdown diagnostics.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### parseArguments()

> `static` **parseArguments**(`command`): `string`[]

Splits a command string using the package's platform-neutral parser.

#### Parameters

##### command

`string`

#### Returns

`string`[]

***

### registerNewFFmpegPipe()

> `static` **registerNewFFmpegPipe**(): `string` \| `undefined`

Creates a named FIFO/pipe path for streaming data into or out of FFmpeg.
Returns `undefined` when the native platform cannot create the pipe.

#### Returns

`string` \| `undefined`

***

### sessionStateToString()

> `static` **sessionStateToString**(`state`): `string`

Returns the enum name for a `SessionState`.

#### Parameters

##### state

[`SessionState`](../enumerations/SessionState.md)

#### Returns

`string`

***

### setAudioOutputDevice()

> `static` **setAudioOutputDevice**(`deviceName`): `Promise`\<`void`\>

Selects the native audio output device by the name returned from
`listAudioOutputDevices()`.

#### Parameters

##### deviceName

`string`

#### Returns

`Promise`\<`void`\>

***

### setEnvironmentVariable()

> `static` **setEnvironmentVariable**(`name`, `value`): `Promise`\<`void`\>

Sets a native environment variable used by FFmpeg and its libraries.

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

Registers a directory for fontconfig-based filters such as `drawtext` and
`subtitles`.

`mapping` optionally maps font family names to filenames in the directory.

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

Sets the minimum process-wide FFmpeg log level.

#### Parameters

##### level

[`LogLevel`](../enumerations/LogLevel.md)

#### Returns

`Promise`\<`void`\>

***

### setMaxConcurrentSessions()

> `static` **setMaxConcurrentSessions**(`value`): `void`

Sets the JavaScript session queue concurrency limit.

#### Parameters

##### value

`number`

#### Returns

`void`

***

### setSessionHistorySize()

> `static` **setSessionHistorySize**(`size`): `Promise`\<`void`\>

Sets the maximum number of completed/created sessions retained natively.
Reducing the value may discard older history entries.

#### Parameters

##### size

`number`

#### Returns

`Promise`\<`void`\>
