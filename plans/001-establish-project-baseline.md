# Plan 001: Establish the native project and public trust baseline

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before continuing. If a
> STOP condition occurs, stop and report it instead of improvising. When done,
> update Plan 001 in `plans/README.md`.
>
> **Greenfield drift check (run first)**:
> `git status --short --untracked-files=all -- . ':(exclude)plans/**'`
> must print nothing. This plan was written before the repository had a first
> commit, so there is no commit SHA to compare. If any non-plan file exists,
> inspect it and STOP if it conflicts with the paths or choices below.

## Status

- **Priority**: P1
- **Effort**: M (about one day, including CI and documentation)
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction / DX / docs
- **Planned at**: unborn `main` branch (no commit), 2026-08-29

## Why this matters

The repository is empty, so every later feature depends on establishing one
unambiguous native macOS structure. This plan fixes naming, deployment target,
target ownership, privacy boundaries, and verification commands before camera
code introduces signing and lifecycle complexity. It also makes the public
repository useful to colleagues who want to inspect the app before installing
it.

## Product contract to preserve

- Product name, app display name, menu-bar label, extension device name, target
  naming, documentation, and user-facing copy use `unflip`.
- Minimum deployment target: macOS 14.0. Compile with the installed current
  Xcode SDK while preserving that minimum.
- Native SwiftUI + AppKit only. No Electron, WebView, third-party analytics,
  login, server, or network client.
- Menu-bar app only: normal `.app` bundle, `LSUIElement = YES`, no Dock icon and
  no main settings window. It must still be installable in `/Applications` and
  discoverable through Spotlight and Launchpad.
- Two targets in one Xcode project: host app `unflip` and embedded Camera
  Extension `unflipCamera`. A unit-test target may be added.
- Suggested identifiers, unless an already-registered App ID requires another
  prefix: host `com.kzemin.unflip`, extension `com.kzemin.unflip.camera`, shared
  app group `$(TeamIdentifierPrefix)com.kzemin.unflip`.
- Privacy: camera frames remain on the Mac. No audio capture. No persistence of
  frames. No network APIs.

## Current state

- `git status --short --branch` reported an unborn branch with no commits when the
  plan was written.
- No README, Xcode project, Swift files, tests, CI, or local agent instructions
  exist.
- Xcode 26.5, Apple Swift 6.0.3, and macOS 26.5.1 are installed locally.
- `xcodegen` and `xcbeautify` are not installed; do not add either just to make
  the project.
- Public remote: <https://github.com/kzemin/unflip>.

## Commands you will establish

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Build | `xcodebuild -project unflip.xcodeproj -scheme unflip -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` | exit 0; both host and embedded extension compile |
| Tests | `xcodebuild test -project unflip.xcodeproj -scheme unflip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` | exit 0; smoke/unit tests pass |
| Settings | `xcodebuild -project unflip.xcodeproj -scheme unflip -showBuildSettings` | reports `MACOSX_DEPLOYMENT_TARGET = 14.0` |
| Naming | `rg -n -i 'p[o]nla' . -g '!plans/**' -g '!.git/**'` | no matches |
| Network boundary | `rg -n 'URLSession|NWConnection|Network\.framework|WebKit' unflip unflipCamera` | no matches |

## Scope

**In scope** (the only paths to create or modify):

- `unflip.xcodeproj/**`
- `unflip/**`
- `unflipCamera/**`
- `unflipTests/**`
- `docs/product-contract.md`
- `README.md`
- `SECURITY.md`
- `.gitignore`
- `.github/workflows/build.yml`
- `plans/README.md` (status only)

**Out of scope**:

- Camera capture, live previews, source selection, or frame conversion.
- Working extension activation or frame publishing; the target only needs to
  compile and be embedded in this plan.
- A Settings scene/window, onboarding carousel, audio, recording, filters,
  backgrounds, accounts, analytics, or networking.
- App Store submission, Developer ID signing, notarization, DMG creation, or a
  GitHub Release.
- Adding a package manager or third-party dependency.

## Git workflow

- Suggested branch: `codex/001-project-baseline`.
- Use small logical commits. There is no existing message convention; use
  Conventional Commits such as `chore: scaffold unflip macOS targets`.
- Do not push or open a pull request unless the operator asks.

## Steps

### Step 1: Record the product contract

Create `docs/product-contract.md` with the narrow product contract above, the
exact rioplatense UI copy from Plans 002 and 003, and all out-of-scope items.
Record the resolved orientation contract explicitly: the right preview is
unmirrored, the left preview is mirrored, and the `unflip` virtual camera
publishes the mirrored orientation matching the left preview. The MVP control
copy is `Mandar a la call la vista espejo`.

**Verify**: `rg -n 'macOS 14.0|local|mirrored|unmirrored|orientation' docs/product-contract.md`
prints matching contract lines.

### Step 2: Create a native two-target Xcode project

Create `unflip.xcodeproj` with:

- A Swift host app target `unflip`, product `unflip.app`, marketing version
  `0.1.0`, build `1`, deployment target `14.0`, normal standard architectures,
  and Swift concurrency checking compatible with macOS 14.
- A Swift Camera Extension target `unflipCamera`, embedded in the host app and
  using Apple's Camera Extension template shape (`CMIOExtensionProvider`,
  device source, stream source, and `main.swift`). Keep its initial generated
  frame implementation minimal; no production transport yet.
