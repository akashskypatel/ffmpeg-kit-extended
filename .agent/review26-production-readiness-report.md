# Review 26 Functional Production-Readiness Report

Date: 2026-09-23

## Authority and finding

- Starting wrapper SHA: `18bf4a1a32c68bda2d123c33d7c44c3a9ff413f9`.
- Frozen native source SHA: `625c3452ee3c93fb5d701bb6546726940b88d014`.
- Native ABI source and `libs/libffmpegkit` were not changed by this review.
- The functional defect was process-global structured-log registration ownership
  in the React Native shared C++ and Windows bridges. Each module retained safe
  local callback state, but stale teardown could still unconditionally clear a
  newer module's process-global native registration.

## Implementation design

`react-native/cpp/LogBridgeRegistrationCoordinator.h` provides one semantic
coordinator for both bridges. It serializes install and teardown, records an
owner only after the native install succeeds, clears ownership only after the
native disable succeeds, and conditionally disables the native registration
only for the current owner. A later successful install replaces the owner;
stale teardown never restores an older registration. Existing Review 25 state
lifetime and Web callback-slot behavior remain unchanged.

## Files changed

- `react-native/cpp/LogBridgeRegistrationCoordinator.h`
- `react-native/cpp/FFmpegKitExtendedImpl.cpp`
- `react-native/windows/FFmpegKitExtended/FFmpegKitExtended.cpp`
- `react-native/tests/native-bridge-lifetime.test.js`
- `react-native/tests/native/log_bridge_registration_coordinator_test.cpp`
- `react-native/TEST.md`
- `flutter/README.md`
- `.agent/TRACKER.md`

## Behavioral and local validation

- `node --test tests/native-bridge-lifetime.test.js`: **3/3**.
- Coordinator translation unit and executable ownership fixture compiled with
  `g++.exe -std=c++20 -pthread -Wall -Wextra -Werror` and passed ownership
  replacement, stale teardown, failure, and concurrency assertions with exit
  `0`.
- Elevated React Native `npm run check`: typecheck and lint passed; Node suite
  passed **162/162**. The only lint output was the existing unnecessary-escape
  warning in `tests/arguments.test.js`.
- `npm run test:pack-types`, `npm run test:pack-web`, and `npm pack --dry-run`
  passed.
- `npm run test:web` passed the local WebAssembly smoke flow: initialization,
  repeated initialization, FFmpeg, FFprobe, media information, FFplay,
  pause/resume/stop, and the final WebAssembly assertion.
- The local Windows Release MSBuild passed using the supplied WSL-local
  `bundle-base-windows-x86_64-shared-lgpl.zip` and produced
  `react-native/example/windows/x64/Release/FFmpegKitExtended.dll` and
  `FFmpegKitExtendedExample.exe`.

No hosted Flutter/React Native workflow and no remotely staged binary were used.
The Web, Windows, and Linux resolver configuration continues to point to the
supplied WSL-local archives.

## Residual risk and scope

This change does not change the native ABI, the Web callback-table design, or
the Review 25 bounded state-lifetime policy. Android, Apple, and native Linux
runtime builds were not run on this Windows host because no matching local
runtime/toolchain gate was supplied; this is an environment-scope limitation,
not a native ABI blocker. The builder checkout and its prebuilt archives were
not modified.

## Source freeze

The documentation closeout commit is the implementation/source-freeze point.
Its exact SHA, tree SHA, and the separately requested repository source-snapshot
workflow run and artifact download link are recorded in `.agent/TRACKER.md`
after the snapshot-only workflow completes. The snapshot is provenance only and
does not constitute Flutter or React Native runtime validation.
