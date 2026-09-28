# Review 34 Luna implementation plan — Flutter + React Native cross-platform readiness

Date: 2026-09-28

## Frozen authority and preparation note

Implement against the final Review 33 wrapper snapshot recorded in the tracker:

- Wrapper source SHA: `9d2dfa08bdbfc2845732679471aba5aae668f8f4`
- Source snapshot workflow: `36188816031`
- Source snapshot artifact: `10887515848`
- Native ABI: frozen; do not download or re-review it

The browser's Review 34 document-download controls failed repeatedly. This plan is prepared from the complete visible Review 34 response and is intended to preserve the implementation handoff without claiming a successful document download.

Planning identifiers are metadata only. Implementation types, functions, registries, tests, and files must use semantic names, not `R34-G*` or other review identifiers.

## Implementation constraints

- Wrapper scope only: Flutter and React Native.
- Do not modify `libs/libffmpegkit` or the ManyLinux builders.
- Do not publish or retrieve native ABI binaries.
- Do not use hosted Flutter/React Native acceptance workflows or remote old binaries.
- Use the existing local frozen artifacts and the established local platform order.
- Preserve primary errors and report every failed or unavailable gate truthfully.

## Goals

### Centralize session identity adoption

Move Flutter history registration to a common creation/adoption boundary so every public command, argv, synchronous, asynchronous, FFprobe, MediaInformation, and FFplay creation path receives exactly one identity at the true creation point. Cover direct and global factories as well as the convenience APIs that currently bypass `FFmpegKitExtended.create*Session()`.

Preserve native creation order, prevent duplicate registration, and make history observation independent of whether a session happened to be discovered through a later callback-map lookup.

### Reconcile history metadata on completion

Add completion-driven lifecycle reconciliation across Flutter, React Native native, and React Native Web. Keep live, Created, and Running identities available while retaining only the configured terminal-history capacity after completion. Ensure a service that never calls history APIs cannot grow metadata without bound.

Use a semantic lifecycle authority shared by history projections rather than adding another unbounded mirror. Reconcile native evictions and missing identities without releasing active ownership or changing the frozen ABI.

### Restore Web MediaInformation type precedence

In React Native Web, classify MediaInformation before FFprobe wherever session type is determined. Add parity coverage for typed history, generic reconstruction, and last-session lookup so a MediaInformation session cannot be returned as ordinary FFprobe.

### Validate locally in the established order

Run genuine focused regressions first, followed by local-only platform validation in this order:

1. Windows
2. Android on Windows
3. WSL Linux
4. Wasm/Web
5. Apple on the MacBook Air

Use the configured local artifacts. Do not use hosted acceptance CI, remote staged binaries, native ABI publication, or interactive application execution.

### Reconcile and freeze

Update only affected behavior, evidence, and tracker material. Freeze the exact final wrapper SHA and create one wrapper-only source snapshot. Do not create or download a builders/native snapshot.

## Required evidence

- Focused regressions prove every public creation path registers once at true creation time.
- Completion-driven pruning remains bounded without requiring a history read.
- Flutter, React Native native, and React Native Web history projections preserve live/Created/Running identities and terminal capacity.
- React Native Web MediaInformation precedence tests pass for typed and generic history.
- The ordered local platform matrix completes using the existing frozen artifacts.
- The final wrapper SHA and single wrapper-only source snapshot are recorded in the tracker.

