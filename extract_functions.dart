import 'dart:io';

void main() {
  final file = File(
    'd:/Projects/ffmpeg-kit-extended/flutter/lib/src/generated/ffmpeg_kit_bindings.dart',
  );
  final lines = file.readAsLinesSync();
  final functionRegex = RegExp(r'^\s+([a-zA-Z0-9_<>\s]+)\s+([a-z0_9_]+)\(');
  final functions = <String>[];
  bool inClass = false;

  for (final line in lines) {
    if (line.contains('class FFmpegKitBindings')) {
      inClass = true;
      continue;
    }
    if (inClass) {
      final match = functionRegex.firstMatch(line);
      if (match != null) {
        final name = match.group(2);
        if (name != null && !name.startsWith('_')) {
          functions.add(name);
        }
      }
    }
  }

  final output = File('d:/Projects/ffmpeg-kit-extended/functions_list.txt');
  output.writeAsStringSync(functions.join('\n'));
}
