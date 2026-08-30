# Claude autonomous execution brief

This is the single document to give an implementation session. It authorizes
the session to build the `unflip` MVP plan by plan without routine approval
check-ins. The detailed technical requirements remain in the numbered plan
files; this document defines execution order, autonomy, question policy, git
behavior, and external-action boundaries.

## Mission

Build the greenfield `unflip` macOS MVP described in `plans/README.md` by
executing Plans 001 through 004 in order. `unflip` is a local-only macOS 14+
menu-bar app that:

1. shows one physical camera simultaneously as a mirrored left preview and an
   unmirrored right preview; and
2. publishes the mirrored left-preview orientation through a sandboxed virtual
   camera named `unflip`.

The app has no Dock icon, normal Settings window, account, analytics, network
service, audio, recording, stored frames, filters, or backgrounds.

## Resolved decisions — do not ask again

- Product/device/display name: `unflip`.
- Minimum deployment target: macOS 14.0.
- Technology: native SwiftUI + AppKit, AVFoundation, Core Media I/O Camera
  Extension; no third-party runtime dependency.
- UI: menu-bar status item opening a compact popover with two equal 16:9 tiles.
- Left: `Cómo te ves vos`, mirrored.
- Right: `Cómo te ven los demás`, unmirrored.
- Virtual output: mirrored, matching the left preview.
- MVP virtual-camera control: `Mandar a la call la vista espejo`.
- Camera device name visible in call apps: `unflip`.
- Host app owns the one physical capture session.
- Preferred frame transport proof: CMIO sink/source streams; do not invent
  ad-hoc XPC or use legacy DAL unless a documented platform failure forces a
  new architecture review.
- Bundle IDs to try first: `com.kzemin.unflip` and
  `com.kzemin.unflip.camera`.
- Do not add a license; omission is intentional until the owner chooses one.
- Use standard architectures. Do not spend MVP time on Intel-only quirks.

## Read before changing anything

Read these files completely in this order:

1. `plans/CLAUDE_EXECUTION.md`
2. `plans/README.md`
3. `plans/001-establish-project-baseline.md`
4. The next numbered plan only after its dependency is DONE.

Then run:

```sh
pwd
git status --short --branch
git remote -v
xcodebuild -version
swift --version
```

Expected starting facts: repository root ends in `/unflip`, local branch is an
unborn `main`, `origin` is `https://github.com/kzemin/unflip.git`, source is
empty except `plans/`, and Xcode is available. If harmless facts have changed,
reconcile them and continue. Ask only if the change materially conflicts with
the product or makes a plan unsafe.

## Autonomous execution loop

For each numbered plan:

1. Read the entire plan before editing.
2. Check its dependency and STOP conditions against the live repository.
3. Change its status in `plans/README.md` to `IN PROGRESS`.
4. Execute its steps in order. Make reasonable implementation choices inside
   the stated architecture and scope without asking for preferences.
5. Run every verification command and the complete relevant test suite.
6. Inspect the diff for scope, privacy, lifecycle, naming, and generated-file
   mistakes. Fix failures before continuing.
7. Mark the plan `DONE`, or `BLOCKED: <concise reason>` only if genuinely
   unable to proceed.
8. Commit the completed, verified plan as one or more logical commits.
9. Push `main` to the already-configured public `origin` after each DONE plan so
   the source remains inspectable. Never force-push or rewrite public history.
10. Move immediately to the next plan; do not ask for a routine review between
    plans.

The existing planning files are part of the initial repository and should be
included in the first commit. Use Conventional Commit messages. Keep the
working tree clean at plan boundaries.

## Authority granted

Without asking, you may:

- create and edit all in-scope application, extension, test, documentation,
  project, and CI files described by the plans;
- create the Xcode project and targets;
- run builds, tests, static inspections, format/check commands, and local Debug
  launches;
- create local commits and push normal, non-force commits to `main` on
  `kzemin/unflip` after plan gates pass;
- make small corrective changes required for compilation, tests, sandboxing,
  accessibility, lifecycle, and plan acceptance;
- select ordinary internal names and code organization consistent with the
  plan when no public behavior changes;
