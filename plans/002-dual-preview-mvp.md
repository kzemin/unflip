# Plan 002: Ship the dual-preview menu-bar MVP

> **Executor instructions**: Execute only after Plan 001 is marked DONE. Follow
> each step and verification gate. Stop instead of improvising when a STOP
> condition occurs. Update Plan 002 in `plans/README.md` when complete.
>
> **Greenfield dependency/drift check (run first)**:
> `git status --short` must be clean, and
> `test -d unflip.xcodeproj && test -d unflip && test -d unflipTests` must exit
> 0. Compare the actual Plan 001 paths with “Expected foundation” below. This
> plan was authored before those files existed; if the foundation uses a
> materially different lifecycle or layout, STOP and request a refreshed plan.

## Status

- **Priority**: P1
- **Effort**: M (one to two days, including tests and manual camera QA)
- **Risk**: MED (camera permissions, capture-session concurrency, device churn)
- **Depends on**: `plans/001-establish-project-baseline.md`
- **Category**: direction / correctness / tests
- **Planned at**: unborn `main` branch (no commit), 2026-08-29

## Why this matters

The dual preview is useful even before macOS approves a Camera Extension. It is
also the safest place to prove the app's core visual truth: both tiles show the
same source and crop at the same moment, with only horizontal orientation
different. Keeping this milestone independent prevents signing and system
extension work from blocking user validation.

## Product behavior to implement

- Clicking the menu-bar icon opens a dark, compact popover—never a full window.
- Equal 16:9 tiles sit side by side.
- Left label: `Cómo te ves vos`; left feed is horizontally mirrored.
- Right label: `Cómo te ven los demás`; right feed is unmirrored.
- Both feeds use the same `AVCaptureSession`, camera, timing, crop, and no audio,
  filter, beauty processing, overlay, or background replacement.
- A compact picker lists built-in, Continuity, and external/USB cameras.
- The footer says `Elegí “unflip” como cámara en Zoom o Meet.`
- Extension controls may be visibly disabled with status
  `Cámara virtual: apagada`; activation is Plan 003.
- Opening the popover adds preview demand and starts capture. Closing it removes
  preview demand and stops capture unless a virtual-camera consumer is active.
  Plan 002 has no virtual consumer yet, but must model capture demand so Plan
  003 can add it without rewriting lifecycle logic.

## Expected foundation and file ownership

Plan 001 should have created an AppKit application delegate/status-item owner,
an `NSPopover` containing SwiftUI, host/extension/test targets, deployment
target 14.0, and no normal window. Preserve those choices.

Use this layout unless Plan 001 already established equivalent names:

- `unflip/App/UnflipAppDelegate.swift` — status item, popover lifecycle only.
- `unflip/UI/PopoverView.swift` — SwiftUI composition and copy.
- `unflip/Camera/CameraSessionController.swift` — permission, device discovery,
  capture configuration, and demand-based start/stop.
- `unflip/Camera/CameraPreviewView.swift` — `NSViewRepresentable` around an
  `AVCaptureVideoPreviewLayer`.
- `unflip/Camera/CameraDeviceDescriptor.swift` — immutable, testable device
  identity/category model.
- `unflipTests/CameraSessionControllerTests.swift` and
  `unflipTests/CameraDeviceDescriptorTests.swift` — hardware-free state tests.

Match equivalent existing Plan 001 naming instead of creating duplicate app
delegates or UI roots. If equivalence is unclear, STOP.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Build | `xcodebuild -project unflip.xcodeproj -scheme unflip -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` | exit 0 |
| Tests | `xcodebuild test -project unflip.xcodeproj -scheme unflip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` | exit 0; all state/device tests pass |
| Audio boundary | `rg -n 'AVCaptureAudio|AVMediaTypeAudio|mediaType:\s*\.audio|AVAudio' unflip` | no matches |
| Network boundary | `rg -n 'URLSession|NWConnection|Network\.framework|WebKit' unflip` | no matches |
| Naming | `rg -n -i 'p[o]nla' . -g '!plans/**' -g '!.git/**'` | no matches |

## Scope

**In scope**:

- Existing Plan 001 host app files necessary to inject the camera controller
  and observe popover open/close.
- `unflip/Camera/**`
- `unflip/UI/PopoverView.swift` and small adjacent host UI components.
- Hardware-free unit tests under `unflipTests/**`.
- `docs/product-contract.md` only to mark dual-preview behavior implemented.
- `plans/README.md` status only.

**Out of scope**:

- `unflipCamera/**`, system-extension activation, CMIO frame transport, or a
  selectable virtual camera.
- Mirroring the underlying capture connection globally. Only the left preview
  presentation is mirrored; the raw output remains unmirrored.
- Audio, recording, screenshots, effects, backgrounds, persistent frame
  storage, network access, analytics, a Settings window, or onboarding pages.
- Signing, notarization, App Store work, DMG packaging, and release automation.

## Git workflow

- Suggested branch: `codex/002-dual-preview`.
- Prefer one commit for the tested capture model and one for popover UI/manual
  QA notes. Use Conventional Commits.
- Do not push or open a pull request unless instructed.

## Steps

### Step 1: Make camera state testable and demand-driven

Create a `@MainActor` observable controller whose UI-facing state is explicit:
permission (`notDetermined`, `authorized`, `denied`, `restricted`), available
devices, selected stable device ID, capture status, and optional user-facing
error. Own the `AVCaptureSession` in this controller or a private capture
service; serialize all session mutations on a dedicated queue.

Represent demand as two independent booleans or a small set:

- preview demand from the open popover;
- virtual-camera demand, initially always false but writable by Plan 003.

