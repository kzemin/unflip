# Plan 003: Add the `unflip` virtual camera vertical slice

> **Executor instructions**: Execute only after Plans 001 and 002 are DONE.
> Follow every verification gate. Camera Extension work is
> signing- and OS-sensitive; honor STOP conditions instead of weakening the
> sandbox or switching to legacy DAL plug-ins. Update Plan 003 status when done.
>
> **Dependency/drift check (run first)**: `git status --short` must be clean;
> Plans 001 and 002 must be marked DONE; and
> `rg -n 'virtual.*mirrored|mirrored.*left preview' docs/product-contract.md`
> must show that the virtual camera publishes the mirrored left-preview
> orientation. This plan was
> authored before the foundation files existed. If actual paths or capture
> ownership differ materially from “Expected architecture,” STOP and request a
> refreshed plan.

## Status

- **Priority**: P1
- **Effort**: L (multi-day; includes signed `/Applications` testing)
- **Risk**: HIGH (system-extension activation, cross-process frames, timing,
  third-party call-app compatibility)
- **Depends on**: `plans/002-dual-preview-mvp.md`
- **Category**: direction / architecture / correctness
- **Planned at**: unborn `main` branch (no commit), 2026-08-29

## Why this matters

The virtual camera is the integration that makes an orientation choice visible
to other apps. It must be implemented with Apple's sandboxed Camera Extension
path, keep frames local, share Plan 002's one capture session, and stop work
when no preview or external client needs it. This plan starts with a narrow
Core Media I/O transport proof so the riskiest assumption fails early.

## Expected architecture

- Host app `unflip` owns the single physical `AVCaptureSession` from Plan 002.
- Host adds one `AVCaptureVideoDataOutput` and forwards the selected orientation.
- Embedded `unflipCamera` is a sandboxed `CMIOExtension` with a source stream
  that call apps see as camera device `unflip`.
- Preferred first transport: a CMIO sink stream on the extension/device. The
  host writes sample buffers through Core Media I/O's C output-device APIs; the
  extension consumes them and forwards the latest valid buffer to its source
  stream. Core Media I/O owns the media IPC.
- The shared App Group stores only small control/status values. Do not write raw
  video frames to UserDefaults or ordinary files.
- Host receives virtual-client activity through a supported CMIO property
  notification or equivalent event-driven control path and sets Plan 002's
  virtual capture demand. Do not poll continuously while idle.
- Fixed MVP format: start with 1280×720 BGRA at 30 fps, unless the Plan 002
  capture device cannot produce or efficiently convert it. Both extension
  stream format and host conversion must agree.
- With no host frame, publish black—not the last camera frame—to avoid retaining
  a stale private image.

Apple references:

- <https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o>
- <https://developer.apple.com/videos/play/wwdc2022/10022/>

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Build | `xcodebuild -project unflip.xcodeproj -scheme unflip -configuration Debug -destination 'platform=macOS' build` | exit 0 with the selected signing team |
| Tests | `xcodebuild test -project unflip.xcodeproj -scheme unflip -destination 'platform=macOS'` | exit 0 |
| Embedded extension | `find ~/Library/Developer/Xcode/DerivedData -path '*Debug/unflip.app/Contents/Library/SystemExtensions/unflipCamera.systemextension' -print -quit` | prints one path after a signed Debug build |
| System registration | `systemextensionsctl list` | lists the extension bundle ID as activated/enabled after approval |
| Naming | `rg -n -i 'p[o]nla' . -g '!plans/**' -g '!.git/**'` | no matches |
| Network boundary | `rg -n 'URLSession|NWConnection|Network\.framework|WebKit' unflip unflipCamera` | no matches |

The signed Build and activation checks cannot use `CODE_SIGNING_ALLOWED=NO`.
Unsigned CI may continue to use that override for compile/test coverage.

## Scope

**In scope**:

- `unflipCamera/**` provider, device, source/sink streams, fixed IDs, status,
  and frame forwarding.
- Host services under `unflip/VirtualCamera/**` for activation, CMIO output,
  orientation conversion, and virtual-client demand.
- The existing Plan 002 camera controller only where necessary to attach one
  data output and set virtual demand.
- Popover/status menu rows for activation, chosen orientation, state, and
  actionable errors.
