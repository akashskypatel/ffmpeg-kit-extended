[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / parseArguments

# Function: parseArguments()

> **parseArguments**(`command`): `string`[]

Splits an FFmpegKit compatibility command string into argument tokens.

Single and double quotes group whitespace. Ordinary backslashes are literal
so Windows drive and UNC paths survive unchanged. A backslash only escapes a
quote, or unquoted whitespace. Empty quoted arguments are preserved.

## Parameters

### command

`string`

## Returns

`string`[]
