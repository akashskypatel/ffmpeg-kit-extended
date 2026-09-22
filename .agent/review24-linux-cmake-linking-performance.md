# Review 24 N7 — Linux CMake linking-resolution evidence

## Scope

FFK24-N7 targets the dependency resolver in
`FFmpegKit/cmake/FfmpegKitLinkingHelpers.cmake`. The initial performance fix
was Linux-focused; the follow-up below unifies the lookup path for all native
platform branches:

- pkg-config-derived search directories are cached for the configure invocation;
- static archive lookup uses cached direct-entry candidates for every platform;
  it never recursively scans a search root;
- project-static resolution routes through the same direct-only search path on
  Linux, Emscripten, Windows, macOS, and other native branches;
- Windows prefers `.lib` candidates while MinGW and Unix-like targets use `.a`,
  and the existing `.dll`, `.dylib`, `.tbd`, and versioned `.so` conversions
  remain platform-specific;
- nested archives are resolved only when their containing directory is
  explicitly supplied by the caller. This removes the cross-platform recursive
  lookup ambiguity rather than widening search scope.

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

## Cross-platform non-recursive follow-up

Native follow-up commit
`13f45218fc562c9cf4f90da38da479874df8b404` replaces both the Linux recursive
archive index and the non-Linux recursive glob with one cached direct-entry
resolver. It also adds `.lib` basename/candidate handling and corrects Windows
`.dll`/`.lib` and macOS `.a`/`.dylib` conversion coverage without changing the
Linux `.so` or Apple `.tbd` rules.

Follow-up commit
`e43b51eebe2f42fac658a0dbbc3ee3e47dd55c2f` preserves the MinGW
`.dll.a` import-library-to-`.dll` path and adds a focused regression case.

The focused CMake fixture passed with the following cases:

- nested-only archives are rejected unless the nested directory is explicitly
  supplied;
- direct pkg-config roots, direct project archives, and cached misses resolve;
- simulated MSVC `.lib`/`.dll` and macOS `.a`/`.dylib` conversions pass;
- `GLOB_RECURSE`, the old archive-index helper, and its recursive call sites are
  absent from `FfmpegKitLinkingHelpers.cmake`.

The exact approved Linux runner was rerun after the follow-up and completed with
exit status `0`; CMake reported `Configuring done (0.4s)` and the full runner
elapsed time was `13s`. The existing `distclean`/`uninstall` no-rule and license
touch warnings remained non-fatal. Windows/macOS builder runners were not
available in the ManyLinux environment, so their suffix behavior is covered by
the focused CMake platform simulations and remains subject to their native CI
builds.

## Resolver fixture and build evidence

- `FFmpegKit/tests/cmake/linking_helpers_test.cmake` covers two pkg-config
  roots, nested decoys, direct archives, `-lfoo`, cached misses, explicit
  nested-directory lookup, Windows `.lib`/`.dll`, macOS `.a`/`.dylib`, and
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

Native implementation commits: `e9de4755a66d437cd2d070fbec2f81a9783e03aa`
(Linux performance fix),
`13f45218fc562c9cf4f90da38da479874df8b404` (cross-platform non-recursive
follow-up), and
`e43b51eebe2f42fac658a0dbbc3ee3e47dd55c2f` (MinGW import-library follow-up),
all pushed to `ffmpeg-kit-builders` `origin/dev`.