- Hardware-free tests under `unflipTests/**` plus a documented signed manual
  integration procedure.
- Entitlements/Info.plists/project settings only as required for correct
  signing and embedded activation.
- `docs/product-contract.md`, `README.md`, and `plans/README.md` status/behavior
  updates.

**Out of scope**:

- Legacy DAL plug-ins, disabling SIP, turning off library validation, or
  weakening either sandbox.
- A custom global Mach service, raw frame files, a network transport, or
  third-party video SDK.
- Multiple resolutions/frame rates, audio, recording, effects, backgrounds,
  beauty processing, or a Settings window.
- Automatic activation without an explicit user action.
- App Store submission, notarized DMG, or GitHub Release (Plan 004).

## Git workflow

- Suggested branch: `codex/003-virtual-camera`.
- Commit the transport proof separately from activation/UI and lifecycle work.
- Do not push or open a pull request unless instructed.

## Steps

### Step 1: Encode the mirrored output-orientation contract

Read `docs/product-contract.md`. The MVP behavior is resolved: publish the
mirrored orientation matching the left preview. Represent orientation as an
explicit typed value rather than scattering ambiguous booleans, but expose
only the mirrored action in the MVP UI. Use this control copy:

`Mandar a la call la vista espejo`

An unmirrored virtual output is deferred because the physical camera already
normally provides that result to call apps.

**Verify**: the preflight `rg` command finds the resolved mirrored choice and
unit tests prove horizontal reflection for asymmetric input.

### Step 2: Prove signed activation with a generated test frame

Before bridging the physical camera, make the existing Camera Extension template
publish a deterministic asymmetric test frame at 1280×720/30 and set:

- provider/manufacturer/model strings to `unflip`;
- `CMIOExtensionDevice.localizedName` to exactly `unflip`;
- stable provider, device, source-stream, and sink-stream UUIDs;
- host and extension marketing versions equal;
- sandbox and App Group entitlements from Plan 001.

Implement an `OSSystemExtensionRequestDelegate` service in the host. Activation
must occur only after the user chooses `Instalar / activar cámara virtual`.
Surface states: not installed, request submitted, needs approval/restart if the
OS says so, active, replaced/upgraded, failed with a useful message. Explain
that activation only works from `/Applications`; do not obscure that failure.

Use this prompt copy in context:

`unflip instala una cámara virtual para que otras apps puedan usar el video ya dado vuelta.`

**Verify**: copy the signed app to `/Applications`, activate explicitly, approve
in System Settings, run `systemextensionsctl list`, and select `unflip` in
Photo Booth or QuickTime. The asymmetric test frame appears. If this cannot be
made to work without sandbox/signing exceptions, STOP before adding transport.

### Step 3: Prove host-to-extension frames through CMIO source/sink streams

Add a source stream for call apps and a sink stream for host input, using the
same format description. In the host, discover the extension output device by
the fixed device ID—not display-name string—and use Core Media I/O C APIs to
enqueue `CMSampleBuffer`s to the sink stream. In the extension, drain the sink
queue using `consumeSampleBuffer` and acknowledge scheduled output using
`notifyScheduledOutputChanged` as required by the API.

Forward only the newest valid frame to the source stream, with monotonic host
timestamps. Bound the queue and drop old frames under load rather than building
latency. Validate pixel format, dimensions, duration, and data readiness before
publishing. Publish black on startup, input loss, transport error, or when host
frames age past a short threshold; never keep a stale camera image indefinitely.

Do not add ad-hoc XPC during this step. If a CMIO sink stream cannot serve this
host-to-extension topology on macOS 14 after a bounded proof, document the exact
API/OS failure and STOP. A revised architecture can then evaluate App Group +
IOSurface/XPC with evidence.

**Verify**: feed a generated asymmetric color-bar buffer from the host. Photo
Booth/QuickTime receives it through the `unflip` source stream for five minutes
with bounded memory and no increasing latency. Stop the host feed; output turns
black promptly.

### Step 4: Attach the one physical capture pipeline and orientation transform

Add one `AVCaptureVideoDataOutput` to Plan 002's existing session. Use a
dedicated serial output queue and discard late frames. Convert/crop to the fixed
16:9 extension format while preserving the exact source crop used by the
previews. Apply horizontal reflection only when the resolved orientation model
requires it. Prefer Core Image/Metal or vImage with a reusable context and
buffer pool; do not allocate a new context or unbounded buffers per frame.

