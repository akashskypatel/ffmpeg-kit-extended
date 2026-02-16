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

/// Represents a chapter within a media file.
class ChapterInformation {
  /// The unique ID of the chapter.
  final int? id;

  /// The time base used for chapter timestamps.
  final String? timeBase;

  /// The start time in `time_base` units.
  final int? start;

  /// The start time in seconds as a string.
  final String? startTime;

  /// The end time in `time_base` units.
  final int? end;

  /// The end time in seconds as a string.
  final String? endTime;

  /// A JSON string containing chapter tags.
  final String? tagsJson;

  /// A JSON string containing all chapter properties.
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

  /// Creates a new [ChapterInformation] instance with the given metadata.
  ChapterInformation({
    this.id,
    this.timeBase,
    this.start,
    this.startTime,
    this.end,
    this.endTime,
    this.tagsJson,
    this.allPropertiesJson,
  });

  @override
  String toString() =>
      'ChapterInformation(id: $id, start: $startTime, end: $endTime)';
}
