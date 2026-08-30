# unflip

A macOS menu-bar app that shows your camera **two ways at once** — mirrored, the
way you are used to seeing yourself, and unmirrored, the way everybody else sees
you — and can publish the mirrored view to Zoom, Meet or Teams through a virtual
camera named `unflip`.

> **Status: pre-alpha.** The project baseline builds and the menu-bar shell
> runs. The dual preview and the working virtual camera are not implemented
> yet. There is no downloadable binary. Do not expect it to be useful today.

## What it does

- One menu-bar icon, one popover, two equal 16:9 tiles.
- Left tile — `Cómo te ves vos` — mirrored.
- Right tile — `Cómo te ven los demás` — unmirrored.
- One switch — `Mandar a la call la vista espejo` — publishes the mirrored view
  as a camera named `unflip` that other apps can select.

## What it does not do

Not "not yet" — deliberately never, for as long as this stays the same product:

- No network access of any kind. No accounts, no sign-in, no analytics, no
  telemetry, no crash reporting, no server.
- No audio or microphone access.
- No recording. No frame is written to disk, ever.
- No filters, effects, touch-up, blur, or background replacement.
- No Dock icon, no settings window, no onboarding.

## Permissions it asks for, and why

| Permission | Why |
|-----------|-----|
| Camera | To read frames from your physical camera and draw the two previews. `unflip usa la cámara solo en esta Mac para mostrarte las dos vistas y, si lo activás, mandar el video a Zoom o Meet.` |
| Install a system extension | Only when you turn the virtual camera on. macOS asks you to approve it once. `unflip instala una cámara virtual para que otras apps puedan usar el video ya dado vuelta.` |

No microphone permission is requested. `unflipTests` fails the build if one is
ever added to `Info.plist`.

## How to check the privacy claims yourself

The app and extension source are the only places frames are handled, and both
are in this repository. Two greps are enough to check the network promise:

```bash
grep -rE 'URLSession|NWConnection|Network\.framework|WebKit' unflip unflipCamera
```

That command must print nothing, and CI fails the build if it ever does. The
entitlements files — [unflip/unflip.entitlements](unflip/unflip.entitlements)
and [unflipCamera/unflipCamera.entitlements](unflipCamera/unflipCamera.entitlements)
— list every capability the sandbox grants; there is no network client
entitlement in either.

The full, narrow product definition lives in
[docs/product-contract.md](docs/product-contract.md).

## Build it

Requires macOS 14.0 or later and Xcode 16 or later.

```bash
xcodebuild -project unflip.xcodeproj -scheme unflip -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

```bash
xcodebuild test -project unflip.xcodeproj -scheme unflip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Activating the virtual camera needs a real signing identity; an unsigned build
compiles and runs the menu-bar shell but cannot install the system extension.

- Deployment target: **macOS 14.0**
- Host bundle identifier: `com.kzemin.unflip`
- Extension bundle identifier: `com.kzemin.unflip.camera`

## Binaries

There are none yet. When a signed and notarized build is published, its release
notes will name the exact source tag it was built from and publish a checksum,
so anyone can rebuild it and compare.

## Security

See [SECURITY.md](SECURITY.md).

## License

Intentionally none for now. The source is public so it can be inspected before
anyone installs a camera extension from it; that is not the same as a grant of
reuse rights. A license will be added when the owner picks one.
