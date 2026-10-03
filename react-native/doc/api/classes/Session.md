[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / Session

# Abstract Class: Session

Base wrapper for one native FFmpegKit session.

Session getters read the latest native snapshot on each call. When the v2
event bridge is available, live log delivery is direct and sequence-based;
the monitor does not poll complete log history during steady state. At
terminal state it reads the retained count once and fetches only a bounded
missing range, while the indexed getters remain available for history and v1
compatibility. Keep history entries available until you finish inspecting a
completed session. Calling `FFmpegKitConfig.clearSessions()` while sessions
are running can cancel/invalidate active handles. Clearing sessions can also
make later getters throw because the native session no longer exists.

A Session object may be submitted for execution once. Create a new session
for another execution.

## Extended by

- [`FFmpegSession`](FFmpegSession.md)
- [`FFprobeSession`](FFprobeSession.md)
- [`MediaInformationSession`](MediaInformationSession.md)
- [`FFplaySession`](FFplaySession.md)

## Properties

### command

> `readonly` **command**: `string`

Normalized/original command representation associated with this wrapper.

***

### sessionId

> `readonly` **sessionId**: `number`

Process-unique native identity; it is not persistent across restarts.

***

### type

> `readonly` **type**: [`SessionType`](../type-aliases/SessionType.md)

Session kind: `ffmpeg`, `ffprobe`, `ffplay`, or `media-information`.

## Accessors

### isCancelled

#### Get Signature

> **get** **isCancelled**(): `boolean`

Whether cancellation was requested through this JavaScript object.

##### Returns

`boolean`

## Methods

### cancel()

> **cancel**(): `Promise`\<`void`\>

Records cancellation immediately, then cancels queued work or requests
native cancellation once running. A state-read or native-dispatch failure
does not erase the recorded request, so an executing session can still
deliver it when Running is observed again. Successful never-started
abandonment makes repeated cancellation a no-op; failed cancellation
remains retryable.

#### Returns

`Promise`\<`void`\>

***

### clearDebugLog()

> **clearDebugLog**(): `Promise`\<`void`\>

Clears the session-specific native debug log buffer.

#### Returns

`Promise`\<`void`\>

***

### disableDebugLog()

> **disableDebugLog**(): `Promise`\<`void`\>

Disables additional native debug-log capture for this session.

#### Returns

`Promise`\<`void`\>

***

### enableDebugLog()

> **enableDebugLog**(): `Promise`\<`void`\>

Enables additional native debug-log capture for this session.

#### Returns

`Promise`\<`void`\>

***

### getCommand()

> **getCommand**(): `string`

Returns the command stored by the native session.

#### Returns

`string`

***

### getCreateTime()

> **getCreateTime**(): `Date`

Returns when the native session was created.

#### Returns

`Date`

***

### getDebugLog()

> **getDebugLog**(): `string`

Returns the session-specific native debug log.

#### Returns

`string`

***

### getDuration()

> **getDuration**(): `number`

Returns wall-clock execution duration in milliseconds.

#### Returns

`number`

***

### getEndTime()

> **getEndTime**(): `Date`

Returns when execution ended; may represent epoch before completion.

#### Returns

`Date`

***

### getFailStackTrace()

> **getFailStackTrace**(): `string`

Returns the native failure stack trace when one was recorded.

#### Returns

`string`

***

### getLogsAsString()

> **getLogsAsString**(): `string`

Returns all retained session logs concatenated as text.

#### Returns

`string`

***

### getLogsCount()

> **getLogsCount**(): `number`

Returns the retained log count used for public inspection/reconciliation.

#### Returns

`number`

***

### getOutput()

> **getOutput**(): `string`

Returns the session's combined native console output.

#### Returns

`string`

***

### getReturnCode()

> **getReturnCode**(): `number`

Returns the native exit code; inspect after completion.

#### Returns

`number`

***

### getSessionId()

> **getSessionId**(): `number`

Returns the process-unique native session ID.

#### Returns

`number`

***

### getStartTime()

> **getStartTime**(): `Date`

Returns when native execution started; may represent epoch before start.

#### Returns

`Date`

***

### getState()

> **getState**(): [`SessionState`](../enumerations/SessionState.md)

Returns the current native lifecycle state.

#### Returns

[`SessionState`](../enumerations/SessionState.md)

***

### getStatisticsCount()

> **getStatisticsCount**(): `number`

Returns the number of retained statistics entries.

#### Returns

`number`

***

### isDebugLogEnabled()

> **isDebugLogEnabled**(): `boolean`

Whether additional debug-log capture is enabled for this session.

#### Returns

`boolean`

***

### isFFmpegSession()

> **isFFmpegSession**(): `this is FFmpegSession`

Type guard for FFmpeg processing sessions.

#### Returns

`this is FFmpegSession`

***

### isFFplaySession()

> **isFFplaySession**(): `this is FFplaySession`

Type guard for FFplay sessions.

#### Returns

`this is FFplaySession`

***

### isFFprobeSession()

> **isFFprobeSession**(): `this is FFprobeSession`

Type guard for FFprobe command sessions.

#### Returns

`this is FFprobeSession`

***

### isMediaInformationSession()

> **isMediaInformationSession**(): `this is MediaInformationSession`

Type guard for structured media-information sessions.

#### Returns

`this is MediaInformationSession`
