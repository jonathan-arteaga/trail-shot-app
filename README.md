# TrailShot

TrailShot is a native macOS screenshot utility for internal Salesforce workflows.
It is designed to feel fast, quiet, and cohesive: capture first, mark clearly,
copy or save instantly, and keep the full workflow local.

## Current Working Slice

- Native Swift/SwiftUI macOS app shell
- Menu bar capture actions
- Editable conflict-safe global shortcuts with native Settings controls
- Capture-flow Settings for clipboard copy, quick-access bubble, and automatic redaction
- Timed capture delay with visible countdown for transient UI states
- First-run Screen Recording permission guidance
- Full-screen capture through ScreenCaptureKit
- Multi-display area selection with stitched ScreenCaptureKit region capture on modern macOS
- Display and area captures exclude TrailShot’s own windows
- Hover-targeted window capture overlay
- ScreenCaptureKit-backed window picker fallback and window capture
- Window picker thumbnails and row hover highlighting
- Auto-copy latest capture to the clipboard
- Save selected capture as PNG
- Inline annotations: arrows, shapes, text labels, redaction blocks, and numbered steps
- Move, select, delete, undo, and clear annotation workflows
- Resize handles for arrows, shapes, and redaction blocks
- Edit placed text labels from the inspector
- Local Vision OCR detection for likely-sensitive text
- Optional auto-detection of sensitive text immediately after capture
- Local sharing guard that checks screenshots before copy, save, or drag export
- Local OCR text extraction with copy-to-clipboard
- Annotated copy/save export
- Presentation-ready framed copy/save export
- Drag-out PNG sharing for annotated and framed captures
- Local main-display and selected-area screen recording to Movies/TrailShot
- Recording history for saved `.mov` files with open, reveal, refresh, and trash controls
- Recording trim export for local clipped `.mov` copies
- Floating quick-access bubble after capture
- Pin selected captures to the screen
- Pinned capture organizer with focus, close, and close-all controls
- Capture history sidebar with search, favorites, rename, delete, and clear-history controls
- Persistent local capture history with annotations restored from Application Support
- Local capture and recording retention controls for automatic cleanup
- Minimal TrailShot logo/icon with a subtle Astro nod
- Project-local run script and DMG packaging script

## Run

```bash
./script/build_and_run.sh
```

TrailShot needs macOS Screen Recording access for local screen and window
capture. The app surfaces the current access state and can open the correct
System Settings pane.

Default global shortcuts use Control-Option-Shift so TrailShot works without
disabling Apple's built-in screenshot keys. They can be changed from TrailShot
Settings.

- Capture area: `⌃⌥⇧4`
- Capture full screen: `⌃⌥⇧3`
- Capture window: `⌃⌥⇧5`
- Record or stop: `⌃⌥⇧R`
- Record area: `⌃⌥⇧A`

## Test

```bash
swift test
```

## Package a DMG

```bash
./script/package_dmg.sh
```

By default this runs tests, creates a hardened-runtime, ad-hoc signed
development build, packages `dist/TrailShot.dmg`, and validates the artifact.
The bundle is stamped with version/build metadata:

- `TRAILSHOT_VERSION`, default `0.1.0`
- `TRAILSHOT_BUILD_NUMBER`, default commit count
- `TRAILSHOT_RELEASE_CHANNEL`, default `development`
- `TRAILSHOT_GIT_COMMIT`, default current short commit

To also launch-verify the app while packaging locally:

```bash
TRAILSHOT_PACKAGE_VERIFY_LAUNCH=1 ./script/package_dmg.sh
```

For a distributable Developer ID build:

```bash
TRAILSHOT_VERSION="0.1.0" TRAILSHOT_RELEASE_CHANNEL="internal" TRAILSHOT_CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/package_dmg.sh
```

Validate the current app and DMG artifacts:

```bash
./script/validate_release_artifact.sh
```

Notarize a Developer ID signed DMG:

```bash
TRAILSHOT_NOTARY_PROFILE="notarytool-profile" ./script/notarize_release.sh
```

The current DMG is not notarized yet. A broad internal distribution should use
Developer ID signing, notarization, and stapling before release.

## GitHub Releases

The repo includes GitHub Actions for CI and downloadable DMGs:

- Pushes and pull requests run tests, build the app bundle, package a DMG, and
  upload the DMG as a workflow artifact.
- Tags that start with `v`, such as `v0.1.0`, create or update a GitHub Release
  with `TrailShot.dmg` attached.
- The release workflow can also be run manually with a tag input.

GitHub-built DMGs are ad-hoc signed until Developer ID signing secrets are added.

## Product Direction

TrailShot should borrow the best ideas from CleanShot X, Shottr, macshot,
Snapzy, Shotnix, and Capso without feeling like a pile of features. The center
of gravity is a single clean workflow:

1. Capture something quickly.
2. Mark it up with only the tools that matter.
3. Copy, save, pin, drag, or share without friction.
4. Keep sensitive data local by default.

## Near-Term Build Targets

- Window targeting polish on multi-display setups
- Developer ID signing, hardened runtime, notarization, and stapled DMG release
