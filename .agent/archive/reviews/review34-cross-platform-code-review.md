# Review 34 — Flutter + React Native cross-platform code review

Date: 2026-09-28

## Review authority

Review 34 examined the final frozen Review 33 wrapper source snapshot:

- Wrapper source SHA: `9d2dfa08bdbfc2845732679471aba5aae668f8f4`
- Snapshot workflow: `36188816031`
- Snapshot artifact: `10887515848`
- Verified wrapper manifest: `1,064/1,064` files

The native ABI was frozen and was not downloaded or re-reviewed. This was a source-only code review: no builds, tests, CI, simulators, applications, or runtime execution were performed.

The in-app browser's document-download controls failed repeatedly with “Failed to download file. Please try again later.” This local authority file preserves the complete visible Review 34 findings and review metadata for implementation preparation; it is not claimed to be a byte-for-byte downloaded copy.

## Substantive findings

### Flutter history identity registration is incomplete

Flutter's Review 33 history identity authority records identities mainly through `FFmpegKitExtended.create*Session()` and currently-live callback-map sessions. Several ordinary public creation/execution paths bypass that registration, including `FFmpegKit.execute*`, argument-based creation, multiple `FFprobeKit` and `MediaInformation` routes, and direct/global `FFplayKit` factories.

Created or completed sessions from those paths can disappear from `getSessions()`, typed history, and `getLast*Session()` results. Late discovery can also assign observation order rather than true creation order. Registration must occur once at the common creation/adoption boundary, before execution can race with history observation.

### History identity metadata is not completion-bounded

Flutter, React Native native, and React Native Web identity maps/registries insert identities but normally remove stale terminal identities only during a later history read or a full clear. A service that executes thousands of sessions without querying history can therefore accumulate thousands of wrapper records despite a small configured native history size. Later history queries also scale with process-lifetime sessions rather than retained-history capacity.

The lifecycle must reconcile metadata on completion and enforce a bound consisting of live/Created/Running identities plus the configured terminal-history capacity. A history read must not be the operation that makes the metadata bounded.

### React Native Web misclassifies MediaInformation sessions

The Web backend checks `session_is_ffprobe_session` before checking MediaInformation and never checks `session_is_media_information_session`. The frozen wrapper contract establishes that MediaInformation is an FFprobe subtype, while React Native native checks MediaInformation first.

As a result, Web typed history, generic reconstruction, and `getLastMediaInformationSession()` can classify or return the wrong type. Web must test MediaInformation before FFprobe and retain parity across typed history and generic reconstruction.

## Confirmed boundaries and exclusions

- No native ABI change is required.
- Do not download or review another native/builders snapshot.
- Do not use remote old binaries or hosted acceptance CI.
- Do not execute interactive applications as part of this code-review handoff.
- Exclude pedantic style, naming, documentation-only, missing-test-only, and speculative findings.
- Use semantic implementation names; Review identifiers are metadata only.

