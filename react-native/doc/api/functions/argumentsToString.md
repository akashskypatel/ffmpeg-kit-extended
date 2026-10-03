[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / argumentsToString

# Function: argumentsToString()

> **argumentsToString**(`arguments_`): `string`

Formats an argv-style array as one FFmpegKit command string.

This representation is intended for display and compatibility string APIs.
Prefer argument-array session constructors when arguments are already
tokenized. Values requiring grouping are single-quoted so backslashes and
double quotes remain literal. Embedded single quotes are emitted as adjacent
quoted/unquoted segments that the native compatibility parser round-trips.

## Parameters

### arguments\_

readonly `string`[]

## Returns

`string`
