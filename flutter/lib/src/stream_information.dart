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

import 'dart:convert';

/// Represents a media stream within a container format.
class StreamInformation {
  /// The index of the stream in the file.
  final int? index;

  /// The type of the stream (e.g., "video", "audio", "subtitle").
  final String? type;

  /// The short name of the codec (e.g., "h264", "aac").
  final String? codec;

  /// The long descriptive name of the codec.
  final String? codecLong;

  /// The format associated with the stream.
  final String? format;

  /// The width of the video stream in pixels.
  final int? width;

  /// The height of the video stream in pixels.
  final int? height;

  /// The bitrate of the stream in bits per second.
  final String? bitrate;

  /// The audio sample rate in Hz.
  final String? sampleRate;

  /// The audio sample format (e.g., "fltp").
  final String? sampleFormat;

  /// The channel layout of the audio stream.
  final String? channelLayout;

  /// The sample aspect ratio.
  final String? sampleAspectRatio;

  /// The display aspect ratio (e.g., "16:9").
  final String? displayAspectRatio;

  /// The average frame rate of the video stream.
  final String? averageFrameRate;

  /// The real frame rate of the video stream.
  final String? realFrameRate;

  /// The time base of the stream.
  final String? timeBase;

  /// The codec time base.
  final String? codecTimeBase;

  /// A JSON string containing stream tags.
  final String? tagsJson;

  /// A JSON string containing all stream properties.
  final String? allPropertiesJson;

  /// Parsed map of tags from keys to values.
  Map<String, dynamic>? get tags {
    if (tagsJson == null || tagsJson!.isEmpty) return null;
    try {
      return jsonDecode(tagsJson!);
    } catch (_) {
      return null;
    }
  }

  /// Parsed map of all properties from keys to values.
  Map<String, dynamic>? get allProperties {
    if (allPropertiesJson == null || allPropertiesJson!.isEmpty) return null;
    try {
      return jsonDecode(allPropertiesJson!);
    } catch (_) {
      return null;
    }
  }

  /// Creates a new [StreamInformation] instance with the given metadata.
  StreamInformation({
    this.index,
    this.type,
    this.codec,
    this.codecLong,
    this.format,
    this.width,
    this.height,
    this.bitrate,
    this.sampleRate,
    this.sampleFormat,
    this.channelLayout,
    this.sampleAspectRatio,
    this.displayAspectRatio,
    this.averageFrameRate,
    this.realFrameRate,
    this.timeBase,
    this.codecTimeBase,
    this.tagsJson,
    this.allPropertiesJson,
  });

  @override
  String toString() =>
      'StreamInformation(index: $index, type: $type, codec: $codec)';
}