Capture runs when either demand exists and stops when neither exists. Make
start/stop idempotent. Never call `startRunning()` or `stopRunning()` on the
main actor. Remove inputs/outputs cleanly when switching devices.

Inject protocol-backed permission, discovery, and session collaborators into
tests; do not make unit tests open real camera hardware.

**Verify**: unit tests cover repeated open/close, both-demand truth table,
denied permission, and idempotent start/stop; Tests command exits 0.

### Step 2: Request permission with exact local-only copy

On first preview demand, use `AVCaptureDevice.authorizationStatus(for: .video)`
and request access only for video when status is undetermined. The Info.plist
copy must already be:

`unflip usa la cámara solo en esta Mac para mostrarte las dos vistas y, si lo activás, mandar el video a Zoom o Meet.`

Show concise in-popover states for waiting, denied/restricted (with a button to
open System Settings only on an explicit user action), no camera, and capture
failure. Do not repeatedly prompt.

**Verify**: hardware-free permission tests pass. Manual test after resetting
camera permission shows one system prompt and no audio prompt.

### Step 3: Discover and switch physical cameras safely

For macOS 14 use `AVCaptureDevice.DiscoverySession` with device types
`.builtInWideAngleCamera`, `.continuityCamera`, and `.external`, media type
`.video`, position `.unspecified`. `NSCameraUseContinuityCameraDeviceType` must
be true so Continuity cameras retain their device type.

Map devices to immutable descriptors using `uniqueID` as identity and
`localizedName` for display. Categorize for ordering only; do not replace the
actual localized name with generic “USB cam.” Exclude the future `unflip`
virtual-device UUID to prevent a feedback loop. Preserve selection by unique ID
when devices reconnect; fall back predictably to built-in, then Continuity,
then external. Observe device connection/disconnection and reconfigure safely.

Switch inputs inside `beginConfiguration()` / `commitConfiguration()` on the
session queue. If the new input cannot be added, keep or restore the last good
input and surface a recoverable error.

**Verify**: descriptor/sorting/fallback tests pass. Manual test can switch
available physical sources without duplicate sessions or a frozen popover.

### Step 4: Render the same session in two equal preview tiles

Wrap `AVCaptureVideoPreviewLayer` in AppKit so two layers observe the same
capture session. Set both to the same `.resizeAspectFill` gravity and place each
inside an identical 16:9 clipped container. Configure the left preview
connection with automatic mirroring disabled and explicit mirroring on;
configure the right connection with explicit mirroring off. Do not mirror the
session's future `AVCaptureVideoDataOutput` connection.

If two preview-layer connections cannot independently hold mirroring state on
macOS 14, STOP and report that finding. The fallback is a single sample-buffer
render path with two presentation transforms, but do not add that complexity
without confirming the simpler route fails.

**Verify**: build and tests pass. For manual QA, hold printed asymmetric text or
raise one hand: the tiles must be exact horizontal opposites with identical
crop and motion timing.

### Step 5: Finish the compact popover and lifecycle

Use background `#0B0B0C` (or system black where vibrancy/accessibility requires
it), native text colors, modest spacing, and no large title or decorative
chrome. Keep both tiles visible side by side at normal popover width. Include:

- labels above each tile;
- source picker under the tiles;
- disabled virtual-camera row/status for Plan 003;
- footer `Elegí “unflip” como cámara en Zoom o Meet.`;
- an accessible `•••` menu or status-item right-click menu with `Abrir unflip`,
  disabled `Instalar / activar cámara virtual`, and `Salir`.

The app delegate must call preview-demand start only when the popover opens and
remove it on every close path (outside click, Escape, status-item toggle). Quit
must tear down capture before app termination.

**Verify**: manually exercise every close path and observe the camera privacy
indicator turning off shortly after the popover closes. Build and Tests exit 0.

## Test plan

- Capture demand truth table: neither, preview only, virtual only, both.
- Repeated demand changes are idempotent and do not double-start/stop.
- Permission states map to stable UI states; only undetermined requests access.
- Device descriptors preserve unique identity, ordering, exclusion of the
  reserved virtual-device UUID, reconnection, and fallback.
- Failed camera input replacement leaves a known-good configuration.
- UI copy can have lightweight string/config tests, but do not add brittle
  snapshot tests for native camera layers.
- Manual matrix: built-in camera; Continuity Camera if available; one USB camera
  if available; permission denied; device disconnected while active; every
  popover close path.

## Done criteria

- [ ] Popover shows two equal, synchronized 16:9 tiles from one camera session.
- [ ] Left is mirrored, right is unmirrored, with identical crop.
- [ ] Built-in, Continuity, and external physical sources are selectable.
- [ ] Permission denial and no-device states do not crash or loop prompts.
- [ ] Capture stops when the popover closes because virtual demand is false.
- [ ] All build/unit-test commands exit 0.
- [ ] Audio, network, and legacy-name scans have no matches.
- [ ] No extension, release, or out-of-scope feature work is mixed into the diff.

## STOP conditions

Stop and report if:

- Plan 001 is not DONE, the working tree is dirty, or its lifecycle/layout is
  materially different from “Expected foundation.”
- Independent mirroring cannot be configured on two preview-layer connections.
- Switching sources would require two simultaneous capture sessions.
- A physical camera must be accessed through network code or a third-party SDK.
- Any implementation path introduces audio capture or persistent frames.
- A verification fails twice after one reasonable correction.

## Maintenance notes

Plan 003 must attach `AVCaptureVideoDataOutput` to this same session and drive
the existing virtual-demand flag; it must not start another capture session.
Review all session mutations for queue confinement and all UI state for main
actor access. Treat the reserved virtual-device UUID as a shared constant once
the extension defines it.
