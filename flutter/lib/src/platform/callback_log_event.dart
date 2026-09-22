import 'dart:developer' as developer;

/// Consumes one native-owned log payload and releases it exactly once.
///
/// The release error is deliberately secondary to a decode/dispatch error so
/// an ownership failure cannot replace the primary callback failure.
void consumeOwnedLogEvent<T>({
  required T payload,
  required bool isNull,
  required String? Function(T payload) decode,
  required void Function(String? message) dispatch,
  required void Function(T payload) release,
}) {
  Object? primaryError;
  StackTrace? primaryStackTrace;

  try {
    final message = isNull ? null : decode(payload);
    try {
      dispatch(message);
    } catch (error, stackTrace) {
      primaryError = error;
      primaryStackTrace = stackTrace;
    }
  } catch (error, stackTrace) {
    primaryError = error;
    primaryStackTrace = stackTrace;
  } finally {
    if (!isNull) {
      try {
        release(payload);
      } catch (error, stackTrace) {
        if (primaryError == null) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        developer.log(
          'Owned log payload release failed after a primary callback error',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  if (primaryError != null) {
    Error.throwWithStackTrace(primaryError, primaryStackTrace!);
  }
}