Never start a second physical capture session. Never mutate preview mirroring to
produce virtual output. Preview is presentation state; outgoing transformation
is explicit pixel-buffer processing.

**Verify**: use asymmetric printed text/hand position. The call-app `unflip`
feed matches the product contract; both in-app previews remain unchanged. Run
for ten minutes while monitoring memory and frame latency for growth.

### Step 5: Make external-client demand event-driven

When the extension source stream transitions from zero to one client, signal
the host through a supported CMIO custom property notification or another
event-driven mechanism available to the signed app/extension. When the final
client stops, clear demand. The host maps that state to the Plan 002 virtual
demand flag:

- popover open, no external client → capture on;
- popover closed, external client active → capture on;
- popover closed, no external client → capture and conversion off;
- both active → one shared capture session, not duplicated work.

Handle host launch/relaunch and extension restart without getting stuck “on.”
Do not use a recurring idle poll. If the platform cannot deliver the event to
the host, STOP and report the tested alternatives before accepting polling.

**Verify**: exercise the four-state matrix with Photo Booth/QuickTime. Camera
privacy indicator and session logs match demand; idle capture stops after the
last consumer and popover both close.

### Step 6: Finish popover install/status/orientation UI

Enable the compact activation action in the `•••`/right-click menu. Show status
as `Cámara virtual: apagada` or `Cámara virtual: unflip`, plus concise pending,
approval-required, and error states when necessary. Keep the footer:

`Elegí “unflip” como cámara en Zoom o Meet.`

Do not add a Settings window. Do not claim the extension is active until the
system request completes and the device can be discovered. Keep activation and
orientation changes explicit user actions.

**Verify**: activation/replacement/error state-machine unit tests pass; manual
UI remains within the compact popover without clipping at default text size.

## Test plan

- Unit-test extension activation delegate outcomes: success, needs approval,
  replacement, reboot required if reported, cancellation, failure.
- Unit-test orientation conversion with an asymmetric tiny pixel buffer: pass
  through vs horizontal reflection and identical crop/dimensions.
- Unit-test stale-frame policy, invalid format rejection, monotonic timestamp
  mapping, bounded/latest-frame queue, and black fallback.
- Unit-test capture demand for popover/virtual consumer combinations and host
  relaunch state.
- Signed manual integration: install from `/Applications`; approve; verify
  system registration; select in Photo Booth/QuickTime; then Zoom, Google Meet
  in a supported browser, and Teams if locally available.
- Manual failure cases: host app quit, camera disconnected, extension restart,
  call app opens before host, call app closes while popover is closed.

## Done criteria

- [ ] Product contract and implementation publish the mirrored left-preview
      orientation through the virtual camera.
- [ ] Signed app activates a sandboxed Camera Extension from `/Applications`.
- [ ] Call apps list exactly one virtual camera named `unflip`.
- [ ] Host frames cross through the proven CMIO sink/source path without files,
      networking, stale-frame retention, or unbounded latency.
- [ ] The outgoing orientation matches the contract and previews do not change.
- [ ] Capture stays on only for preview or real virtual-camera demand.
- [ ] Build/tests pass and naming/network scans have no matches.
- [ ] No legacy DAL, SIP weakening, audio, or release work is introduced.

## STOP conditions

Stop and report if:

- Plans 001/002 are not DONE, the tree is dirty, or capture ownership differs
  materially from “Expected architecture.”
- Bundle/App Group IDs or signing profiles are unavailable to the team.
- Activation requires running outside `/Applications` or weakening security.
- CMIO sink/source bridging cannot be proven on the macOS 14 deployment target.
- Virtual-client activity cannot be delivered event-first without continuous
  idle polling.
- The implementation requires a second physical capture session, raw frame
  files, network transport, audio permission, or a third-party SDK.
- A verification fails twice after one reasonable correction.

## Maintenance notes

Camera Extension behavior must be tested from a signed app in `/Applications`;
an unsigned build proves compilation only. Fixed UUIDs and bundle IDs are public
device identity and must not change casually after release. Review buffer-pool
reuse, timestamps, queue bounds, stale-frame blacking, and teardown more closely
than UI polish.
