# Review 35 — Flutter + React Native Cross-Platform Code Review

**Project:** FFmpegKitExtended  
**Review type:** source-only code review  
**Date:** 2026-09-28  
**Repository:** `akashskypatel/ffmpeg-kit-extended`  
**Frozen wrapper source:** `c9682fb8a7f98141b1566374b0f7c827aedd7e1b`  
**Snapshot workflow:** `36510171029`  
**Snapshot artifact:** `review34-final-wrapper-source-36510171029`  
**Artifact ID:** `11008563205`  
**Artifact digest:** `sha256:d6cb8721369974a3dcd50f3c7217fa2041241621401e2ef7842cecfa4038bb2e`  
**Embedded `source.tar.gz` SHA-256:** `e6810e3d1247aebec7cfaca7ac2e75e9f8d42c384444555469fb6b075ee621b7`  
**Manifest:** **1,066/1,066 files verified**  
**Native ABI:** frozen/read-only; not downloaded or re-reviewed  
**Native runtime:** `0.11.2`

## Review boundary

Review 35 used only the final Review 34 wrapper snapshot recorded in `.agent/TRACKER.md`.
It was code review only: no tests, builds, hosted CI, simulator/device execution,
interactive application execution, or repository mutation. Style, documentation-only
drift, coverage-only observations, speculative hardening, and low-impact pedantry were
excluded.

## Executive disposition

The frozen wrapper is not code-review clean. Three substantive lifecycle defects were
found. No finding requires a frozen-native ABI change.

| ID | Severity | Surface | Finding |
| --- | --- | --- | --- |
| **R35-F1** | **High** | Flutter | Terminal history is committed after user completion callbacks. A callback that calls `session.dispose()` can delete the completed session's still-nonterminal identity before reconciliation. This affects FFmpeg, FFprobe, MediaInformation, and FFplay, in synchronous and asynchronous paths. |
| **R35-F2** | **Medium-High** | React Native native + Web | Queue-discarded Created sessions are not removed from wrapper history because discard cleanup calls retained-handle release before any retained execution handle exists. Repeated create/queue/cancel cycles can accumulate stale Created metadata. |
| **R35-F3** | **Medium** | Flutter | `clearSessions()` hides active identities, but terminal reconciliation prunes only visible entries. Hidden terminal records can remain in the identity map for the process lifetime. |

## R35-F1 — Commit Flutter terminal history before callbacks

`Session.dispose()` removes an identity while it is nonterminal. The synchronous
execution paths dispatch the completion callback before the `finally` block calls
`markExecutionSettled()`, which currently performs terminal reconciliation. The async
completion wrapper likewise invokes user code before queue settlement performs that
reconciliation. A callback that disposes the session therefore removes its identity
before the wrapper can mark native-terminal state.

The required behavior is to commit terminal history as soon as authoritative native
terminal evidence is available, before arbitrary user callback code, while retaining
queue settlement for cancellation-monitor shutdown, reservation release, queue
advancement, and execution-future settlement. The terminal transition must be
idempotent, preserve the primary execution error, and never mark a Created/Running
session terminal merely because startup or reconciliation failed.

## R35-F2 — Explicitly abandon queued Created identities

The shared queue supplies an `onDiscard` callback for every high-level session. That
callback currently releases an owning execution handle. Native `releaseSessionHandle`
returns immediately when the session has no entry in `retainedSessionHandles`; Web
`releaseSessionHandle` returns when no retained Wasm pointer exists. A queued,
never-started session is exactly that case, so the existing `removeNonTerminal...`
cleanup is unreachable.

Add a semantic wrapper bridge operation for explicit pre-execution abandonment. It must
remove only a nonterminal history identity after the caller has established that the
session was discarded before execution; it must be idempotent, must not release a
Running handle, must not cancel unrelated work, and must not modify the native ABI.
Use it for queue discard and for the selected permanent pre-submission cancellation
policy. Queue cancellation must keep the original cancellation rejection primary and
record cleanup failures as secondary diagnostics without stranding reservations.

## R35-F3 — Remove hidden Flutter identities when execution settles

`clearSessions()` correctly preserves live wrapper/callback ownership by marking active
history entries invisible. When those sessions later complete, terminal pruning ignores
invisible entries and ordinary disposal refuses to remove already-terminal entries.
The entry is no longer public history and no longer needs execution ownership, so it
must be removed at the terminal-history boundary. Disposal must also be allowed to
remove an invisible identity regardless of its terminal bit; visible terminal history
must continue to survive ordinary post-completion disposal.

## Required regression coverage

- Flutter sync and async FFmpeg, FFprobe, MediaInformation, and FFplay completion
  callbacks call `dispose()`; terminal history survives and native release is exactly once.
- Completion callbacks observe already-reconciled capacity; callback errors do not roll
  back terminal history; failed startup in Created state is not terminalized.
- React Native native and Web queue discard, `clearQueue`, repeated 1,000+ discard
  cycles, active/terminal preservation, idempotent abandonment, and primary cancellation
  error authority.
- Flutter running-session `clearSessions()` for normal, failed, and cancelled completion,
  multiple sessions, callback disposal, new sessions after clear, and no second getter or
  clear required for cleanup.

## Closeout

Implement and test only wrapper behavior. Validate locally in this order: Windows,
Android on Windows, Linux under WSL, Wasm/Web, and Apple last on the MacBook Air. Use
the already-established local `0.11.2` artifacts and universal Apple XCFrameworks.
Do not use hosted Flutter/React Native acceptance CI, remote old ABI bundles, native
publication, a builders/native snapshot, or interactive application execution. Freeze
and snapshot only the final wrapper source after the focused and platform gates pass.

