[**ffmpeg-kit-extended**](../README.md)

***

[ffmpeg-kit-extended](../README.md) / SessionState

# Enumeration: SessionState

Lifecycle state reported by every session.

## Enumeration Members

### Completed

> **Completed**: `2`

Native execution reached a terminal state; inspect the return code.

***

### Created

> **Created**: `0`

The native session exists but execution has not started.

***

### Failed

> **Failed**: `3`

Session startup or execution failed before normal completion.

***

### Running

> **Running**: `1`

The command is currently executing.
