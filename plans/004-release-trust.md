# Plan 004: Harden, document, sign, and release the MVP

> **Executor instructions**: Execute only after Plans 001–003 are DONE. This is
> a release gate, not a feature pass. Run every verification and record evidence
> in the release checklist. Never place signing/notarization credentials in the
> repository. Update Plan 004 in `plans/README.md` when complete.
>
> **Dependency/drift check (run first)**: `git status --short` must be clean and
> Plans 001–003 must be marked DONE. Confirm a signed `/Applications/unflip.app`
> can publish a camera named `unflip` before changing packaging. If not, STOP;
> release work cannot compensate for an incomplete vertical slice.

## Status

- **Priority**: P2
- **Effort**: M (one to two days plus external call-app testing)
- **Risk**: MED (signing, notarization, packaging, compatibility)
- **Depends on**: `plans/003-virtual-camera.md`
- **Category**: direction / security / performance / docs / DX
- **Planned at**: unborn `main` branch (no commit), 2026-08-29

## Why this matters

The app asks for camera access and installs a system extension, so trust must be
demonstrable rather than asserted. Colleagues should be able to read the exact
tagged source, understand permissions and architecture, build it themselves,
verify a released binary's checksum/signature, and see that the process is idle
when unused. A release is blocked until those claims have evidence.

## Current intended release shape

- Public source: <https://github.com/kzemin/unflip>.
- macOS 14.0 minimum; current SDK compilation is acceptable.
- Sandboxed host + sandboxed Camera Extension, same marketing version.
- Menu-bar-only `.app`, installed into `/Applications`, no Dock icon.
- Local camera frames only; no audio, recording, persistence, analytics,
  accounts, or networking.
- First practical distribution can be a signed and notarized DMG attached to a
  GitHub Release. Keep the project App Store-compatible; App Store submission
  can follow without forking the architecture.

## Commands you will need

Replace `<archive-path>`, `<export-path>`, `<app-path>`, `<dmg-path>`, and
`<release-tag>` with explicit validated paths/values; never rely on broad globs.

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Clean tests | `xcodebuild test -project unflip.xcodeproj -scheme unflip -destination 'platform=macOS'` | exit 0 |
| Archive | `xcodebuild archive -project unflip.xcodeproj -scheme unflip -configuration Release -archivePath <archive-path>` | exit 0; signed archive exists |
| App signature | `codesign --verify --deep --strict --verbose=2 <app-path>` | exit 0 |
| Entitlements | `codesign -d --entitlements :- <app-path>` | sandbox, camera, system-extension install, and App Group only as expected |
| Gatekeeper | `spctl --assess --type execute --verbose=4 <app-path>` | accepted after notarization/stapling |
| Notarization | `xcrun notarytool history --keychain-profile <profile>` | release submission reports Accepted |
| DMG checksum | `shasum -a 256 <dmg-path>` | one checksum recorded in release notes |
| Universal slices | `lipo -archs <app-path>/Contents/MacOS/unflip` | contains `arm64 x86_64`, unless an Intel blocker is documented and owner accepts arm64-only |
| Naming | `rg -n -i 'p[o]nla' . -g '!plans/**' -g '!.git/**'` | no matches |
| Network boundary | `rg -n 'URLSession|NWConnection|Network\.framework|WebKit' unflip unflipCamera` | no matches |

## Scope

**In scope**:

- Release configuration in `unflip.xcodeproj/**`, Info.plists, entitlements,
  version values, and asset catalog/app icon.
- `README.md`, `SECURITY.md`, `PRIVACY.md`, `docs/architecture.md`,
  `docs/release-checklist.md`, and build-from-source instructions.
- `.github/workflows/**` for unsigned validation and safe release checks that do
  not expose signing secrets.
- Minimal test/instrumentation fixes required to meet existing acceptance
  criteria, with no feature expansion.
- A tagged GitHub Release and notarized DMG only after every gate passes.
- `plans/README.md` status only.

**Out of scope**:

- New features, redesign, Settings window, onboarding carousel, audio,
  recording, filters, backgrounds, accounts, analytics, or network services.
- Weakening sandbox/library validation, disabling SIP, or using legacy DAL.
- Storing certificates, API keys, app-specific passwords, or notarization
  credentials in source or logs.
- Automatic App Store submission. Prepare compatibility and documentation, but
  treat MAS submission as a separate operator action.

## Git workflow

- Suggested branch: `codex/004-release-trust`.
- Use commits such as `docs: document unflip privacy and architecture` and
  `chore: prepare 0.1.0 release`.
- Do not push, tag, or create a GitHub Release until the operator explicitly
  authorizes publication of that exact version and artifact.

## Steps

### Step 1: Turn privacy claims into inspectable documentation

Update README and add `PRIVACY.md` and `docs/architecture.md` covering:

- one-screen product purpose and screenshot/GIF of the two previews;
- camera and system-extension permissions, why each exists, and exact prompt
  copy;
- process diagram: physical camera → host capture → orientation transform →
  CMIO sink/source → call app;
- explicit statements: no audio, recording, stored frames, analytics, account,
  network client, server, or hidden helper;
- how capture demand starts/stops and why the extension may keep capture active
  while a call app uses it;
- build/test commands, Xcode requirement, macOS 14 minimum, `/Applications`
  activation requirement, and how to remove the app/extension;
- how a reader can compare a release tag, checksum, signature, and binary.

