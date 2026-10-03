[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / SessionQueueManager

# Class: SessionQueueManager

Process-wide JavaScript queue that limits concurrent native sessions.

`FFmpegSession`, `FFprobeSession`, `MediaInformationSession`, and
`FFplaySession` all use the shared instance. The default concurrency is 8.
Lower the limit for memory-constrained devices or workloads that saturate
storage, CPU, GPU, or network resources.

## Constructors

### Constructor

> **new SessionQueueManager**(): `SessionQueueManager`

#### Returns

`SessionQueueManager`

## Accessors

### activeSessionCount

#### Get Signature

> **get** **activeSessionCount**(): `number`

Number of currently active session executors.

##### Returns

`number`

***

### activeSessions

#### Get Signature

> **get** **activeSessions**(): [`Session`](Session.md)[]

Snapshot of sessions whose executors have started and not settled.

##### Returns

[`Session`](Session.md)[]

***

### isBusy

#### Get Signature

> **get** **isBusy**(): `boolean`

Whether at least one session is actively executing.

##### Returns

`boolean`

***

### maxConcurrentSessions

#### Get Signature

> **get** **maxConcurrentSessions**(): `number`

Maximum number of active sessions permitted at once.

##### Returns

`number`

#### Set Signature

> **set** **maxConcurrentSessions**(`value`): `void`

Sets the concurrency limit and immediately starts queued work when the
larger limit creates capacity.

##### Throws

`Error` unless `value` is an integer of at least 1.

##### Parameters

###### value

`number`

##### Returns

`void`

***

### queueLength

#### Get Signature

> **get** **queueLength**(): `number`

Number of sessions waiting for a concurrency slot.

##### Returns

`number`

***

### shared

#### Get Signature

> **get** `static` **shared**(): `SessionQueueManager`

Singleton used by all high-level execution APIs.

##### Returns

`SessionQueueManager`

## Methods

### cancelAll()

> **cancelAll**(): `void` \| `Promise`\<`void`\>

Clears waiting sessions and requests cancellation of active sessions.
Queue cleanup has branch priority over active cancellation for error
authority, while both branches are initiated without serial waiting.

#### Returns

`void` \| `Promise`\<`void`\>

***

### cancelCurrent()

> **cancelCurrent**(): `void` \| `Promise`\<`void`\>

Requests cancellation of every currently active session.

A single native cancellation failure must not prevent the remaining active
sessions from receiving the request. After all attempts complete, callers
receive the first failure in the stable active-session snapshot order,
independent of Promise settlement timing.

#### Returns

`void` \| `Promise`\<`void`\>

***

### clearQueue()

> **clearQueue**(): `void` \| `Promise`\<`void`\>

Removes all waiting sessions and rejects their promises with
`SessionCancelledException`, or with a discard cleanup error when cleanup
fails. Active sessions continue running.

#### Returns

`void` \| `Promise`\<`void`\>

***

### waitForAll()

> **waitForAll**(): `Promise`\<`void`\>

Resolves after both the active set and pending queue become empty.

#### Returns

`Promise`\<`void`\>
