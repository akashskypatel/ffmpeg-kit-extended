[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / NativeFFmpegKitExtendedSpec

# Type Alias: NativeFFmpegKitExtendedSpec

> **NativeFFmpegKitExtendedSpec** = `object`

Stable native-only contract for advanced integrations and diagnostics.

Most applications should use the high-level wrappers. Direct use requires
the caller to preserve session lifetime, retained-handle, callback-demand,
and history rules normally owned by those wrappers. This explicit contract
keeps the complete low-level method inventory visible to generated docs
without adding a JavaScript export or changing Codegen's parser-compatible
declaration.
The runtime module is exported from the native entry point only; Web has no
native module value.

## Properties

### onLogEvent

> `readonly` **onLogEvent**: `EventEmitter`\<[`NativeFFmpegKitExtendedLogEvent`](NativeFFmpegKitExtendedLogEvent.md)\>

Receives structured native log events.

## Methods

### abandonCreatedSession()

> **abandonCreatedSession**(`sessionId`): `Promise`\<`void`\>

Removes wrapper history for a queued session discarded before execution.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### cancelSession()

> **cancelSession**(`sessionId`): `Promise`\<`void`\>

Requests cancellation of a native session.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### clearDebugLog()

> **clearDebugLog**(`sessionId`): `Promise`\<`void`\>

Clears the per-session native debug log.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### clearSessions()

> **clearSessions**(): `Promise`\<`void`\>

Clears retained native session history.

#### Returns

`Promise`\<`void`\>

***

### closeFFmpegPipe()

> **closeFFmpegPipe**(`path`): `Promise`\<`void`\>

Closes a native FFmpeg pipe path.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`void`\>

***

### consumeSynchronousError()

> **consumeSynchronousError**(): `string`

Consumes a synchronous Windows result diagnostic from the same call boundary.

#### Returns

`string`

***

### createFFmpegSession()

> **createFFmpegSession**(`command`): `number`

Creates an FFmpeg session from a command string.

#### Parameters

##### command

`string`

#### Returns

`number`

***

### createFFmpegSessionFromArguments()

> **createFFmpegSessionFromArguments**(`arguments_`): `number`

Creates an FFmpeg session from pre-tokenized arguments.

#### Parameters

##### arguments\_

readonly `string`[]

#### Returns

`number`

***

### createFFplaySession()

> **createFFplaySession**(`command`): `number`

Creates an FFplay session from a command string.

#### Parameters

##### command

`string`

#### Returns

`number`

***

### createFFplaySessionFromArguments()

> **createFFplaySessionFromArguments**(`arguments_`): `number`

Creates an FFplay session from pre-tokenized arguments.

#### Parameters

##### arguments\_

readonly `string`[]

#### Returns

`number`

***

### createFFprobeSession()

> **createFFprobeSession**(`command`): `number`

Creates an FFprobe session from a command string.

#### Parameters

##### command

`string`

#### Returns

`number`

***

### createMediaInformationSession()

> **createMediaInformationSession**(`command`): `number`

Creates a media-information session from a command string.

#### Parameters

##### command

`string`

#### Returns

`number`

***

### createMediaInformationSessionFromPath()

> **createMediaInformationSessionFromPath**(`path`): `number`

Creates a media-information session for a path.

#### Parameters

##### path

`string`

#### Returns

`number`

***

### disableDebugLog()

> **disableDebugLog**(`sessionId`): `Promise`\<`void`\>

Disables per-session native debug logging.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### disableRedirection()

> **disableRedirection**(): `Promise`\<`void`\>

Disables process-wide output redirection.

#### Returns

`Promise`\<`void`\>

***

### enableDebugLog()

> **enableDebugLog**(`sessionId`): `Promise`\<`void`\>

Enables per-session native debug logging.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### enableRedirection()

> **enableRedirection**(): `Promise`\<`void`\>

Enables process-wide output redirection.

#### Returns

`Promise`\<`void`\>

***

### executeSessionAsync()

> **executeSessionAsync**(`sessionId`, `timeoutMs`): `Promise`\<`void`\>

Executes a native session asynchronously with a millisecond timeout.

#### Parameters

##### sessionId

`number`

##### timeoutMs

`number`

#### Returns

`Promise`\<`void`\>

***

### ffplayGetDuration()

> **ffplayGetDuration**(`sessionId`): `number`

Returns the FFplay duration in seconds.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### ffplayGetPosition()

> **ffplayGetPosition**(`sessionId`): `number`

Returns the FFplay position in seconds.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### ffplayGetVideoHeight()

> **ffplayGetVideoHeight**(`sessionId`): `number`

Returns the FFplay video height in pixels.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### ffplayGetVideoWidth()

> **ffplayGetVideoWidth**(`sessionId`): `number`

Returns the FFplay video width in pixels.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### ffplayGetVolume()

> **ffplayGetVolume**(`sessionId`): `number`

Returns the current FFplay volume.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### ffplayHasVideoStream()

> **ffplayHasVideoStream**(`path`): `boolean`

Reports whether a media path has a video stream.

#### Parameters

##### path

`string`

#### Returns

`boolean`

***

### ffplayIsPaused()

> **ffplayIsPaused**(`sessionId`): `boolean`

Reports whether FFplay is currently paused.

#### Parameters

##### sessionId

`number`

#### Returns

`boolean`

***

### ffplayIsPlaying()

> **ffplayIsPlaying**(`sessionId`): `boolean`

Reports whether FFplay is currently playing.

#### Parameters

##### sessionId

`number`

#### Returns

`boolean`

***

### ffplayPause()

> **ffplayPause**(`sessionId`): `Promise`\<`void`\>

Pauses FFplay for one session.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### ffplayResume()

> **ffplayResume**(`sessionId`): `Promise`\<`void`\>

Resumes FFplay for one session.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### ffplaySeek()

> **ffplaySeek**(`sessionId`, `seconds`): `Promise`\<`void`\>

Seeks FFplay to a position in seconds.

#### Parameters

##### sessionId

`number`

##### seconds

`number`

#### Returns

`Promise`\<`void`\>

***

### ffplaySetPosition()

> **ffplaySetPosition**(`sessionId`, `seconds`): `Promise`\<`void`\>

Sets the FFplay position in seconds.

#### Parameters

##### sessionId

`number`

##### seconds

`number`

#### Returns

`Promise`\<`void`\>

***

### ffplaySetVolume()

> **ffplaySetVolume**(`sessionId`, `volume`): `Promise`\<`void`\>

Sets FFplay volume as a normalized numeric value.

#### Parameters

##### sessionId

`number`

##### volume

`number`

#### Returns

`Promise`\<`void`\>

***

### ffplayStart()

> **ffplayStart**(`sessionId`): `Promise`\<`void`\>

Starts FFplay for one session.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### ffplayStop()

> **ffplayStop**(`sessionId`): `Promise`\<`void`\>

Stops FFplay for one session.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### getBuildConfiguration()

> **getBuildConfiguration**(): `string`

Returns the native build configuration.

#### Returns

`string`

***

### getBuildDate()

> **getBuildDate**(): `string`

Returns the native build date.

#### Returns

`string`

***

### getBuildStamp()

> **getBuildStamp**(): `string`

Returns the wrapper/native build stamp.

#### Returns

`string`

***

### getBundleType()

> **getBundleType**(): `string`

Returns the native bundle type.

#### Returns

`string`

***

### getDebugLog()

> **getDebugLog**(`sessionId`): `string`

Returns the per-session native debug log.

#### Parameters

##### sessionId

`number`

#### Returns

`string`

***

### getExternalLibraries()

> **getExternalLibraries**(): `string`

Returns the compiled external-library inventory.

#### Returns

`string`

***

### getFFmpegArchitecture()

> **getFFmpegArchitecture**(): `string`

Returns the bundled FFmpeg architecture.

#### Returns

`string`

***

### getFFmpegVersion()

> **getFFmpegVersion**(): `string`

Returns the bundled FFmpeg version.

#### Returns

`string`

***

### getLastSessionJson()

> **getLastSessionJson**(`kind`): `string`

Returns the latest session snapshot for a kind as serialized JSON.

#### Parameters

##### kind

`string`

#### Returns

`string`

***

### getLogLevel()

> **getLogLevel**(): `number`

Returns the native log level.

#### Returns

`number`

***

### getLogsCount()

> **getLogsCount**(`sessionId`): `number`

Returns the retained native log count for one session.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### getLogsJson()

> **getLogsJson**(`sessionId`, `fromIndex`): `string`

Returns serialized log entries from a session starting at an index.

#### Parameters

##### sessionId

`number`

##### fromIndex

`number`

#### Returns

`string`

***

### getMediaInformationJson()

> **getMediaInformationJson**(`sessionId`): `string`

Returns serialized media information for one session.

#### Parameters

##### sessionId

`number`

#### Returns

`string`

***

### getPackageName()

> **getPackageName**(): `string`

Returns the native package name.

#### Returns

`string`

***

### getRegisteredBitstreamFilters()

> **getRegisteredBitstreamFilters**(): `string`

Returns registered bitstream-filter names as serialized JSON.

#### Returns

`string`

***

### getRegisteredCodecs()

> **getRegisteredCodecs**(): `string`

Returns registered codec names as serialized JSON.

#### Returns

`string`

***

### getRegisteredDecoders()

> **getRegisteredDecoders**(): `string`

Returns registered decoder names as serialized JSON.

#### Returns

`string`

***

### getRegisteredDemuxers()

> **getRegisteredDemuxers**(): `string`

Returns registered demuxer names as serialized JSON.

#### Returns

`string`

***

### getRegisteredEncoders()

> **getRegisteredEncoders**(): `string`

Returns registered encoder names as serialized JSON.

#### Returns

`string`

***

### getRegisteredFilters()

> **getRegisteredFilters**(): `string`

Returns registered filter names as serialized JSON.

#### Returns

`string`

***

### getRegisteredMuxers()

> **getRegisteredMuxers**(): `string`

Returns registered muxer names as serialized JSON.

#### Returns

`string`

***

### getRegisteredProtocols()

> **getRegisteredProtocols**(): `string`

Returns registered protocol names as serialized JSON.

#### Returns

`string`

***

### getSessionHistorySize()

> **getSessionHistorySize**(): `number`

Returns the retained native session-history size.

#### Returns

`number`

***

### getSessionJson()

> **getSessionJson**(`sessionId`): `string`

Returns one session snapshot as serialized JSON.

#### Parameters

##### sessionId

`number`

#### Returns

`string`

***

### getSessionsJson()

> **getSessionsJson**(`kind`): `string`

Returns session snapshots for a kind as serialized JSON.

#### Parameters

##### kind

`string`

#### Returns

`string`

***

### getSessionState()

> **getSessionState**(`sessionId`): `number`

Returns the native lifecycle state for one session.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### getStatisticsJson()

> **getStatisticsJson**(`sessionId`, `fromIndex`): `string`

Returns serialized statistics from a session starting at an index.

#### Parameters

##### sessionId

`number`

##### fromIndex

`number`

#### Returns

`string`

***

### getVersion()

> **getVersion**(): `string`

Returns the wrapper version.

#### Returns

`string`

***

### ignoreSignal()

> **ignoreSignal**(`signal`): `Promise`\<`void`\>

Configures one native signal to be ignored.

#### Parameters

##### signal

`number`

#### Returns

`Promise`\<`void`\>

***

### initialize()

> **initialize**(): `Promise`\<`void`\>

Initializes the native library selected by the consuming app configuration.

#### Returns

`Promise`\<`void`\>

***

### installLogBridge()

> **installLogBridge**(): `Promise`\<`void`\>

Installs the process-wide structured log bridge.

#### Returns

`Promise`\<`void`\>

***

### isDebugLogEnabled()

> **isDebugLogEnabled**(`sessionId`): `boolean`

Reports whether per-session native debug logging is enabled.

#### Parameters

##### sessionId

`number`

#### Returns

`boolean`

***

### isGpl()

> **isGpl**(): `boolean`

Reports whether the bundle includes GPL components.

#### Returns

`boolean`

***

### isNonfree()

> **isNonfree**(): `boolean`

Reports whether the bundle includes non-free components.

#### Returns

`boolean`

***

### listAudioOutputDevices()

> **listAudioOutputDevices**(): `string`

Returns available native audio output devices as serialized JSON.

#### Returns

`string`

***

### logLevelToString()

> **logLevelToString**(`level`): `string`

Converts a native log level to display text.

#### Parameters

##### level

`number`

#### Returns

`string`

***

### messagesInTransmit()

> **messagesInTransmit**(`sessionId`): `number`

Returns the number of messages currently in transmission.

#### Parameters

##### sessionId

`number`

#### Returns

`number`

***

### registerNewFFmpegPipe()

> **registerNewFFmpegPipe**(): `string`

Registers and returns a native FFmpeg pipe path.

#### Returns

`string`

***

### releaseSessionHandle()

> **releaseSessionHandle**(`sessionId`): `Promise`\<`void`\>

Releases the retained native handle for one session.

#### Parameters

##### sessionId

`number`

#### Returns

`Promise`\<`void`\>

***

### setAudioOutputDevice()

> **setAudioOutputDevice**(`deviceName`): `Promise`\<`void`\>

Selects the native audio output device.

#### Parameters

##### deviceName

`string`

#### Returns

`Promise`\<`void`\>

***

### setEnvironmentVariable()

> **setEnvironmentVariable**(`name`, `value`): `Promise`\<`void`\>

Sets one native environment variable.

#### Parameters

##### name

`string`

##### value

`string`

#### Returns

`Promise`\<`void`\>

***

### setFontDirectory()

> **setFontDirectory**(`path`, `mappingJson`): `Promise`\<`void`\>

Sets the native font directory and mapping JSON.

#### Parameters

##### path

`string`

##### mappingJson

`string`

#### Returns

`Promise`\<`void`\>

***

### setLogLevel()

> **setLogLevel**(`level`): `Promise`\<`void`\>

Sets the native log level.

#### Parameters

##### level

`number`

#### Returns

`Promise`\<`void`\>

***

### setSessionHistorySize()

> **setSessionHistorySize**(`size`): `Promise`\<`void`\>

Sets the retained native session-history size.

#### Parameters

##### size

`number`

#### Returns

`Promise`\<`void`\>

***

### uninstallLogBridge()

> **uninstallLogBridge**(): `Promise`\<`void`\>

Removes the process-wide structured log bridge.

#### Returns

`Promise`\<`void`\>
