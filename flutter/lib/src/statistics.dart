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
import 'ffmpeg_session.dart';

/// Represents encoding/decoding statistics for an active [FFmpegSession].
class Statistics {
  /// The ID of the session this statistics belong to.
  final int sessionId;

  /// The current time in milliseconds.
  final int time;

  /// The current size of the output in bytes.
  final int size;

  /// The current bitrate in bits per second.
  final double bitrate;

  /// The processing speed (e.g., 2.0x).
  final double speed;

  /// The current video frame number being processed.
  final int videoFrameNumber;

  /// The current video processing speed in frames per second.
  final double videoFps;

  /// The current video quality (e.g., quantizer value).
  final double videoQuality;

  /// Creates a [Statistics] instance with the provided values.
  Statistics(this.sessionId, this.time, this.size, this.bitrate, this.speed,
      this.videoFrameNumber, this.videoFps, this.videoQuality);

  @override
  String toString() =>
      'Statistics($sessionId, time: $time, size: $size, bitrate: $bitrate, speed: $speed, frame: $videoFrameNumber, fps: $videoFps, quality: $videoQuality)';
}
