# Flutter local testing

The Flutter Marionette interactive agent contract is documented in
[`example/interactive-tests/marionette.md`](example/interactive-tests/marionette.md)
and the cross-wrapper matrix is in
[`../docs/interactive-testing.md`](../docs/interactive-testing.md).
All interactive targets use the configured local ABI/runtime only.

Flutter interactive tests are local-only because the frozen native ABI is not
published for hosted test runners. Use the existing Hooks configuration in
`flutter/pubspec.yaml` and `flutter/example/pubspec.yaml`; do not introduce a
second runtime resolver or replace a local override with a release URL.

## Read-only runtime preflight

Before launching an interactive target, inspect the override for that target
in the applicable `ffmpeg_kit_extended_config` map and confirm that the path
exists on the host running Flutter. The override may be a local archive or a
local directory, depending on the platform. This check is intentionally
read-only: it must not download, extract, copy, cache, or mutate an artifact.

The configured runtime ABI is **0.11.2**. A missing local path is a blocker;
do not fall back to the published release. On Windows, the Linux and Android
paths use the existing `\\wsl.localhost\ManyLinux\...` local builder paths.
On the MacBook Air, the Apple paths use the existing
`/Users/akash/Projects/ffmpeg-kit-builders/prebuilt/apple/xcframeworks/...`
archives. Verify the path on the target host rather than assuming that a path
from another host is mounted.

The recommended command preflight for Flutter/Dart local locking symptoms is
an elevated shell followed by:

```bash
flutter config --no-analytics
dart --disable-analytics
```

Tag spawned processes with `FFMPEG_KIT_TASK_TAG`, observe bounded commands, and
terminate a confirmed stale or hung task-owned process before retrying it.
Record an unavailable target as **not run** with the exact path or tool
blocker; never report a local interactive pass without an executed target.

## Static package checks

From `flutter/`, use the elevated, tagged shell preflight above when needed,
then run `flutter pub get`, `flutter analyze`, and `flutter test`. From
`flutter/example/`, run `flutter pub get`, `flutter analyze`, and the supported
example/integration tests for the selected local target.
