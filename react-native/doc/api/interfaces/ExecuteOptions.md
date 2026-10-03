[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / ExecuteOptions

# Interface: ExecuteOptions\<T\>

Common options accepted by asynchronous session execution.

## Extended by

- [`FFmpegExecuteOptions`](FFmpegExecuteOptions.md)

## Type Parameters

### T

`T`

## Properties

### completeCallback?

> `optional` **completeCallback?**: [`SessionCompleteCallback`](../type-aliases/SessionCompleteCallback.md)\<`T`\>

Invoked before the execution promise resolves.

***

### logCallback?

> `optional` **logCallback?**: [`LogCallback`](../type-aliases/LogCallback.md)\<`T`\>

Receives log entries in session order.

***

### pollIntervalMs?

> `optional` **pollIntervalMs?**: `number`

Interval used by the TypeScript layer to poll native state and buffered
callbacks. Values below 10 ms are clamped to 10 ms. Defaults to 50 ms.