- A unit-test target `unflipTests` hosted by the app.
- Shared schemes committed under
  `unflip.xcodeproj/xcshareddata/xcschemes/` so CI can build and test.

Use `com.kzemin.unflip` and `com.kzemin.unflip.camera` if available. If Xcode or
the signing portal reports those identifiers belong to another team, STOP and
ask the operator for the intended reverse-DNS prefix; do not invent a personal
or corporate domain.

**Verify**: run the Build and Settings commands from “Commands you will
establish.” Both exit 0, and settings report deployment target 14.0.

### Step 3: Configure the bundle, sandbox, and extension metadata

Host configuration must include:

- `CFBundleDisplayName = unflip`
- `LSUIElement = YES`
- `NSCameraUsageDescription = unflip usa la cámara solo en esta Mac para mostrarte las dos vistas y, si lo activás, mandar el video a Zoom o Meet.`
- `NSCameraUseContinuityCameraDeviceType = YES`
- App Sandbox, camera, System Extension install, and the shared App Group
  entitlements.

Extension configuration must include:

- App Sandbox and the exact same App Group entitlement.
- `NSSystemExtensionUsageDescription = unflip instala una cámara virtual para que otras apps puedan usar el video ya dado vuelta.`
- The Xcode Camera Extension template's `CMIOExtension` dictionary and
  `CMIOExtensionMachServiceName` based on the team and product bundle IDs.
- Stable hard-coded UUIDs for the provider/device/streams once introduced;
  never generate new public device IDs on every launch.
- Host and extension `MARKETING_VERSION` values must match.

Match Apple's current Camera Extension template rather than copying obsolete
DAL plug-in configuration.

**Verify**:

```sh
xcodebuild -project unflip.xcodeproj -scheme unflip -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: exit 0, with `unflipCamera.systemextension` embedded in the app build
product.

### Step 4: Add only the menu-bar shell

Create an AppKit lifecycle coordinator (`NSApplicationDelegate`) that owns an
`NSStatusItem` and `NSPopover`, with SwiftUI content hosted inside the popover.
This choice is deliberate: later work needs precise open/close callbacks and a
right-click menu. The shell may show a compact “unflip — preparación” message,
a disabled extension status, and Quit. Do not create a SwiftUI `Settings`
scene or normal window.

Ensure activating the app creates one status item and no visible Dock tile.
Keep capture-related interfaces out until Plan 002.

**Verify**: Build succeeds. Launch the unsigned Debug app manually; it shows
one menu-bar item, opens one popover, and has no Dock icon or normal window.

### Step 5: Establish tests and public inspection docs

- Add a unit smoke test that loads app configuration values without launching
  the camera.
- Add a macOS GitHub Actions workflow that runs the unsigned Build and Tests
  commands. Pin the runner only as tightly as GitHub currently supports while
  retaining an Xcode version capable of compiling Camera Extensions.
- Add a README that states what the app does, what it does not do, all requested
  permissions, the no-network/no-recording promise, current pre-alpha status,
  build commands, deployment target, and that published binaries will be tied
  to tagged source.
- Add `SECURITY.md` with a private vulnerability-reporting route supported by
  GitHub (prefer GitHub private vulnerability reporting; do not invent an email
  address).
- Add a standard Xcode/macOS `.gitignore` without hiding source, project files,
  entitlements, or shared schemes.

Do not add a license unless the operator explicitly selects one; source can be
publicly inspectable without silently granting reuse rights.

**Verify**: Tests exit 0. `git status --short` shows only the in-scope paths.

## Test plan

- `unflipTests/AppConfigurationTests.swift` verifies the product display name,
  minimum OS/build setting representation where practical, and privacy copy.
- CI runs both the unsigned build and unit tests on every pull request.
- No UI or camera hardware automation is required in this foundation plan.

## Done criteria

- [ ] Host app, Camera Extension, and unit-test targets exist and compile.
- [ ] Deployment target is exactly macOS 14.0 for host and extension.
- [ ] Host app is `LSUIElement`, shows only a status item/popover, and has no
      Settings or normal window.
- [ ] Host and extension have sandbox/App Group metadata; the host can install
      a system extension once properly signed.
- [ ] Build and Tests commands exit 0 with code signing disabled.
- [ ] README and SECURITY docs make the privacy boundary inspectable.
- [ ] Naming scan has no legacy-name matches outside plans.
- [ ] Network-boundary scan has no matches.
- [ ] No file outside Scope is modified, except status in `plans/README.md`.

## STOP conditions

Stop and report if:

- The repository is no longer empty and existing files conflict with this
  structure.
- The proposed bundle identifiers are unavailable to the signing team.
- The Camera Extension template generated by installed Xcode materially
  differs from the required entitlements or bundle shape.
- Building the embedded extension requires weakening App Sandbox.
- A step appears to require a third-party dependency or network code.
- A verification fails twice after one reasonable correction.

## Maintenance notes

Keep user-visible product naming separate from Swift type capitalization;
`UnflipAppDelegate` is acceptable, while product/device strings remain
`unflip`. Reviewers should scrutinize accidental window scenes, generated
per-launch camera UUIDs, uncommitted shared schemes, and mismatched app/extension
versions. Camera implementation belongs in Plans 002 and 003.
