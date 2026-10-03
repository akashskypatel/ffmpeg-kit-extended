# Review 48 React Native cancellation closure plan

Prepared implementation plan for the downloaded Review 48 plan.

- Downloaded source: `C:\Users\Akash\Downloads\review-48-luna-flutter-react-native-closure-plan.md`
- Source SHA-256: `D8D7E72272F01EAB9139AF068F18FB705DEFF0F8D38A1FDEF11CA677DD9C0251`
- Starting wrapper SHA: `33ed987ef35be4acb446c78c7b2181b06995228b`
- Frozen native submodule SHA: `b74da2c5d1e294b87d15d73a6687393729e932b3`

## Implementation sequence

1. Extend the internal cancellable-session contract with an optional semantic pre-execution marker.
2. Add `Session.markCancelledBeforeExecution()`; it only records local cancellation state.
3. Invoke that marker from queue discard before cleanup; never call full `Session.cancel()` for queued discard.
4. Make `Session.cancel()` return early only after successful native cancellation dispatch or committed Created abandonment. Preserve retry paths and durable submitted-session intent.
5. Add direct retained-object, marker-authority, repeated-cancel, failed-abandonment-retry, and Running-retry regressions.
6. Refactor `cancelAll()` so queued removal/cleanup is initiated first and active cancellation is initiated immediately afterward, before awaiting either branch. Await all initiated promises, attempt all active sessions, and preserve first-error identity.
7. Add a deferred-cleanup ordering regression and synchronous-error coverage only where existing seams support it.
8. Update public README/TSDoc with semantic queued-cancellation, repeated-cancellation, and cancel-all guarantees. Keep internal comments concise and free of review identifiers.

## Validation and closeout

Run local React Native typecheck, test compilation, lint, focused queue/observer/Web ownership tests, full Node suite, and the smallest established local Web/Wasm gate. Run required native wrapper validation locally in this order: Windows, Android on local Windows, Linux/WSL where affected, and Apple iOS/tvOS/macOS last over the authorized MacBook Air SSH connection. Do not use hosted acceptance workflows.

If Flutter/shared packaging remains unchanged, perform bounded no-drift verification and preserve accepted prior evidence rather than rerunning the full Flutter matrix. Verify the native submodule and ManyLinux builder checkout remain unchanged.

After a zero-finding audit, freeze and push the exact wrapper SHA, run one wrapper-only source snapshot at that SHA, verify artifact and embedded manifest digests/metadata, and record the run ID, artifact ID/name/link, digests, manifest count, symlink count, `runtimeExecution=false`, and frozen submodule SHA in the tracker. Tracker-only closeout commits occur after the frozen source authority is recorded.

## Naming rule

Review, goal, and finding identifiers are metadata only. Production symbols, tests, comments, and user-facing wording must describe cancellation state, abandonment, retry, queue cleanup, and active-delivery semantics.
