# Review 36 — Flutter + React Native Cross-Platform Code Review

Date: 2026-09-29  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Review type: frozen-source code review, pedantic findings excluded

## Frozen authority

- Wrapper SHA: `d6afceabfe7baa9190a20342aad9e7e87a59a803`
- Snapshot workflow: `36521169004`
- Snapshot artifact: `repo-source-snapshot-36521169004`
- Artifact ID: `11013156574`
- Artifact digest: `sha256:9216d85557af470f06f4db7be41cdce519bc6f4111ac257b1c939369798815c2`
- Embedded source archive SHA-256: `2d2b8623b50b275b01e388aca68da42d1d854dfbd90bc3dcede2020c3d64f75e`
- Manifest: `1,066/1,066` files verified
- Frozen submodule: `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`
- Native ABI/runtime: `0.11.2`, frozen/read-only, not downloaded or re-reviewed

The review inspected wrapper source only. It did not run tests, builds, CI,
runtime smoke, simulator/device execution, or repository mutation. Style,
naming, formatting, documentation-only drift, missing-test-only observations,
speculative hardening, and low-impact pedantry were excluded.

## Executive disposition

The frozen Review 35 wrapper is not code-review clean. Three substantive
wrapper lifecycle defects remain; no finding requires a native ABI change.

## Findings

### R36-F1 — Flutter completion-callback disposal remains unsafe

Severity: High  
Surface: Flutter native and Web session wrappers

Review 35 commits terminal history before user callbacks, but completion
fan-out and queue settlement continue using the same session afterwards. A
supported sequence is:

```text
terminal state observed
-> terminal history committed
-> local completion callback calls dispose()
-> native/Web handle released
-> global completion callback receives the disposed session
-> queue settlement calls markExecutionSettled()
-> reconciliation reads session.getState() again
```

`reconcileCompletedSession()` reads backend state before checking the terminal
marker, so the second reconciliation can cross FFI/Wasm with a released
handle. The local-before-global ordering is not itself the fix: either callback
can dispose the session.

Required remediation is a wrapper-owned completion lifetime barrier. Physical
release must be deferred until terminal history commit, local callback, global
callback, and queue-owned settlement have all stopped using the handle.
Repeated reconciliation must check the terminal marker before any backend read.

### R36-F2 — React Native Created abandonment can be bypassed by ID lookup

Severity: Medium-High  
Surface: React Native native and Web

Review 35's `abandonCreatedSession()` removes semantic list/last-history
metadata, but `FFmpegKitExtended.getSession(id)` directly calls
`getSessionJson(id)`. Native and Web can reacquire the Created session by ID
even after its history record was removed. `sessionFromSnapshot()` then creates
a fresh wrapper whose cancellation, submission, and abandonment fields are
reset. The stale ID can be executed and may remain absent from list/last
history, producing split-brain lifecycle state.

Required remediation is an ID-scoped wrapper authority shared by native and
Web: direct lookup fails closed, execution handoff fails closed, ordinary
Created sessions remain valid, terminal history is preserved, and the
authority is cleared with wrapper session history. The frozen ABI must not be
changed.

### R36-F3 — Flutter pre-submission cancellation is not durable

Severity: Medium-High  
Surface: Flutter native and Web

Flutter history stores a weak wrapper reference. Direct cancellation of an
unsubmitted Created session sets `_isCancelled` on the current object but does
not durably abandon its history identity. If that weak wrapper disappears,
history reconstruction creates a fresh wrapper with `_isCancelled == false`
and `_submitted == false`; the same Created native ID can execute. Behavior
therefore depends on wrapper/GC lifetime.

Required remediation is an ID-only abandoned state in the history authority.
Direct cancellation and queue discard must use it; reconstruction and
execution handoff must reject the ID; normal Created, Running, and terminal
behavior must remain unchanged; and no strong wrapper/handle reference may be
added.

## Retained non-findings

- Review 35 terminal-history commitment, cleared-history cleanup, and RN
  scalar state polling remain the baseline outside these defects.
- RN Web MediaInformation classification remains correctly ordered before
  FFprobe.
- Existing native-session-ID queue reservation and duplicate-admission guards
  remain in scope and must not regress.
- No native/builders finding was established because native source was frozen
  and intentionally not re-reviewed.

## Review closeout

Substantive findings: 3  
Pedantic/style/docs-only findings reported: 0  
Native ABI change required: no  
Tests/builds/runtime during review: no  
Promotion before remediation: not recommended
