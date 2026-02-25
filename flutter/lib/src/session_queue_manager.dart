/**
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
    if (value < 1)
      throw ArgumentError('maxConcurrentSessions must be at least 1');
    _maxConcurrentSessions = value;
    _processQueue();
  }

  /// Executes a session.
  ///
  /// The session will be added to the queue and executed as soon as
  /// a concurrency slot becomes available.
  ///
  /// Returns a Future that completes when the session finishes execution.
  Future<void> executeSession(
    Session session,
    Future<void> Function() executor,
  ) {
    final completer = Completer<void>();
    _queue.add(_QueuedSession(session, executor, completer));

    _processQueue();

    return completer.future;
  }

  /// Processes the session queue, starting as many sessions as allowed.
  void _processQueue() {
    if (_isProcessing) return;
    _isProcessing = true;

    while (
        _queue.isNotEmpty && _activeSessions.length < _maxConcurrentSessions) {
      final queued = _queue.removeFirst();
      _executeQueuedSession(queued);
    }

    _isProcessing = false;
  }

  /// Internal helper to execute a queued session and manage its lifecycle.
  Future<void> _executeQueuedSession(_QueuedSession queued) async {
    _activeSessions.add(queued.session);

    try {
      await queued.executor();
      if (!queued.completer.isCompleted) {
        queued.completer.complete();
      }
    } catch (error, stackTrace) {
      if (!queued.completer.isCompleted) {
        queued.completer.completeError(error, stackTrace);
      }
    } finally {
      _activeSessions.remove(queued.session);
      // Trigger processing for the next session in queue
      _processQueue();
    }
  }

  /// Cancels all currently executing sessions.
  void cancelCurrent() {
    // Collect sessions to cancel to avoid concurrent modification issues
    final sessionsToCancel = _activeSessions.toList();
    for (final session in sessionsToCancel) {
      session.cancel();
    }
  }

  /// Clears all queued sessions without executing them.
  void clearQueue() {
    final queuedToCancel = _queue.toList();
    _queue.clear();
    for (final queued in queuedToCancel) {
      queued.completer.completeError(
        SessionCancelledException('Session was removed from queue'),
      );
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

  _QueuedSession(this.session, this.executor, this.completer);
}

/// Exception thrown when a session is cancelled.
class SessionCancelledException implements Exception {
  final String message;

  SessionCancelledException(this.message);

  @override
  String toString() => 'SessionCancelledException: $message';
}
