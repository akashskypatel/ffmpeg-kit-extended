import 'package:test/test.dart';

import '../hook/build.dart';

void main() {
  const hostilePaths = [
    r'C:\cache\archive with spaces.zip',
    r'C:\缓存\архив.zip',
    r'C:\cache\$(Get-Date).zip',
    r'C:\cache\$archive.zip',
    r'C:\cache\archive;exit.zip',
    r"C:\cache\archive's.zip",
    r'C:\cache\archive (copy).zip',
  ];

  test('keeps archive and destination paths out of PowerShell source', () {
    const destination = r'C:\output\$(Invoke-Expression "bad")';
    final ordinary = buildWindowsArchiveExtractionInvocation(
      r'C:\cache\ordinary.zip',
      r'C:\output\ordinary',
    );

    expect(ordinary.arguments, contains('-NoProfile'));
    expect(ordinary.arguments, contains('-NonInteractive'));
    expect(ordinary.arguments, contains(windowsArchiveExtractionScript));
    expect(windowsArchiveExtractionScript, contains('-LiteralPath'));
    expect(windowsArchiveExtractionScript, isNot(contains('ordinary.zip')));
    expect(windowsArchiveExtractionScript, isNot(contains('ordinary')));

    for (final archive in hostilePaths) {
      final invocation = buildWindowsArchiveExtractionInvocation(
        archive,
        destination,
      );

      expect(invocation.arguments, contains(windowsArchiveExtractionScript));
      expect(invocation.environment['FFMPEG_KIT_ARCHIVE'], archive);
      expect(invocation.environment['FFMPEG_KIT_DESTINATION'], destination);
      expect(windowsArchiveExtractionScript, isNot(contains(archive)));
      expect(windowsArchiveExtractionScript, isNot(contains(destination)));
      expect(invocation.arguments.where((value) => value == archive), isEmpty);
      expect(
        invocation.arguments.where((value) => value == destination),
        isEmpty,
      );
    }
  });

  test('uses one identical constant script for ordinary and hostile paths', () {
    final scripts = hostilePaths
        .map(
          (archive) => buildWindowsArchiveExtractionInvocation(
            archive,
            r'C:\output\destination',
          ).arguments.last,
        )
        .toSet();

    expect(scripts, {windowsArchiveExtractionScript});
    expect(windowsArchiveExtractionScript, contains('Expand-Archive'));
    expect(windowsArchiveExtractionScript, contains('-LiteralPath'));
    expect(windowsArchiveExtractionScript, contains('FFMPEG_KIT_ARCHIVE'));
    expect(windowsArchiveExtractionScript, contains('FFMPEG_KIT_DESTINATION'));
  });
}
