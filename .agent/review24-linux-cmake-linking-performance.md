# Review 24 N7 — Linux CMake linking-resolution evidence

## Scope

FFK24-N7 targets the Linux-local dependency resolver in
`FFmpegKit/cmake/FfmpegKitLinkingHelpers.cmake`. The change is Linux-only:

- pkg-config-derived search directories are cached for the configure invocation;
- Linux archive lookup uses one sorted recursive archive index per search root,
  including cached negative results, so repeated misses do not rescan the tree;
- Linux project-static resolution searches only the dependency and FFmpeg
  project roots. This avoids scanning unrelated system/pkg-config roots whose
  results would be rejected by `resolve_project_static_library` anyway;
- the existing Emscripten short-circuit and non-Linux recursive lookup path are
  retained.

## Baseline authority

Environment: elevated ManyLinux WSL2, x86_64; Linux kernel
`6.18.33.2-microsoft-standard-WSL2`; CMake `4.2.1`; GCC/G++ `14.2.1`;
pkg-config `1.4.2`.

The runner used the approved command:

```text
sudo ./runner.sh --host=linux --arch=x86_64 --skip -y --enable-base --build-deps --kit -fk --release=local
```

Build mode was shared, bundle type `base`, and the resolved roots were:

```text
FFMPEG_BUILD_DIR=/home/vscode/ffmpeg-kit-builders/prebuilt/linux-x86_64/ffmpeg-base-linux-x86_64-static
DEPENDENCY_BUILD_DIR=/home/vscode/ffmpeg-kit-builders/prebuilt/linux-x86_64/libraries
```

Before the change, all four dependency steps were already cached, but CMake
reported `Configuring done (130.8s)`. The complete runner elapsed time was
`143.79s`, exit status `0`. The CMake profile identified
`configure_static_linking`, `find_project_static_library_for_link`, and the
recursive archive lookup at `FfmpegKitLinkingHelpers.cmake:401` as the resolver
hot path. The repeated misses were the system shared runtimes
`libpthread-2.28.so`, `librt-2.28.so`, `libm.so`, and `libdl-2.28.so`.

## Before/after timing

Three clean isolated configure runs were made with identical Linux/GCC 14
inputs after the filesystem cache was warm:

| Helper | Runs (seconds) | Median |
| --- | ---: | ---: |
| pre-change | 0.39, 0.38, 0.40 | 0.39 |
| N7 change | 0.31, 0.31, 0.32 | 0.31 |

The end-to-end runner comparison is the material result: the same approved
command configured in `9.9s` and completed in `22.50s` after N7, exit status
`0`, a reduction of about 84% in total elapsed time and about 92% in the CMake
configure phase relative to the captured pathological baseline.

## Resolver fixture and build evidence

- `FFmpegKit/tests/cmake/linking_helpers_test.cmake` covers two pkg-config
  roots, nested decoys, direct archives, `-lfoo`, a cached miss, and
  shared-to-static project replacement.
- Project CTest registration passed: `ffmpegkit_cmake_linking_helpers`, **1/1**.
- The exact documented Linux gtest runner command from `TEST.md` completed with
  exit status `0` and built `ffmpegkit_tests`:

  ```text
  sudo ./runner.sh --host=linux --arch=x86_64 --enable-base --gpl --kit --build-deps --no-bundle --test=thread --build-debug --skip -y
  ```

- The full 111-test/17-suite executable run was started with the documented
  ASLR-safe command. It stopped at the pre-existing
  `FFmpegKitTest.GenerateTestVideoFile` test with no child encoder and 0% CPU
  for more than two minutes. The exact tagged process tree was terminated;
  this is recorded as a native test-execution blocker for the later N12 full
  suite, not as a resolver failure.
- A direct ad-hoc CMake test build without the runner's link settings exposed
  existing duplicate FFmpeg `framepool.o` symbols. No workaround was added;
  the supported `TEST.md` runner path built the target successfully.

The runner also emitted existing `distclean`/`uninstall` no-rule and license
touch warnings while returning success. No `configure_static_linking` unresolved
entry warnings were emitted; the four “No static replacement found” messages
are the expected preserved system shared-runtime decisions.

Native implementation commit: `e9de4755a66d437cd2d070fbec2f81a9783e03aa`,
pushed to `ffmpeg-kit-builders` `origin/dev`.
