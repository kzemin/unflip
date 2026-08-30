# unflip product contract

This file is the authoritative, narrow definition of what `unflip` is. Anything
not listed as in scope is out of scope. Changing this contract is a product
decision, not an implementation detail.

## What unflip is

A local-only macOS menu-bar app that shows one physical camera as two
simultaneous previews — mirrored and unmirrored — and can publish the mirrored
orientation to other apps through a virtual camera named `unflip`.

## Fixed decisions

| Decision | Value |
|----------|-------|
| Product / display / device name | `unflip` |
| Minimum deployment target | macOS 14.0 |
| Technology | Native SwiftUI + AppKit, AVFoundation, Core Media I/O Camera Extension |
| Third-party runtime dependencies | none |
| UI surface | menu-bar status item + one compact popover with two equal 16:9 tiles |
| Dock icon | none (`LSUIElement = YES`) |
| Settings window | none |
| Host bundle identifier | `com.kzemin.unflip` |
| Extension bundle identifier | `com.kzemin.unflip.camera` |
| Shared App Group | `$(TeamIdentifierPrefix)com.kzemin.unflip` |
| Frame transport | Core Media I/O sink/source streams (no ad-hoc XPC, no legacy DAL) |
| Capture ownership | the host app owns the single physical capture session |
| License | intentionally absent until the owner chooses one |

## Implementation status

- Dual preview (two synchronized 16:9 tiles from one capture session, left
  mirrored and right unmirrored): **implemented**, Plan 002.
- `unflip` virtual camera: **not implemented yet**, Plan 003.

## Orientation contract

This is the part users care about, so it is stated exactly:

- **Left preview** — **mirrored**, labeled `Cómo te ves vos`. This is the
  familiar self-view: raising your right hand raises the hand on the right of
  the tile.
- **Right preview** — **unmirrored**, labeled `Cómo te ven los demás`. This is
  what a physical camera normally sends to a call app.
- **Virtual camera output** — **mirrored**, matching the left preview. Turning
  the feature on is what changes what other people see.
- **MVP control copy** — `Mandar a la call la vista espejo`.

Publishing an unmirrored virtual-camera mode is deferred: a physical camera
already supplies that orientation to call apps.

## User-facing copy (rioplatense Spanish, exact strings)

| Key | String |
|-----|--------|
| Left tile | `Cómo te ves vos` |
| Right tile | `Cómo te ven los demás` |
| Virtual camera control | `Mandar a la call la vista espejo` |
| Camera usage description | `unflip usa la cámara solo en esta Mac para mostrarte las dos vistas y, si lo activás, mandar el video a Zoom o Meet.` |
| System extension usage description | `unflip instala una cámara virtual para que otras apps puedan usar el video ya dado vuelta.` |

## Privacy promise

- Camera frames stay on this Mac. They are never uploaded, sent, or proxied.
- No audio is ever captured.
- No frame is ever written to disk.
- No network API is used anywhere in the app or the extension. `URLSession`,
  `NWConnection`, `Network.framework` and `WebKit` are absent by policy and the
  absence is scanned for in CI.
- The camera session runs only while a preview or a virtual-camera consumer
  needs it, and goes idle otherwise.

## Out of scope

Rejected deliberately, not forgotten:

- A settings window, preferences scene, or onboarding carousel.
- Audio capture, recording, screenshots, or any stored media.
- Filters, effects, touch-up, background blur or replacement.
- Accounts, sign-in, analytics, telemetry, crash reporting, or any server.
- Networking of any kind.
- Multiple simultaneous physical cameras or multi-cam compositing.
- macOS 12.3 / 13 support.
- Legacy DAL plug-ins.
- Intel-specific tuning beyond standard architectures.
