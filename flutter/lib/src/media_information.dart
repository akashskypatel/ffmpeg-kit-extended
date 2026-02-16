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
import 'chapter_information.dart';
import 'stream_information.dart';

/// Represents metadata retrieved from a media file or stream.
class MediaInformation {
  /// The path or URL of the media file.
  final String? filename;

  /// The short name of the container format (e.g., "mp4", "mkv").
  final String? format;

  /// The long descriptive name of the format.
  final String? longFormat;

  /// The total duration of the media in seconds.
  final String? duration;

  /// The start time of the media in seconds.
  final String? startTime;

  /// The bitrate of the media stream.
  final String? bitrate;

  /// The size of the media file in bytes.
  final String? size;

  /// A JSON string containing media tags.
  final String? tagsJson;

  /// A JSON string containing all media properties.
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

  /// The list of streams contained in the media.
  final List<StreamInformation> streams;

  /// The list of chapters contained in the media.
  final List<ChapterInformation> chapters;

  /// Creates a new [MediaInformation] instance.
  MediaInformation({
    this.filename,
    this.format,
    this.longFormat,
    this.duration,
    this.startTime,
    this.bitrate,
    this.size,
    this.tagsJson,
    this.allPropertiesJson,
    this.streams = const [],
    this.chapters = const [],
  });

  @override
  String toString() =>
      'MediaInformation(filename: $filename, format: $format, duration: $duration, streams: ${streams.length}, chapters: ${chapters.length})';
}