- defer unavailable optional hardware/call-app matrix entries while completing
  every test that is possible locally, clearly recording what remains manual.

## Actions not authorized without an essential question

Do not do any of the following without asking first:

- publish a downloadable binary, GitHub Release, tag intended as a release,
  App Store submission, or notarized DMG;
- spend money, enroll in a developer program, create certificates, or change
  the owner's Apple/GitHub account settings;
- expose or store signing/notarization credentials, tokens, certificates, or
  provisioning secrets;
- weaken App Sandbox, library validation, Gatekeeper, SIP, or camera privacy;
- change the resolved product behavior, name, deployment target, or privacy
  promise;
- force-push, delete public history, delete repositories, or merge unrelated
  work;
- install a legacy DAL plug-in or an undocumented privileged helper;
- perform a destructive operation outside explicit build products.

Plan 004 may complete documentation, QA, release configuration, and local
archive preparation autonomously. It must pause before the first public binary
release/notarization action if credentials or explicit publication authority
are required.

## Essential-question policy

Do not ask about preferences, code style, file names, small UI details, test
structure, whether to continue to the next plan, or choices already resolved in
this document. Investigate local files, Xcode templates, SDK headers, build
output, and official Apple documentation first.

Ask a question only when all four conditions are true:

1. the answer cannot be discovered from the repository, local toolchain, or
   official documentation;
2. a reasonable assumption could materially change public behavior, privacy,
   security, signing identity, cost, or irreversible external state;
3. no safe in-scope work remains that can proceed first; and
4. the blocker has been reproduced or supported by concrete evidence.

Likely essential questions are limited to:

- the Apple Development Team or reverse-DNS prefix if the proposed identifiers
  cannot be signed;
- asking the owner to click a macOS camera/system-extension approval that only
  a human can grant;
- choosing between materially different architectures only after the planned
  CMIO transport proof demonstrably fails;
- permission to publish the first signed/notarized downloadable release;
- access to a missing signing/notarization credential at the moment it becomes
  the only remaining blocker.

When an essential question is unavoidable, ask exactly one question at a time
using this format:

```text
Blocker: <one sentence>
Evidence: <specific command/API result>
Recommended answer: <one concrete choice and why>
If approved: <what will proceed>
If not: <safe fallback or what remains blocked>
```

Do not send progress questions disguised as updates. Continue with other safe
work before asking.

## Failure and drift behavior

- A plan verification failure is not automatically a user question. Diagnose
  it, consult the installed SDK/Xcode Camera Extension template and official
  Apple docs, make one or two reasonable corrections, and rerun the gate.
- Preserve any user-authored or unrelated changes. Never discard them with
  destructive git commands.
- If live code has drifted from a future plan because an earlier plan chose an
  equivalent structure, adapt exact paths while preserving the plan's intent,
  boundaries, and verification. Record the mapping in the commit or plan
  status; do not ask merely because a filename differs.
- If a STOP condition is real but affects only later work, finish all safe work
  first, mark the blocked plan accurately, and then ask the single essential
  question.
- Never weaken privacy/security to turn a red verification green.

## Required plan-boundary checks

At every plan boundary run at least:

```sh
xcodebuild -project unflip.xcodeproj -scheme unflip -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project unflip.xcodeproj -scheme unflip -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
rg -n -i 'p[o]nla' . -g '!plans/**' -g '!.git/**'
rg -n 'URLSession|NWConnection|Network\.framework|WebKit' unflip unflipCamera
git status --short
```

The build and tests must exit 0. The naming and network scans must have no
unexplained matches. For signed extension verification, also run the signed
commands in Plans 003 and 004; do not treat an unsigned CI build as proof that
activation works.

## Completion report

Do not stop after scaffolding. Continue until Plans 001–004 are DONE or a real
external blocker prevents further work. At the end, report only:

- plan status table;
- commits pushed and public branch URL;
- build/test/manual verification results;
- exact remaining manual checks or blockers;
- whether any public binary was intentionally not released.

Do not claim completion when only compilation or generated test frames work.
The MVP is complete only when the dual preview works, the signed Camera
Extension appears as `unflip`, its output is mirrored, capture goes idle when
unused, and the privacy/release checks have evidence.
