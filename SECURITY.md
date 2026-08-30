# Security policy

`unflip` installs a macOS Camera Extension and reads your camera. That is a
sensitive amount of trust, so please report anything that looks wrong.

## Reporting a vulnerability

Use **GitHub private vulnerability reporting**:

1. Go to <https://github.com/kzemin/unflip/security/advisories/new>.
2. Describe the issue, the macOS and `unflip` versions, and how to reproduce it.

That form is private — the report is visible only to the repository maintainers
until a fix is published. Please do not open a public issue for a vulnerability,
and please do not include recordings or screenshots containing other people.

There is no security contact email; a maintained private form beats an address
that might stop being read.

## Scope

Especially interested in reports about:

- any path where a camera frame leaves this Mac, is written to disk, or reaches
  a process that should not have it;
- anything that lets code other than `unflip` publish frames through the
  `unflip` virtual camera;
- sandbox, entitlement, hardened-runtime, or code-signing weaknesses in the app
  or the embedded system extension;
- the camera session continuing to run when no preview and no consumer needs it.

Out of scope: the absence of features listed as out of scope in
[docs/product-contract.md](docs/product-contract.md), and issues that require an
attacker to already have administrator access to the Mac.

## Supported versions

Pre-alpha: only the current `main` branch is supported. There are no published
binaries yet, so there is nothing older to patch.
