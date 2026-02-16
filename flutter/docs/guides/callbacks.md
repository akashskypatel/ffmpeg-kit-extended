# Callbacks and Monitoring Guide

Learn how to monitor FFmpeg operations in real-time using callbacks.

## Table of Contents

- [Overview](#overview)
- [Callback Types](#callback-types)
- [Session-Level Callbacks](#session-level-callbacks)
- [Global Callbacks](#global-callbacks)
- [Progress Tracking](#progress-tracking)
- [Real-time Logging](#real-time-logging)
- [Statistics Monitoring](#statistics-monitoring)
- [Best Practices](#best-practices)

## Overview

FFmpeg Kit Extended provides three types of callbacks for monitoring operations:

1. **Log Callbacks** - Receive log messages from FFmpeg
2. **Statistics Callbacks** - Get real-time encoding/decoding statistics
3. **Complete Callbacks** - Notified when a session finishes

Callbacks can be set at two levels:

- **Session-level**: Applied to a specific operation
- **Global-level**: Applied to all operations

## Callback Types

### Log Callback

Receives log messages emitted by FFmpeg during execution.

```dart
typedef FFmpegLogCallback = void Function(Log log);

class Log {
  final int sessionId;    // Session that produced this log
  final int level;        // Raw log level
  final String message;   // Log message content
  
  LogLevel get logLevel;  // Parsed log level enum
}
```

### Statistics Callback

Receives periodic statistics updates during encoding/decoding.

```dart
typedef FFmpegStatisticsCallback = void Function(Statistics statistics);

class Statistics {
  final int sessionId;          // Session ID
  final int time;               // Current time in milliseconds
  final int size;               // Output size in bytes
  final double bitrate;         // Current bitrate in kbps
  final double speed;           // Processing speed (e.g., 2.0x)
  final int videoFrameNumber;   // Current frame number
  final double videoFps;        // Current FPS
  final double videoQuality;    // Current quality
}
```

### Complete Callback

Called when a session completes execution.

```dart
typedef FFmpegSessionCompleteCallback = void Function(FFmpegSession session);
typedef FFprobeSessionCompleteCallback = void Function(FFprobeSession session);
typedef FFplaySessionCompleteCallback = void Function(FFplaySession session);
```

## Session-Level Callbacks

Set callbacks for a specific operation.

### FFmpeg Session Callbacks

```dart
await FFmpegKit.executeAsync(
  '-i input.mp4 -c:v libx264 output.mp4',
  onLog: (log) {
    print('[${log.logLevel}] ${log.message}');
  },
  onStatistics: (stats) {
    print('Frame: ${stats.videoFrameNumber}, Speed: ${stats.speed}x');
  },
  onComplete: (session) {
    if (ReturnCode.isSuccess(session.getReturnCode())) {
      print('Success!');
    } else {
      print('Failed: ${session.getOutput()}');
    }
  },
);
```

### FFprobe Session Callbacks

```dart
await FFprobeKit.executeAsync(
  '-show_format input.mp4',
  onComplete: (session) {
    print('FFprobe output: ${session.getOutput()}');
  },
);
```

### FFplay Session Callbacks

```dart
await FFplayKit.executeAsync(
  'video.mp4',
  onComplete: (session) {
    print('Playback finished');
  },
);
```

## Global Callbacks

Set callbacks that apply to all operations.

### Enable Global Log Callback

```dart
FFmpegKitConfig.enableLogCallback((log) {
  // Filter by log level
  if (log.logLevel == LogLevel.error) {
    print('ERROR: ${log.message}');
  } else if (log.logLevel == LogLevel.warning) {
    print('WARNING: ${log.message}');
  }
});
```

### Enable Global Statistics Callback

```dart
FFmpegKitConfig.enableStatisticsCallback((stats) {
  print('Session ${stats.sessionId}: ${stats.speed}x speed');
});
```

### Enable Global Complete Callbacks

```dart
// For FFmpeg sessions
FFmpegKitConfig.enableFFmpegSessionCompleteCallback((session) {
  print('FFmpeg session ${session.getSessionId()} completed');
});

// For FFprobe sessions
FFmpegKitConfig.enableFFprobeSessionCompleteCallback((session) {
  print('FFprobe session ${session.getSessionId()} completed');
});

// For FFplay sessions
FFmpegKitConfig.enableFFplaySessionCompleteCallback((session) {
  print('FFplay session ${session.getSessionId()} completed');
});
```

### Disable Global Callbacks

```dart
// Pass null to disable
FFmpegKitConfig.enableLogCallback(null);
FFmpegKitConfig.enableStatisticsCallback(null);
FFmpegKitConfig.enableFFmpegSessionCompleteCallback(null);
```

## Progress Tracking

### Basic Progress Tracking

```dart
Future<void> convertWithProgress(String input, String output) async {
  // Get video duration first
  final probeSession = FFprobeKit.getMediaInformation(input);
  double totalDuration = 0.0;
  
  if (probeSession is MediaInformationSession) {
    final info = probeSession.getMediaInformation();
    totalDuration = double.tryParse(info?.duration ?? '0') ?? 0.0;
  }
  
  if (totalDuration == 0) {
    print('Could not determine video duration');
    return;
  }
  
  // Convert with progress tracking
  await FFmpegKit.executeAsync(
    '-i $input -c:v libx264 $output',
    onStatistics: (stats) {
      // Calculate progress percentage
      final currentTime = stats.time / 1000; // Convert ms to seconds
      final progress = (currentTime / totalDuration) * 100;
      
      print('Progress: ${progress.toStringAsFixed(1)}%');
      print('Speed: ${stats.speed}x');
      print('Frame: ${stats.videoFrameNumber}');
      print('Bitrate: ${stats.bitrate} kbps');
    },
    onComplete: (session) {
      print('Conversion complete!');
    },
  );
}
```

### Progress with UI Updates

```dart
class VideoConverterState extends State<VideoConverter> {
  double _progress = 0.0;
  String _status = 'Ready';
  
  Future<void> _convertVideo(String input, String output) async {
    // Get duration
    final probeSession = FFprobeKit.getMediaInformation(input);
    double totalDuration = 0.0;
    
    if (probeSession is MediaInformationSession) {
      final info = probeSession.getMediaInformation();
      totalDuration = double.tryParse(info?.duration ?? '0') ?? 0.0;
    }
    
    setState(() => _status = 'Converting...');
    
    await FFmpegKit.executeAsync(
      '-i $input -c:v libx264 $output',
      onStatistics: (stats) {
        setState(() {
          _progress = (stats.time / 1000 / totalDuration).clamp(0.0, 1.0);
          _status = 'Converting... ${(_progress * 100).toStringAsFixed(1)}%';
        });
      },
      onComplete: (session) {
        setState(() {
          if (ReturnCode.isSuccess(session.getReturnCode())) {
            _progress = 1.0;
            _status = 'Complete!';
          } else {
            _progress = 0.0;
            _status = 'Failed';
          }
        });
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(value: _progress),
        Text(_status),
      ],
    );
  }
}
```

### Advanced Progress with ETA

```dart
class ProgressTracker {
  DateTime? _startTime;
  double _lastProgress = 0.0;
  
  String calculateETA(double currentProgress, double totalDuration) {
    if (_startTime == null) {
      _startTime = DateTime.now();
      return 'Calculating...';
    }
    
    final elapsed = DateTime.now().difference(_startTime!);
    final progressDelta = currentProgress - _lastProgress;
    
    if (progressDelta <= 0) return 'Unknown';
    
    final estimatedTotal = elapsed.inSeconds / currentProgress;
    final remaining = estimatedTotal - elapsed.inSeconds;
    
    _lastProgress = currentProgress;
    
    final minutes = (remaining / 60).floor();
    final seconds = (remaining % 60).floor();
    
    return '${minutes}m ${seconds}s remaining';
  }
}

// Usage
final tracker = ProgressTracker();

await FFmpegKit.executeAsync(
  command,
  onStatistics: (stats) {
    final progress = stats.time / 1000 / totalDuration;
    final eta = tracker.calculateETA(progress, totalDuration);
    print('Progress: ${(progress * 100).toStringAsFixed(1)}% - $eta');
  },
);
```

## Real-time Logging

### Log to Console

```dart
FFmpegKitConfig.enableLogCallback((log) {
  print('[FFmpeg ${log.logLevel}] ${log.message}');
});
```

### Filter Logs by Level

```dart
FFmpegKitConfig.enableLogCallback((log) {
  // Only show errors and warnings
  if (log.logLevel == LogLevel.error || log.logLevel == LogLevel.warning) {
    print('[${log.logLevel}] ${log.message}');
  }
});
```

### Log to File

```dart
final logFile = File('ffmpeg_logs.txt');
final logSink = logFile.openWrite(mode: FileMode.append);

FFmpegKitConfig.enableLogCallback((log) {
  logSink.writeln('[${DateTime.now()}] [${log.logLevel}] ${log.message}');
});

// Don't forget to close when done
await logSink.close();
```

### Structured Logging

```dart
class FFmpegLogger {
  final List<Log> _logs = [];
  
  void enable() {
    FFmpegKitConfig.enableLogCallback((log) {
      _logs.add(log);
      
      // Keep only last 1000 logs
      if (_logs.length > 1000) {
        _logs.removeAt(0);
      }
      
      _printLog(log);
    });
  }
  
  void _printLog(Log log) {
    final timestamp = DateTime.now().toIso8601String();
    final level = log.logLevel.toString().split('.').last.toUpperCase();
    print('[$timestamp] [$level] ${log.message}');
  }
  
  List<Log> getErrorLogs() {
    return _logs.where((log) => log.logLevel == LogLevel.error).toList();
  }
  
  List<Log> getWarningLogs() {
    return _logs.where((log) => log.logLevel == LogLevel.warning).toList();
  }
  
  void clear() {
    _logs.clear();
  }
}
```

## Statistics Monitoring

### Monitor Encoding Speed

```dart
await FFmpegKit.executeAsync(
  command,
  onStatistics: (stats) {
    if (stats.speed < 0.5) {
      print('⚠️ Encoding is slow: ${stats.speed}x');
    } else if (stats.speed > 2.0) {
      print('✅ Encoding is fast: ${stats.speed}x');
    }
  },
);
```

### Monitor Bitrate

```dart
await FFmpegKit.executeAsync(
  command,
  onStatistics: (stats) {
    final bitrateMbps = stats.bitrate / 1000;
    print('Current bitrate: ${bitrateMbps.toStringAsFixed(2)} Mbps');
    
    if (stats.bitrate > 10000) {
      print('⚠️ High bitrate detected');
    }
  },
);
```

### Track Frame Processing

```dart
int lastFrame = 0;
DateTime lastUpdate = DateTime.now();

await FFmpegKit.executeAsync(
  command,
  onStatistics: (stats) {
    final now = DateTime.now();
    final elapsed = now.difference(lastUpdate).inMilliseconds;
    
    if (elapsed > 0) {
      final framesDelta = stats.videoFrameNumber - lastFrame;
      final fps = (framesDelta / elapsed) * 1000;
      
      print('Processing at ${fps.toStringAsFixed(1)} FPS');
      
      lastFrame = stats.videoFrameNumber;
      lastUpdate = now;
    }
  },
);
```

### Comprehensive Statistics Dashboard

```dart
class StatisticsDashboard {
  int _totalFrames = 0;
  double _avgSpeed = 0.0;
  double _avgBitrate = 0.0;
  int _sampleCount = 0;
  
  void update(Statistics stats) {
    _totalFrames = stats.videoFrameNumber;
    _avgSpeed = (_avgSpeed * _sampleCount + stats.speed) / (_sampleCount + 1);
    _avgBitrate = (_avgBitrate * _sampleCount + stats.bitrate) / (_sampleCount + 1);
    _sampleCount++;
  }
  
  void printSummary() {
    print('=== Statistics Summary ===');
    print('Total frames: $_totalFrames');
    print('Average speed: ${_avgSpeed.toStringAsFixed(2)}x');
    print('Average bitrate: ${_avgBitrate.toStringAsFixed(2)} kbps');
    print('Samples: $_sampleCount');
  }
}

// Usage
final dashboard = StatisticsDashboard();

await FFmpegKit.executeAsync(
  command,
  onStatistics: (stats) => dashboard.update(stats),
  onComplete: (session) => dashboard.printSummary(),
);
```

## Best Practices

### 1. Use Session-Level Callbacks for Specific Operations

```dart
// Good: Specific callback for this operation
await FFmpegKit.executeAsync(
  command,
  onStatistics: (stats) {
    // Handle progress for this specific conversion
  },
);
```

### 2. Use Global Callbacks for Debugging

```dart
// Good for development/debugging
void setupDebugLogging() {
  FFmpegKitConfig.enableLogCallback((log) {
    if (kDebugMode) {
      print('[FFmpeg] ${log.message}');
    }
  });
}
```

### 3. Avoid Heavy Processing in Callbacks

```dart
// Bad: Heavy processing blocks the callback
FFmpegKitConfig.enableLogCallback((log) {
  // Don't do this!
  expensiveOperation(log.message);
});

// Good: Offload to another isolate or use debouncing
FFmpegKitConfig.enableLogCallback((log) {
  // Quick operation
  _logQueue.add(log);
});
```

### 4. Clean Up Resources

```dart
@override
void dispose() {
  // Disable callbacks when widget is disposed
  FFmpegKitConfig.enableLogCallback(null);
  FFmpegKitConfig.enableStatisticsCallback(null);
  super.dispose();
}
```

### 5. Handle Null Values

```dart
onStatistics: (stats) {
  // Statistics might have zero/null values
  if (stats.speed > 0) {
    print('Speed: ${stats.speed}x');
  }
}
```

### 6. Throttle UI Updates

```dart
DateTime _lastUpdate = DateTime.now();

onStatistics: (stats) {
  final now = DateTime.now();
  
  // Update UI at most once per 500ms
  if (now.difference(_lastUpdate).inMilliseconds >= 500) {
    setState(() {
      _progress = calculateProgress(stats);
    });
    _lastUpdate = now;
  }
}
```

### 7. Combine Callbacks Effectively

```dart
await FFmpegKit.executeAsync(
  command,
  onLog: (log) {
    // Log errors to file
    if (log.logLevel == LogLevel.error) {
      _logToFile(log);
    }
  },
  onStatistics: (stats) {
    // Update UI with progress
    _updateProgress(stats);
  },
  onComplete: (session) {
    // Final cleanup and notification
    _handleCompletion(session);
  },
);
```

## Complete Example: Video Converter with Full Monitoring

```dart
class VideoConverterWithMonitoring extends StatefulWidget {
  @override
  _VideoConverterWithMonitoringState createState() =>
      _VideoConverterWithMonitoringState();
}

class _VideoConverterWithMonitoringState
    extends State<VideoConverterWithMonitoring> {
  double _progress = 0.0;
  double _speed = 0.0;
  int _currentFrame = 0;
  double _bitrate = 0.0;
  String _status = 'Ready';
  List<String> _errors = [];
  DateTime? _startTime;
  
  Future<void> _convert(String input, String output) async {
    setState(() {
      _startTime = DateTime.now();
      _status = 'Getting video info...';
      _errors.clear();
    });
    
    // Get duration
    final probeSession = FFprobeKit.getMediaInformation(input);
    double totalDuration = 0.0;
    
    if (probeSession is MediaInformationSession) {
      final info = probeSession.getMediaInformation();
      totalDuration = double.tryParse(info?.duration ?? '0') ?? 0.0;
    }
    
    setState(() => _status = 'Converting...');
    
    await FFmpegKit.executeAsync(
      '-i $input -c:v libx264 -preset medium -crf 23 $output',
      onLog: (log) {
        // Collect errors
        if (log.logLevel == LogLevel.error) {
          setState(() => _errors.add(log.message));
        }
      },
      onStatistics: (stats) {
        setState(() {
          _progress = (stats.time / 1000 / totalDuration).clamp(0.0, 1.0);
          _speed = stats.speed;
          _currentFrame = stats.videoFrameNumber;
          _bitrate = stats.bitrate;
          
          final percent = (_progress * 100).toStringAsFixed(1);
          _status = 'Converting... $percent%';
        });
      },
      onComplete: (session) {
        final duration = DateTime.now().difference(_startTime!);
        
        setState(() {
          if (ReturnCode.isSuccess(session.getReturnCode())) {
            _progress = 1.0;
            _status = 'Complete! (${duration.inSeconds}s)';
          } else {
            _status = 'Failed';
          }
        });
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(value: _progress),
        SizedBox(height: 16),
        Text(_status, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Speed: ${_speed.toStringAsFixed(2)}x'),
        Text('Frame: $_currentFrame'),
        Text('Bitrate: ${_bitrate.toStringAsFixed(2)} kbps'),
        if (_errors.isNotEmpty) ...[
          SizedBox(height: 16),
          Text('Errors:', style: TextStyle(color: Colors.red)),
          ..._errors.map((e) => Text(e, style: TextStyle(fontSize: 12))),
        ],
      ],
    );
  }
}
```

## See Also

- [FFmpegKit API Reference](../api/ffmpeg-kit.md)
- [Video Processing Guide](video-processing.md)
- [Error Handling Guide](error-handling.md)
