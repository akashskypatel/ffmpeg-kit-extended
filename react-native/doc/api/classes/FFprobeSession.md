[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFprobeSession

# Class: FFprobeSession

FFprobe command session with completion and log callbacks.

## Extends

- [`Session`](Session.md)

## Constructors

### Constructor

> **new FFprobeSession**(`sessionId`, `command`): `FFprobeSession`

#### Parameters

##### sessionId

`number`

##### command

`string`

#### Returns

`FFprobeSession`

#### Overrides

`Session.constructor`

## Properties

### command

> `readonly` **command**: `string`

Normalized/original command representation associated with this wrapper.

#### Inherited from

[`Session`](Session.md).[`command`](Session.md#command)

***

### sessionId

> `readonly` **sessionId**: `number`

Process-unique native identity; it is not persistent across restarts.

#### Inherited from

[`Session`](Session.md).[`sessionId`](Session.md#sessionid)

***

### type

> `readonly` **type**: [`SessionType`](../type-aliases/SessionType.md)

Session kind: `ffmpeg`, `ffprobe`, `ffplay`, or `media-information`.

#### Inherited from

[`Session`](Session.md).[`type`](Session.md#type)

## Accessors

### isCancelled

#### Get Signature

> **get** **isCancelled**(): `boolean`

Whether cancellation was requested through this JavaScript object.

##### Returns

`boolean`

#### Inherited from

[`Session`](Session.md).[`isCancelled`](Session.md#iscancelled)

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

#### Inherited from

[`Session`](Session.md).[`cancel`](Session.md#cancel)

***

### clearDebugLog()

> **clearDebugLog**(): `Promise`\<`void`\>

Clears the session-specific native debug log buffer.

#### Returns

`Promise`\<`void`\>

#### Inherited from

[`Session`](Session.md).[`clearDebugLog`](Session.md#cleardebuglog)

***

### disableDebugLog()

> **disableDebugLog**(): `Promise`\<`void`\>

Disables additional native debug-log capture for this session.

#### Returns

`Promise`\<`void`\>

#### Inherited from

[`Session`](Session.md).[`disableDebugLog`](Session.md#disabledebuglog)

***

### enableDebugLog()

> **enableDebugLog**(): `Promise`\<`void`\>

Enables additional native debug-log capture for this session.

#### Returns

`Promise`\<`void`\>

#### Inherited from

[`Session`](Session.md).[`enableDebugLog`](Session.md#enabledebuglog)

***

### executeAsync()

> **executeAsync**(`options?`): `Promise`\<`FFprobeSession`\>

Enqueues and executes this FFprobe session.

A Session object may be submitted for execution once. Create a new session
for another execution.

#### Parameters

##### options?

[`ExecuteOptions`](../interfaces/ExecuteOptions.md)\<`FFprobeSession`\> = `{}`

#### Returns

`Promise`\<`FFprobeSession`\>

***

### getCommand()

> **getCommand**(): `string`

Returns the command stored by the native session.

#### Returns

`string`

#### Inherited from

[`Session`](Session.md).[`getCommand`](Session.md#getcommand)

***

### getCreateTime()

> **getCreateTime**(): `Date`

Returns when the native session was created.

#### Returns

`Date`

#### Inherited from

[`Session`](Session.md).[`getCreateTime`](Session.md#getcreatetime)

***

### getDebugLog()

> **getDebugLog**(): `string`

Returns the session-specific native debug log.

#### Returns

`string`

#### Inherited from

[`Session`](Session.md).[`getDebugLog`](Session.md#getdebuglog)

***

### getDuration()

> **getDuration**(): `number`

Returns wall-clock execution duration in milliseconds.

#### Returns

`number`

#### Inherited from

[`Session`](Session.md).[`getDuration`](Session.md#getduration)

***

### getEndTime()

> **getEndTime**(): `Date`

Returns when execution ended; may represent epoch before completion.

#### Returns

`Date`

#### Inherited from

[`Session`](Session.md).[`getEndTime`](Session.md#getendtime)

***

### getFailStackTrace()

> **getFailStackTrace**(): `string`

Returns the native failure stack trace when one was recorded.

#### Returns

`string`

#### Inherited from

[`Session`](Session.md).[`getFailStackTrace`](Session.md#getfailstacktrace)

***

### getLogsAsString()

> **getLogsAsString**(): `string`

Returns all retained session logs concatenated as text.

#### Returns

`string`

#### Inherited from

[`Session`](Session.md).[`getLogsAsString`](Session.md#getlogsasstring)

***

### getLogsCount()

> **getLogsCount**(): `number`

Returns the retained log count used for public inspection/reconciliation.

#### Returns

`number`

#### Inherited from

[`Session`](Session.md).[`getLogsCount`](Session.md#getlogscount)

***

### getOutput()

> **getOutput**(): `string`

Returns the session's combined native console output.

#### Returns

`string`

#### Inherited from

[`Session`](Session.md).[`getOutput`](Session.md#getoutput)

***

### getReturnCode()

> **getReturnCode**(): `number`

Returns the native exit code; inspect after completion.

#### Returns

`number`

#### Inherited from

[`Session`](Session.md).[`getReturnCode`](Session.md#getreturncode)

***

### getSessionId()

> **getSessionId**(): `number`

Returns the process-unique native session ID.

#### Returns

`number`

#### Inherited from

[`Session`](Session.md).[`getSessionId`](Session.md#getsessionid)

***

### getStartTime()

> **getStartTime**(): `Date`

Returns when native execution started; may represent epoch before start.

#### Returns

`Date`

#### Inherited from

[`Session`](Session.md).[`getStartTime`](Session.md#getstarttime)

***

### getState()

> **getState**(): [`SessionState`](../enumerations/SessionState.md)

Returns the current native lifecycle state.

#### Returns

[`SessionState`](../enumerations/SessionState.md)

#### Inherited from

[`Session`](Session.md).[`getState`](Session.md#getstate)

***

### getStatisticsCount()

> **getStatisticsCount**(): `number`

Returns the number of retained statistics entries.

#### Returns

`number`

#### Inherited from

[`Session`](Session.md).[`getStatisticsCount`](Session.md#getstatisticscount)

***

### isDebugLogEnabled()

> **isDebugLogEnabled**(): `boolean`

Whether additional debug-log capture is enabled for this session.

#### Returns

`boolean`

#### Inherited from

[`Session`](Session.md).[`isDebugLogEnabled`](Session.md#isdebuglogenabled)

***

### isFFmpegSession()

> **isFFmpegSession**(): `this is FFmpegSession`

Type guard for FFmpeg processing sessions.

#### Returns

`this is FFmpegSession`

#### Inherited from

[`Session`](Session.md).[`isFFmpegSession`](Session.md#isffmpegsession)

***

### isFFplaySession()

> **isFFplaySession**(): `this is FFplaySession`

Type guard for FFplay sessions.

#### Returns

`this is FFplaySession`

#### Inherited from

[`Session`](Session.md).[`isFFplaySession`](Session.md#isffplaysession)

***

### isFFprobeSession()

> **isFFprobeSession**(): `this is FFprobeSession`

Type guard for FFprobe command sessions.

#### Returns

`this is FFprobeSession`

#### Inherited from

[`Session`](Session.md).[`isFFprobeSession`](Session.md#isffprobesession)

***

### isMediaInformationSession()

> **isMediaInformationSession**(): `this is MediaInformationSession`

Type guard for structured media-information sessions.

#### Returns

`this is MediaInformationSession`

#### Inherited from

[`Session`](Session.md).[`isMediaInformationSession`](Session.md#ismediainformationsession)

***

### removeCompleteCallback()

> **removeCompleteCallback**(): `void`

Removes the stored completion callback.

#### Returns

`void`

***

### removeLogCallback()

> **removeLogCallback**(): `Promise`\<`void`\>

Removes the stored log callback.

#### Returns

`Promise`\<`void`\>

***

### setCompleteCallback()

> **setCompleteCallback**(`callback?`): `void`

Sets the default completion callback.

#### Parameters

##### callback?

(`session`) => `void`

#### Returns

`void`

***

### setLogCallback()

> **setLogCallback**(`callback?`): `Promise`\<`void`\>

Sets the default log callback.

#### Parameters

##### callback?

(`log`, `session`) => `void`

#### Returns

`Promise`\<`void`\>
