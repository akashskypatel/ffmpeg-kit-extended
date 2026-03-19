# Global Configuration

The `FFmpegKitConfig` class provides methods to manage global settings and retrieve library information.

## Log Management

### Redirection

Enable or disable redirection of all FFmpeg logs to the system console.

- `enableRedirection()`
- `disableRedirection()`

### Log Level

Set or get the global log level for the library.

- `setLogLevel(LogLevel)`
- `getLogLevel()`

## Library Information

Retrieve version and build information for FFmpeg and FFmpeg Kit.

- `getFFmpegVersion()`: Returns the bundled FFmpeg version.
- `getVersion()`: Returns the FFmpeg Kit Extended version.
- `getPackageName()`: Returns the name of the bundled package.
- `getBuildDate()`: Returns the library build date.

## Session Management

### History

- `setSessionHistorySize(int)`: Sets how many sessions are kept in the native history.
- `getSessionHistorySize()`: Gets the current history size.
- `clearSessions()`: Clears all sessions from the history.

### Concurrency

- `setMaxConcurrentSessions(int)`: Sets the maximum number of sessions that can run simultaneously (default: 8).
- `getMaxConcurrentSessions()`: Gets the current concurrency limit.

## Global Callbacks

Set callbacks that will be triggered for EVERY session of a specific type.

- `enableLogCallback(FFmpegLogCallback?)`
- `enableStatisticsCallback(FFmpegStatisticsCallback?)`
- `enableFFmpegSessionCompleteCallback(FFmpegSessionCompleteCallback?)`
- `enableFFprobeSessionCompleteCallback(FFprobeSessionCompleteCallback?)`
- `enableFFplaySessionCompleteCallback(FFplaySessionCompleteCallback?)`
- `enableMediaInformationSessionCompleteCallback(MediaInformationSessionCompleteCallback?)`

## Advanced Configuration

### Fonts

Configure font directories for subtitle rendering and video filters.

- `setFontDirectory(String, {String? mapping})`
- `setFontDirectoryList(List<String>, [Map<String, String>?])`

### Pipes

Manage FFmpeg pipes for input/output redirection.

- `registerNewFFmpegPipe()`: Creates a new pipe and returns its path.
- `closeFFmpegPipe(String)`: Closes an active pipe.

### Utilities

- `parseArguments(String)`: Splices a command string into an argument list.
- `argumentsToString(List<String>)`: joins an argument list into a command string.
- `setEnvironmentVariable(String, String)`: Sets a native environment variable.
- `ignoreSignal(Signal)`: Tells FFmpeg to ignore a specific system signal.
