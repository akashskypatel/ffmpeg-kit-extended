# Review 36 Flutter + React Native Cross-Platform Remediation Plan

Date: 2026-09-29  
Audience: Luna implementation model  
Repository: `akashskypatel/ffmpeg-kit-extended`

## Authority and scope

Review 36 is based on the frozen Review 35 wrapper source at
`d6afceabfe7baa9190a20342aad9e7e87a59a803`.

- Snapshot workflow: `36521169004`
- Snapshot artifact: `repo-source-snapshot-36521169004`
- Artifact ID: `11013156574`
- Artifact digest: `sha256:9216d85557af470f06f4db7be41cdce519bc6f4111ac257b1c939369798815c2`
- Embedded source archive SHA-256: `2d2b8623b50b275b01e388aca68da42d1d854dfbd90bc3dcede2020c3d64f75e`
- Wrapper manifest: `1,066/1,066` files verified
- Frozen submodule: `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`
- Native runtime: `0.11.2`, frozen and read-only

This plan changes Flutter and React Native wrappers and focused tests only. Do
not edit `libs/libffmpegkit`, the ManyLinux builder checkout, native ABI
sources, or native ABI publication/configuration. Do not retrieve remote old
binaries or use hosted Flutter/React Native CI. Use the existing local
artifacts already configured by the repository.

Review and implementation identifiers are metadata only. Production names and
tests must describe completion lifetime barriers, ID-scoped abandonment,
durable Created cancellation, or other semantic behavior.

## Findings to remediate

| Finding | Severity | Required outcome |
| --- | --- | --- |
| R36-F1 | High | Flutter completion callbacks and queue settlement must not access a native/Web handle after a callback requested disposal. |
| R36-F2 | Medium-High | React Native native and Web must reject direct lookup and execution handoff for an explicitly abandoned Created session ID. |
| R36-F3 | Medium-High | Flutter pre-submission cancellation must survive weak-history wrapper reconstruction and remain non-executable by session ID. |

## Goals and implementation order

### Goal 1 — Flutter completion lifetime barrier

Implement a wrapper-owned lifetime scope around both session-specific and
global completion delivery for FFmpeg, FFprobe, MediaInformation, and FFplay.

Required invariants:

1. Observe terminal native state and commit terminal history before callbacks.
2. Enter a completion lifetime scope before local callback delivery.
3. Deliver local and global callbacks while the owned handle remains valid.
4. If any callback calls `dispose()`, defer physical handle release.
5. Let queue-owned settlement complete all internal handle-dependent work.
6. Release the deferred handle exactly once after callback fan-out and
   settlement are complete.
7. Make terminal reconciliation check an already-terminal history marker before
   any backend state read. Repeated reconciliation must not read a disposed
   session.

Do not merely reverse callback order. Either callback may request disposal.

### Goal 2 — React Native ID-scoped Created abandonment

Use the existing semantic history authority plus a distinct ID-only abandoned
tombstone state for native and Web wrappers.

Required behavior:

- Queue discard and Created cancellation record abandonment by native session ID.
- `getSession(id)` consults the same authority as list/last history and fails
  closed for an abandoned ID.
- `prepareForExecution()` and the native/Web execution handoff reject an
  abandoned ID even when a stale wrapper was retained or reconstructed.
- Normal Created sessions remain executable.
- Terminal records remain intact when an already-terminal ID is passed to the
  Created-abandonment operation.
- `clearSessions()` clears the wrapper tombstone authority.
- Remove tombstones when the native session is known gone; do not build a
  second process-lifetime mirror of every session.

The frozen ABI already contains the needed session operations. Do not add an
export or modify C++/native code.

### Goal 3 — Flutter durable pre-submission cancellation

Use the Flutter session-history authority to retain an ID-only abandoned state.

- Direct cancellation of a never-submitted Created session records the ID
  before returning.
- Queue discard uses the same operation.
- `registerCreatedSession()` and history reconstruction cannot restore an
  abandoned ID.
- `validateExecutionHandoff()` fails closed by ID before native execution.
- Ordinary Created, Running, and terminal sessions retain their existing
  behavior.
- No abandoned state may strongly retain a Dart wrapper or native handle.
- Clearing the history authority clears abandoned tombstones.

### Goal 4 — Focused regressions and local platform matrix

Run focused wrapper regressions first. Then run local validation in this order,
with no GitHub workflow tests:

1. Windows Flutter and React Native wrapper tests/builds.
2. Android wrapper tests/builds on local Windows.
3. Linux wrapper validation under WSL.
4. Wasm/Web Flutter and React Native tests/builds/smoke checks.
5. Apple Flutter and React Native builds/tests last on the user's MacBook Air
   through the authorized SSH host.

Use analytics-disabled commands:

```text
flutter config --no-analytics
dart --disable-analytics
```

Tag every task-owned process, observe boundedly, and terminate confirmed hangs
before retrying. Clean task-owned temporary output and verify no orphaned
Flutter, Dart, Node, Gradle, SSH, or test process remains.

### Goal 5 — Freeze and snapshot wrapper source

After implementation and local evidence are complete:

- reconcile only affected tracker and review material;
- commit and push each completed implementation goal with a meaningful message;
- freeze the exact wrapper SHA before snapshot dispatch;
- run `.github/workflows/repo-source-snapshot.yml` once for wrapper source;
- record workflow run ID, artifact ID, artifact link, digests, manifest count,
  and recursive submodule state in `.agent/TRACKER.md`;
- do not create a native ABI or builder snapshot.

## Acceptance invariants

- A completion callback may dispose a session without causing subsequent global
  callback or queue settlement code to use a released handle.
- Repeated terminal reconciliation performs no backend state read after the
  terminal marker is committed.
- A cancelled/discarded Created RN ID cannot be found by direct lookup or
  executed after wrapper reconstruction on native or Web.
- A cancelled/discarded Created Flutter ID cannot be reconstructed as an
  executable wrapper.
- No native ABI, submodule, or builder checkout change is present.
- All claims in the tracker are backed by completed local commands and exact
  commit/SHA evidence.
