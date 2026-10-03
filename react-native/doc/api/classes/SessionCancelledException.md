[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / SessionCancelledException

# Class: SessionCancelledException

Rejection used when a session is removed from the JavaScript queue before its
native executor starts.

## Extends

- `Error`

## Constructors

### Constructor

> **new SessionCancelledException**(`message?`): `SessionCancelledException`

#### Parameters

##### message?

`string` = `'Session was removed from queue'`

#### Returns

`SessionCancelledException`

#### Overrides

`Error.constructor`

## Properties

### message

> **message**: `string`

#### Inherited from

`Error.message`

***

### name

> **name**: `string`

#### Inherited from

`Error.name`

***

### stack?

> `optional` **stack?**: `string`

#### Inherited from

`Error.stack`
