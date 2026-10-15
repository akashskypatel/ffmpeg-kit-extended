// W-F04 source contract (plan §P3.0a item 3, AUTH-FFPLAY-SYNC): the deprecation
// is present and no synchronous backend call remains in FFplaySession. This is a
// VM-only file because it reads the library source.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('execute() carries the deprecation and no sync backend call remains', () {
    final source = File('lib/src/ffplay_session.dart').readAsStringSync();

    expect(
      source,
      matches(
        RegExp(
          r"@Deprecated\(\s*'Synchronous FFplay execution is not supported[\s\S]*?\)\s*FFplaySession execute\(\)",
        ),
      ),
    );
    expect(source, isNot(contains('executeSynchronously')));
    expect(source, isNot(contains('executeFFplaySession(')));
  });
}
