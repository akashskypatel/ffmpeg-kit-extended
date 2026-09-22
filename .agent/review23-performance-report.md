# Review 23 performance and compatibility report

Date: 2026-09-22

This report records the A/B/C callback-transport oracle required by Review 23.
It describes observed test counters, not a cross-device throughput benchmark.
The exact native ABI authority for all wrapper rows is
`196567dae7fd1509c33bf32081f8237596ac8e5b` in the ManyLinux builder checkout.

## Counter definitions

- **A — no optional consumers:** asynchronous completion is requested without a
  log or statistics consumer.
- **B — direct steady state:** a v2 log consumer receives contiguous direct
  events; indexed history must not be read while the session is running.
- **C — terminal reconciliation:** a late or missing direct event is reconciled
  once at terminal state using the retained count and only the bounded missing
  history range.
- **Live events** counts delivered direct log payloads. **History reads** counts
  indexed log reads; **count reads** is the scalar retained-log-count read.
  **Alloc/free** is reported only where the test instrumented ownership. The
  wrapper fixtures do not expose native allocator counters, so a numeric value
  is not invented for those rows.
- **Wall time** is recorded as an observed gate duration below. These are
  harness/toolchain observations, not comparable device benchmarks and not
  causal evidence of callback cost; the primary performance assertion is zero
  steady-state indexed history polling and zero optional traffic in A.

## Flutter native

Source-level counters come from `flutter/test/v2_log_event_test.dart`; native
redirection behavior comes from the 3/3 filtered high-level tests in
`flutter/test/api_test.dart`.

| Case | Wall time | Live events | History reads | Count reads | Alloc/free | Delivered | Duplicates | Missing |
| --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| A no consumers | 12.14 s combined focused Flutter gate | 0 optional log/stat callbacks | 0 in v2 fixture | 0 | Not instrumented in wrapper; native ownership oracle passed | completion only | 0 | 0 |
| B direct steady state | 12.14 s combined focused Flutter gate | 1 contiguous event | 0 | 0 | Not instrumented in wrapper | 1 | 0 | 0 |
| C terminal gap/flush | 12.14 s combined focused Flutter gate | 1 late event in the gap case | 1 bounded reconciliation read | 1 authority read | Not instrumented in wrapper; payload release tests passed | 3 in recoverable gap; 1 in flush case | 0 | 0 when recoverable; unresolved-gap case intentionally delivers 0 |

The native redirection test also proves completion with zero log/statistics
callbacks while redirection is disabled, and direct log delivery after explicit
enable. This separates core redirection authority from wrapper consumer demand.

## Flutter Web

The same v2 fixture counters apply to the wrapper algorithm. The packaged
default Web runtime browser smoke passed through the v1 compatibility fallback,
but the exact custom v2 browser runtime could not be executed with Flutter 3.47
because custom/non-default Web selection requires Dart DataAssets and the
toolchain reports `buildDataAssets: false`. This is a documented toolchain
capability boundary; no workaround or custom-runtime performance claim is made.

| Case | Wall time | Live events | History reads | Count reads | Alloc/free | Delivered | Duplicates | Missing |
| --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| A no consumers | No custom-v2 browser time; DataAssets gate blocked | 0 optional events in fixture | 0 in v2 fixture | 0 | Not instrumented in wrapper; Wasm ownership tests passed | completion only | 0 | 0 |
| B direct steady state | No custom-v2 browser time; DataAssets gate blocked | 1 contiguous event in fixture | 0 | 0 | Not instrumented in wrapper; owned-payload release oracle passed | 1 | 0 | 0 |
| C terminal gap/flush | No custom-v2 browser time; DataAssets gate blocked | 1 late event in fixture | 1 bounded read | 1 authority read | Not instrumented in wrapper; release-on-error oracle passed | 3 in recoverable gap | 0 | 0 when recoverable |

The local default-runtime browser result is compatibility evidence only: it
verified initialization, FFmpeg, FFprobe, media information, and the v1
fallback. Browser-based Wasm validation must remain local; a workflow build is
not browser-runtime evidence.

## React Native native

The native consumer builds passed on Android and Windows against the frozen ABI
handoff; unpublished-ABI runtime execution remains local/source-controlled by
policy. The direct counter oracle is
`react-native/tests/wasm-session-ownership.test.js`, which models the same
backend contract used by the native and Web adapters.

| Case | Wall time | Live events | History reads | Count reads | Alloc/free | Delivered | Duplicates | Missing |
| --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| A no consumers | 5.45 s `npm run check` gate | 0 optional events | 0 | 0 | Not instrumented in JS fixture; native ownership gates passed | completion only | 0 | 0 |
| B direct steady state | 5.45 s `npm run check` gate | 2 direct events | 0 | 1 terminal authority read | Not instrumented in JS fixture; native bridge copies/releases internally | 2 | 1 duplicate ignored | 0 |
| C terminal gap | 5.45 s `npm run check` gate | 1 late direct event | 1 bounded history read | 1 | Not instrumented in JS fixture; native/Wasm free-once tests passed | 3 ordered events | 0 | 0 |

The no-consumer case records zero log/statistics reads and completion bridge
demand only. The disabled-redirection case records zero delivered log/stat
events and zero implicit `enableRedirection()` calls.

## React Native Web

The source fixture and local headless `npm run test:web` are the Web evidence;
the packed type/Web consumer gates also passed with an isolated cache.

| Case | Wall time | Live events | History reads | Count reads | Alloc/free | Delivered | Duplicates | Missing |
| --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| A no consumers | 6.44 s local `npm run test:web` gate | 0 optional events | 0 | 0 | JS wrapper not allocator-instrumented; Wasm bridge ownership tests passed | completion only | 0 | 0 |
| B direct steady state | 6.44 s local `npm run test:web` gate | 2 direct events | 0 | 1 terminal authority read | Wasm bridge free-once oracle passed | 2 | 1 duplicate ignored | 0 |
| C terminal gap | 6.44 s local `npm run test:web` gate | 1 direct event after a gap | 1 bounded history read | 1 | Wasm bridge free-once oracle passed | 3 ordered events | 0 | 0 |

## Native ownership and sanitizer cross-check

The native final handoff evidence provides the allocator/sanitizer side of the
report: the Review 23 native/Wasm oracle and Wasm callback suite passed; final
ASAN/LSAN had 108/111 passing tests with only the three known FFmpeg 9.0 hard
TLS failures and no sanitizer report; the combined Wasm callback evidence was
11/11. TSAN's two remaining frame-data publication/lifetime warnings and the
UBSAN GCC 14/libstdc++ vptr diagnostics are documented toolchain/upstream
limitations and are not callback-transport blockers. They were not hidden by
filters or workaround code.

## Compatibility policy

- ABI v2 is additive; v1 buffered history remains an explicit fallback.
- Native history getters remain public for inspection and bounded reconciliation.
- Direct live delivery is sequence-ordered, duplicate-suppressing, and does not
  poll complete history in steady state.
- Completion is independent of optional log/statistics consumers.
- `enableRedirection()` is never an implicit side effect of bridge demand;
  `disableRedirection()` remains authoritative.
- Accepted native messages are copied and freed internally; no dangling pointer
  is exposed to Flutter, React Native, Dart, or JavaScript.
- Custom Flutter Web/Wasm runtime selection requires Dart DataAssets.
- `ffigen_js: ^0.0.16-pre` is intentionally retained because no stable release
  exists.
