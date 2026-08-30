# unflip implementation roadmap

Generated on 2026-08-29 for a greenfield repository. The repository had no
commits or source files when these plans were written. Execute the plans in
order; each executor should read the whole plan, honor its STOP conditions,
run every verification gate, and update the corresponding status row.

The product is intentionally narrow: a local-only macOS 14+ menu-bar app that
shows one camera frame in mirrored and unmirrored previews, then optionally
publishes a selected orientation through a Camera Extension named `unflip`.
There is no Dock icon, account, network service, audio, recording, filtering,
background replacement, or full settings window.

The public repository has already been created at
<https://github.com/kzemin/unflip>. The local checkout has that repository as
its `origin`, but no code should be pushed until Plan 001's trust and build
baseline is present.

## Executor entry point

Give the implementation session `plans/CLAUDE_EXECUTION.md`. That brief grants
autonomy to execute the numbered plans in sequence, defines which git pushes
are authorized, and limits questions to genuine external blockers.

## Execution order and status

| Plan | Title | Priority | Effort | Depends on | Status |
|------|-------|----------|--------|------------|--------|
| 001 | Establish the project and public trust baseline | P1 | M | — | DONE |
| 002 | Ship the dual-preview menu-bar MVP | P1 | M | 001 | IN PROGRESS |
| 003 | Add the `unflip` virtual camera vertical slice | P1 | L | 002 | TODO |
| 004 | Harden, document, sign, and release the MVP | P2 | M | 003 | TODO |

Status values: `TODO`, `IN PROGRESS`, `DONE`, `BLOCKED: <reason>`, or
`REJECTED: <reason>`.

## Short roadmap

1. **Foundation and transparency** — create the native Xcode project, fixed
   identifiers and entitlements, CI build/test command, and public-facing
   privacy/build documentation.
2. **Useful app before extension** — implement camera permission, source
   selection, two synchronized 16:9 previews, and strict capture lifecycle in
   the menu-bar popover.
3. **Virtual camera** — activate the sandboxed Camera Extension, bridge frames
   through Core Media I/O, expose consumer activity, and publish the agreed
   orientation as a device named `unflip`.
4. **Release gate** — verify privacy, idle resource use, installation and
   Spotlight behavior, Zoom/Meet/Teams compatibility, signing/notarization,
   checksums, and source-to-binary traceability.

## Resolved product decision: publish the mirrored view

The MVP virtual camera publishes the mirrored orientation shown in the left
preview. This is the behavior that changes what other people see and makes the
outgoing call feed match the familiar self-view.

- Left preview: mirrored, labeled `Cómo te ves vos`.
- Right preview: unmirrored, labeled `Cómo te ven los demás`.
- Virtual camera output: mirrored, matching the left preview.
- MVP control: `Mandar a la call la vista espejo`.

Publishing an unmirrored virtual-camera mode is deferred because a physical
camera already normally supplies that orientation to call apps.

## Dependency notes

- Plan 002 depends on Plan 001 because capture code needs a stable app target,
  app lifecycle, test target, and Info.plist/entitlement ownership.
- Plan 003 depends on Plan 002 because the Camera Extension must consume the
  already-tested capture pipeline instead of creating a second competing
  camera session.
- Plan 004 depends on Plan 003 because signing, notarization, privacy review,
  and real call-app verification must cover the embedded system extension.

## Findings considered and rejected

- **Large Settings window** — rejected because the MVP is the popover and two
  tiles; a second configuration surface adds state and test cost without user
  value.
- **Custom ad-hoc XPC video transport first** — rejected for the first spike.
  Core Media I/O already defines source and sink streams and manages media IPC;
  test that supported route before inventing another frame protocol. App Group
  storage remains appropriate for small control/state values.
- **macOS 12.3 or 13 support** — rejected for MVP. The deployment target is
  macOS 14.0, which also provides the modern external and Continuity Camera
  discovery types.
- **Audio, effects, recording, accounts, analytics, or networking** — rejected
  as outside the single-purpose privacy promise.