Keep claims precise. If the source contains any contradicting code, STOP and
fix the product or soften the claim before release; never publish a false
privacy promise.

**Verify**: naming/network/audio scans pass, and all README build commands work
from a fresh clone.

### Step 2: Add a release acceptance checklist with evidence fields

Create `docs/release-checklist.md` with pass/fail/evidence entries for:

- fresh install in `/Applications`; Spotlight and Launchpad find `unflip`;
- no Dock icon; one menu-bar item and compact popover;
- exact rioplatense labels and permission copy;
- left mirrored/right unmirrored, same crop and timing;
- built-in, Continuity, and USB source selection;
- extension approval and one camera device named `unflip`;
- resolved outgoing orientation in Photo Booth/QuickTime, Zoom, Meet, and Teams;
- camera disconnect, permission denial, host quit/relaunch, extension restart;
- no audio permission and no network traffic initiated by the app;
- near-zero CPU with popover closed and no virtual client; capture/privacy
  indicator off; no timer/poll wakeups attributable to the app;
- memory/latency stable during a 30-minute virtual-camera call;
- VoiceOver labels, keyboard navigation, and increased-text layout;
- signed/notarized artifact, checksum, matching source tag and version.

Record tested macOS/hardware/call-app versions in evidence without promising
untested combinations.

**Verify**: checklist has no blank acceptance category before release; blockers
remain visibly failed, not deleted.

### Step 3: Measure idle and streaming behavior

Use Activity Monitor and an appropriate Instruments Time Profiler/Energy Log
run to capture evidence for these states: popover closed/no client, popover
open, virtual client active, both active. Confirm no capture session, frame
conversion, display link, recurring timer, or CMIO polling runs in the idle
state. Confirm one physical session and bounded buffers when both demands exist.

If idle CPU is persistently measurable above normal event-loop noise, profile
and fix the cause within existing architecture. Do not accept a periodic status
poll for convenience.

**Verify**: attach summarized measurements and Instruments trace location (not
the huge trace itself unless intentionally archived) to the checklist.

### Step 4: Validate sandbox, signature, and dependency surface

- Inspect host and extension entitlements from the built archive; ensure both
  remain sandboxed and share only the required App Group.
- Verify the host has camera and system-extension install entitlements; the
  extension has only its required camera-extension/App Group capabilities.
- Inspect linked libraries with `otool -L`; document all non-system libraries.
  Expected MVP result is no third-party runtime library.
- Run source scans for network/audio APIs and inspect false positives manually.
- Ensure no secrets, provisioning profiles, certificates, or notarization
  credentials are committed.
- Confirm host and extension marketing versions match.

**Verify**: codesign checks pass; dependency and entitlement evidence is copied
to the release checklist without secret material.

### Step 5: Archive, notarize, package, and publish only with authorization

Use a Developer ID Application certificate and an operator-managed keychain
profile for notarization. Archive Release, export the app, create a simple DMG,
submit it with `notarytool`, wait for Accepted, staple the ticket, then run
`spctl` and `codesign` verification on a fresh copy. Do not echo credentials.

Create a version tag only after the tree is clean and CI passes. Release notes
must include supported macOS, permissions, known limitations, exact commit/tag,
SHA-256 checksum, install/removal steps, and the unresolved MAS status. Upload
only the final verified artifact.

**Verify**: download the published DMG from the release, recalculate SHA-256,
install on a clean test account/Mac if available, and repeat signature,
Gatekeeper, activation, and virtual-camera smoke tests.

## Test plan

- Full automated unit suite and unsigned CI compile from a fresh clone.
- Signed archive verification for host and embedded extension.
- Manual acceptance matrix from Step 2, with exact versions recorded.
- Idle/streaming energy and memory evidence from Step 3.
- Fresh-download install, Gatekeeper, notarization, checksum, Spotlight,
  Launchpad, permission, activation, and removal checks.
- Review source tag and generated archive version/commit metadata match.

## Done criteria

- [ ] Public docs accurately explain permissions, data flow, privacy, build,
      verification, installation, and removal.
- [ ] Every release-checklist row passes or the release remains blocked.
- [ ] Idle capture/conversion/timers stop and CPU is near event-loop baseline.
- [ ] Streaming remains bounded and stable for 30 minutes.
- [ ] Host and extension are sandboxed, version-matched, signed, notarized, and
      Gatekeeper accepted.
- [ ] DMG checksum matches the public release note and source tag.
- [ ] Fresh-download smoke test passes with camera device `unflip`.
- [ ] No legacy naming, network client, audio capture, secret, or third-party
      runtime dependency is present.

## STOP conditions

Stop and report if:

- Plans 001–003 are not DONE or the vertical slice fails from `/Applications`.
- Any privacy/documentation claim contradicts source behavior.
- Idle capture, conversion, polling, or meaningful CPU usage remains.
- Signing identities, App IDs, notarization profile, or operator release
  authorization are unavailable.
- Notarization or Gatekeeper rejects the artifact.
- A required call app does not list/use `unflip`; record evidence before any
  compatibility workaround.
- Packaging would require disabling sandbox, SIP, or library validation.
- A verification fails twice after one reasonable correction.

## Maintenance notes

Every future release must repeat the checklist because call apps, signing, and
macOS extension approval behavior can change. Keep privacy claims coupled to
source scans and architecture review. Do not let release automation obscure the
exact signed inputs, source commit, or checksum presented to users.
