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

/// Strategy for handling concurrent session execution requests.
enum SessionExecutionStrategy {
  /// Cancel the currently running session and start the new one immediately.
  cancelAndReplace,

  /// Queue the new session to execute after the current one completes.
  queue,

  /// Reject the new session if one is already running.
  rejectIfBusy,
}

/// Manages session execution to prevent concurrent C API calls.
///
/// The FFmpegKit C API uses mutex locking which prevents concurrent execution
/// of FFmpeg, FFprobe, and FFplay sessions. This manager enforces serialization
/// at the Dart layer to prevent blocking and provide better control.
class SessionQueueManager {
  static final SessionQueueManager _instance = SessionQueueManager._internal();

  factory SessionQueueManager() => _instance;

  SessionQueueManager._internal();

  /// The currently executing session (if any).
  Session? _currentSession;

  /// Queue of pending sessions waiting to execute.
  final Queue<_QueuedSession> _queue = Queue<_QueuedSession>();

  /// Completer that completes when the current session finishes.
  Completer<void>? _currentSessionCompleter;

  /// Lock to prevent concurrent modifications to the queue.
  bool _isProcessing = false;

  /// Gets the currently executing session.
  Session? get currentSession => _currentSession;

  /// Gets the number of queued sessions waiting to execute.
  int get queueLength => _queue.length;

  /// Returns true if a session is currently executing.
  bool get isBusy => _currentSession != null;

  /// Executes a session with the specified strategy.
  ///
  /// Returns a Future that completes when the session finishes execution.
  /// Throws [SessionBusyException] if [strategy] is [SessionExecutionStrategy.rejectIfBusy]
  /// and a session is already running.
  Future<void> executeSession(
    Session session,
    Future<void> Function() executor, {
    SessionExecutionStrategy strategy = SessionExecutionStrategy.queue,
  }) {
    switch (strategy) {
      case SessionExecutionStrategy.cancelAndReplace:
        return _cancelAndReplace(session, executor);

      case SessionExecutionStrategy.queue:
        return _queueSession(session, executor);

      case SessionExecutionStrategy.rejectIfBusy:
        if (isBusy) {
          throw SessionBusyException(
            'A session is already executing. Current session: ${_currentSession?.sessionId}',
          );
        }
        return _queueSession(session, executor);
    }
  }

  /// Cancels and replaces the current session.
  Future<void> _cancelAndReplace(
    Session session,
    Future<void> Function() executor,
  ) async {
    // Cancel current session if running
    if (_currentSession != null) {
      _currentSession!.cancel();
      // Clear the queue as well
      _queue.clear();
    }

    // Execute immediately
    return _executeImmediately(session, executor);
  }

  /// Queues a session for execution.
  Future<void> _queueSession(
    Session session,
    Future<void> Function() executor,
  ) {
    final completer = Completer<void>();
    _queue.add(_QueuedSession(session, executor, completer));

    // Start processing if not already doing so
    if (!_isProcessing) {
      _processQueue();
    }

    return completer.future;
  }

  /// Executes a session immediately (used for cancel-and-replace).
  Future<void> _executeImmediately(
    Session session,
    Future<void> Function() executor,
  ) async {
    _currentSession = session;
    _currentSessionCompleter = Completer<void>();

    try {
      await executor();
    } finally {
      _currentSession = null;
      _currentSessionCompleter?.complete();
      _currentSessionCompleter = null;
    }
  }

  /// Processes the session queue.
  Future<void> _processQueue() async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        final queued = _queue.removeFirst();
        _currentSession = queued.session;
        _currentSessionCompleter = Completer<void>();

        try {
          await queued.executor();
          queued.completer.complete();
        } catch (error, stackTrace) {
          queued.completer.completeError(error, stackTrace);
        } finally {
          _currentSession = null;
          _currentSessionCompleter?.complete();
          _currentSessionCompleter = null;
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Cancels the currently executing session.
  void cancelCurrent() {
    if (_currentSession != null) {
      _currentSession!.cancel();
    }
  }

  /// Clears all queued sessions without executing them.
  void clearQueue() {
    for (final queued in _queue) {
      queued.completer.completeError(
        SessionCancelledException('Session was removed from queue'),
      );
    }
    _queue.clear();
  }

  /// Cancels all sessions (current and queued).
  void cancelAll() {
    cancelCurrent();
    clearQueue();
  }

  /// Waits for the current session to complete.
  Future<void> waitForCurrent() async {
    if (_currentSessionCompleter != null) {
      await _currentSessionCompleter!.future;
    }
  }

  /// Waits for all sessions (current and queued) to complete.
  Future<void> waitForAll() async {
    while (isBusy || _queue.isNotEmpty) {
      await waitForCurrent();
      // Small delay to allow queue processing
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }
}

/// Internal class to hold queued session information.
class _QueuedSession {
  final Session session;
  final Future<void> Function() executor;
  final Completer<void> completer;

  _QueuedSession(this.session, this.executor, this.completer);
}

/// Exception thrown when a session cannot execute because another is running.
class SessionBusyException implements Exception {
  final String message;

  SessionBusyException(this.message);

  @override
  String toString() => 'SessionBusyException: $message';
}

/// Exception thrown when a session is cancelled.
class SessionCancelledException implements Exception {
  final String message;

  SessionCancelledException(this.message);

  @override
  String toString() => 'SessionCancelledException: $message';
}
