[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / FFmpegExecuteOptions

# Interface: FFmpegExecuteOptions\<T\>

Execution options for FFmpeg sessions, including progress statistics.

## Extends

- [`ExecuteOptions`](ExecuteOptions.md)\<`T`\>

## Type Parameters

### T

`T`

## Properties

### completeCallback?

> `optional` **completeCallback?**: [`SessionCompleteCallback`](../type-aliases/SessionCompleteCallback.md)\<`T`\>

Invoked before the execution promise resolves.

#### Inherited from

[`ExecuteOptions`](ExecuteOptions.md).[`completeCallback`](ExecuteOptions.md#completecallback)

***

### logCallback?

> `optional` **logCallback?**: [`LogCallback`](../type-aliases/LogCallback.md)\<`T`\>

Receives log entries in session order.

#### Inherited from

[`ExecuteOptions`](ExecuteOptions.md).[`logCallback`](ExecuteOptions.md#logcallback)

***

### pollIntervalMs?

> `optional` **pollIntervalMs?**: `number`

Interval used by the TypeScript layer to poll native state and buffered
callbacks. Values below 10 ms are clamped to 10 ms. Defaults to 50 ms.

#### Inherited from

[`ExecuteOptions`](ExecuteOptions.md).[`pollIntervalMs`](ExecuteOptions.md#pollintervalms)

***

### statisticsCallback?

> `optional` **statisticsCallback?**: [`StatisticsCallback`](../type-aliases/StatisticsCallback.md)\<`T`\>

Receives FFmpeg progress/statistics updates in session order.
