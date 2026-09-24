import 'dart:io';

import '../hook/build.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run test/hook_cache_worker.dart SOURCE DESTINATION',
    );
    exitCode = 64;
    return;
  }

  await syncLocalOverride(File(args[0]), File(args[1]));
}
