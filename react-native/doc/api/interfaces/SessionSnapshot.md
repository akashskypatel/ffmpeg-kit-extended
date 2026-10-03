[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / SessionSnapshot

# Interface: SessionSnapshot

Serialized state returned by the native session history API.

## Properties

### command

> **command**: `string`

Normalized/original command representation associated with the wrapper.

***

### createTime

> **createTime**: `number`

Unix epoch timestamp in milliseconds.

***

### debugLogEnabled

> **debugLogEnabled**: `boolean`

Whether additional native debug-log capture is enabled.

***

### duration

> **duration**: `number`

Wall-clock execution duration in milliseconds.

***

### endTime

> **endTime**: `number`

Unix epoch timestamp in milliseconds, or `0` before completion.

***

### failStackTrace

> **failStackTrace**: `string`

Native failure stack trace, or an empty string when none was recorded.

***

### logs

> **logs**: `string`

Retained log content from the native history API.

***

### logsCount

> **logsCount**: `number`

Number of retained native log entries.

***

### output

> **output**: `string`

Combined native console output retained for this session.

***

### returnCode

> **returnCode**: `number`

Native return code, including the package cancellation value when applicable.

***

### sessionId

> **sessionId**: `number`

Process-unique native identity; it is not persistent across restarts.

***

### startTime

> **startTime**: `number`

Unix epoch timestamp in milliseconds, or `0` before execution starts.

***

### state

> **state**: [`SessionState`](../enumerations/SessionState.md)

Lifecycle state recorded when the snapshot was read.

***

### statisticsCount

> **statisticsCount**: `number`

Number of retained native statistics entries.

***

### type

> **type**: [`SessionType`](../type-aliases/SessionType.md)

Session kind represented by this snapshot.
