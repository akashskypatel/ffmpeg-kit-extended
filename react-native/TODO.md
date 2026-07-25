### Phase 1 — Release blockers

- [x] Fix `ffmpeg-kit-extended` package-name documentation mismatch.
- [x] Add `LICENSE` and third-party licensing documentation.
- [x] Explicitly declare New Architecture requirement.
- [x] Add top-level tests/lint.
- [x] Verify consumer-owned Codegen from the packed `.tgz` on every supported platform.
- [x] Install the generated `.tgz` into clean consumer projects.

### Phase 2 — Binary delivery hardening

- [x] Add SHA-256 verification.
- [x] Add download retries/timeouts.
- [x] Move Android download out of Gradle configuration.
- [x] Validate every official GitHub release asset automatically.
- [x] Investigate avoiding all-three-platform Apple downloads.

### Phase 3 — Compatibility qualification

- [x] Test RN `0.81.6` minimum.
- [x] Test RN `0.86`.
- [x] Test all five currently implemented platforms from the packed npm artifact.
- [x] Test release builds.
- [x] Publish an explicit compatibility matrix.

### Phase 4 — Release infrastructure

- [x] Add changelog/versioning workflow.
- [ ] Add CI release gates.
- [ ] Configure npm Trusted Publishing/provenance.
- [ ] Publish `0.1.0`.

