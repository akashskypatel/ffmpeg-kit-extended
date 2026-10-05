/// Ensures a non-empty FFmpeg log entry is terminated as a complete line.
///
/// This is a compatibility fallback for native runtimes that return a log
/// message without its line terminator. Existing LF and CRLF endings are kept.
String ensureLogMessageLineFeed(String message) {
  if (message.isEmpty || message.endsWith('\n')) {
    return message;
  }
  return '$message\n';
}

/// Joins native log entries after ensuring each non-empty entry ends in LF.
String formatLogMessages(Iterable<String> messages) =>
    messages.map(ensureLogMessageLineFeed).join();

/// Repairs combined native text only when it is the raw concatenation of the
/// supplied log entries. Unexpected native formatting is preserved.
String formatLogOutputIfMissingLineFeeds(
  String nativeOutput,
  Iterable<String> messages,
) {
  final entries = messages.toList(growable: false);
  if (entries.join() != nativeOutput) {
    return nativeOutput;
  }
  return formatLogMessages(entries);
}
