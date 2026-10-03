import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final readme = File('README.md').readAsStringSync();
  final quickStart = File('doc/quick-start.md').readAsStringSync();

  test('canonical Hooks installation example is valid YAML', () {
    final block = RegExp(r'```yaml\s*(.*?)```', dotAll: true)
        .allMatches(readme)
        .map((match) => match.group(1)!)
        .firstWhere(
          (candidate) =>
              candidate.contains('hooks:') &&
              candidate.contains('ffmpeg_kit_extended_flutter:'),
        );
    final parsed = loadYaml(block) as YamlMap;
    final packageConfig = (parsed['hooks'] as YamlMap)['user_defines']
        as YamlMap;
    final pluginConfig =
        packageConfig['ffmpeg_kit_extended_flutter'] as YamlMap;

    expect(pluginConfig['type'], 'base');
    expect(pluginConfig['gpl'], true);
    expect(pluginConfig['small'], true);
  });

  test('bundle type documentation describes the legacy alias', () {
    expect(readme, contains('The legacy `streaming` value is accepted as an alias for `video`.'));
    expect(quickStart, contains('The legacy `streaming` value is accepted as an alias for'));
    expect(quickStart, contains('`video`.'));
  });
}
