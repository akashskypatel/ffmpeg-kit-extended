/*
 * FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
 * Copyright (C) 2026 Akash Patel
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'session.dart';

/// Manages session execution to limit concurrent system resource usage.
///
/// While FFmpegKit support parallel execution, running too many sessions
/// simultaneously can over-allocate CPU and memory. This manager ensures
/// that sessions are executed in parallel up to a specified limit.
class SessionQueueManager {
  static final SessionQueueManager _instance = SessionQueueManager._internal();

  factory SessionQueueManager() => _instance;

  SessionQueueManager._internal();

  /// The maximum number of sessions that can execute concurrently.
  int _maxConcurrentSessions = 8;

  /// The currently executing sessions.
  final Set<Session> _activeSessions = <Session>{};

  /// Native session IDs reserved by queued or active executions.
  ///
  /// Wrapper objects are disposable observations and are not an execution
  /// identity. This bounded set closes that gap without retaining history:
  /// each ID is held only until its queue item is discarded or settles.
  final Set<int> _reservedSessionIds = <int>{};

  /// Queue of pending sessions waiting to execute.
  final Queue<_QueuedSession> _queue = Queue<_QueuedSession>();

  /// Lock to prevent concurrent modifications to the queue processing.
  bool _isProcessing = false;

  /// Gets the currently executing sessions.
  List<Session> get activeSessions => _activeSessions.toList();

  /// Gets the number of sessions currently executing.
  int get activeSessionCount => _activeSessions.length;

  /// Gets the number of queued sessions waiting to execute.
  int get queueLength => _queue.length;

  /// Returns true if any session is currently executing.
  bool get isBusy => _activeSessions.isNotEmpty;

  /// Gets the maximum number of concurrent sessions.
  int get maxConcurrentSessions => _maxConcurrentSessions;

  /// Sets the maximum number of concurrent sessions.
  set maxConcurrentSessions(int value) {
    if (value < 1) {
      throw ArgumentError('maxConcurrentSessions must be at least 1');
    }
    _maxConcurrentSessions = value;
    _processQueue();
  }

  /// Executes a session.
  ///
  /// The session will be added to the queue and executed as soon as
  /// a concurrency slot becomes available.
  ///
  /// Returns a Future that completes when the session finishes execution.
  ///
  /// Admission is unique by native session ID while queued or active. Reusing
  /// the same object or another wrapper for a reserved ID fails without
  /// invoking [onDiscard].
  Future<void> executeSession(
    Session session,
    Future<void> Function() executor, {
    void Function()? onDiscard,
  }) {
    if (session.isDisposed) {
      return Future<void>.error(
        StateError('Cannot execute a disposed session'),
      );
    }
    if (_containsSession(session)) {
      return Future<void>.error(
        StateError('Session ${session.sessionId} is already queued or active'),
      );
    }
    final completer = Completer<void>();
    if (session.isCancelled) {
      _discard(
        _QueuedSession(session, executor, completer, onDiscard),
        SessionCancelledException('Session was cancelled before queueing'),
      );
      return completer.future;
    }
    _reservedSessionIds.add(session.sessionId);
    _queue.add(_QueuedSession(session, executor, completer, onDiscard));

    _processQueue();

    return completer.future;
  }

  bool _containsSession(Session session) {
    return _reservedSessionIds.contains(session.sessionId) ||
        _activeSessions.any((active) => identical(active, session)) ||
        _queue.any((queued) => identical(queued.session, session));
  }

  /// Processes the session queue, starting as many sessions as allowed.
  void _processQueue() {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_queue.isNotEmpty &&
          _activeSessions.length < _maxConcurrentSessions) {
        final queued = _queue.removeFirst();
        if (queued.session.isDisposed) {
          _discard(queued, StateError('Cannot execute a disposed session'));
          continue;
        }
        if (queued.session.isCancelled) {
          _discard(
            queued,
            SessionCancelledException('Session was cancelled before execution'),
          );
          continue;
        }
        _activeSessions.add(queued.session);
        queued.session.markExecutionStarted();
        _executeQueuedSession(queued);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Removes one exact queued session without disturbing later items.
  ///
  /// Returns `true` when an item was removed. Discard cleanup is isolated to
  /// the removed item; a cleanup failure rejects only that item's Future and
  /// never strands the rest of the queue.
  bool cancelQueued(Session session) {
    if (_queue.isEmpty) return false;

    final retained = Queue<_QueuedSession>();
    _QueuedSession? removed;
    while (_queue.isNotEmpty) {
      final queued = _queue.removeFirst();
      if (removed == null && identical(queued.session, session)) {
        removed = queued;
      } else {
        retained.addLast(queued);
      }
    }
    _queue.addAll(retained);
    if (removed == null) return false;

    _discard(
      removed,
      SessionCancelledException('Session was removed from queue'),
    );
    return true;
  }

  /// Internal helper to execute a queued session and manage its lifecycle.
  Future<void> _executeQueuedSession(_QueuedSession queued) async {
    Object? executionError;
    StackTrace? executionStackTrace;
    try {
      await queued.executor();
    } catch (error, stackTrace) {
      executionError = error;
      executionStackTrace = stackTrace;
    }

    Object? settlementError;
    StackTrace? settlementStackTrace;
    try {
      queued.session.markExecutionSettled();
    } catch (error, stackTrace) {
      settlementError = error;
      settlementStackTrace = stackTrace;
    } finally {
      // Queue identity is released before the public Future is completed so a
      // settlement failure cannot strand the slot or block the next item.
      _activeSessions.remove(queued.session);
      _reservedSessionIds.remove(queued.session.sessionId);
      try {
        _processQueue();
      } catch (error, stackTrace) {
        developer.log(
          'SessionQueueManager: queue progression failed after settlement',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (executionError != null) {
      if (settlementError != null) {
        developer.log(
          'SessionQueueManager: settlement failed after an execution error '
          'for session ${queued.session.sessionId}',
          error: settlementError,
          stackTrace: settlementStackTrace,
        );
      }
      if (!queued.completer.isCompleted) {
        queued.completer.completeError(executionError!, executionStackTrace!);
      }
    } else if (settlementError != null) {
      if (!queued.completer.isCompleted) {
        queued.completer.completeError(settlementError!, settlementStackTrace!);
      }
    } else if (!queued.completer.isCompleted) {
      queued.completer.complete();
    }
  }

  /// Cancels all currently executing sessions.
  void cancelCurrent() {
    // Collect sessions to cancel to avoid concurrent modification issues
    final sessionsToCancel = _activeSessions.toList();
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final session in sessionsToCancel) {
      try {
        session.cancel();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  /// Clears all queued sessions without executing them.
  void clearQueue() {
    final queuedToCancel = _queue.toList();
    _queue.clear();
    for (final queued in queuedToCancel) {
      _discard(
        queued,
        SessionCancelledException('Session was removed from queue'),
      );
    }
  }

  void _discard(_QueuedSession queued, Object defaultError) {
    Object error = defaultError;
    StackTrace? stackTrace;
    try {
      if (defaultError is SessionCancelledException) {
        queued.session.markCancelledBeforeExecution();
      }
      queued.session.discardBeforeExecution();
      queued.onDiscard?.call();
    } catch (e, st) {
      error = e;
      stackTrace = st;
    } finally {
      _reservedSessionIds.remove(queued.session.sessionId);
    }
    if (!queued.completer.isCompleted) {
      if (stackTrace == null) {
        queued.completer.completeError(error);
      } else {
        queued.completer.completeError(error, stackTrace);
      }
    }
  }

  /// Cancels all sessions (current and queued).
  void cancelAll() {
    clearQueue();
    cancelCurrent();
  }

  /// Waits for all sessions (current and queued) to complete.
  Future<void> waitForAll() async {
    if (!isBusy && _queue.isEmpty) return;

    final completer = Completer<void>();

    // Check periodically if we are done
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!isBusy && _queue.isEmpty) {
        timer.cancel();
        completer.complete();
      }
    });

    return completer.future;
  }
}

/// Internal class to hold queued session information.
class _QueuedSession {
  final Session session;
  final Future<void> Function() executor;
  final Completer<void> completer;
  final void Function()? onDiscard;

  _QueuedSession(this.session, this.executor, this.completer, this.onDiscard);
}
