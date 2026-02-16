# Installing IFF-it QuickLook

A step-by-step guide to building and installing the IFF/ILBM Quick Look extension, thumbnail extension, and Spotlight importer on your Mac.

## What You Get

Once installed, you'll be able to:

- **Press Space** on any `.iff`, `.ilbm`, or `.lbm` file in Finder to see a full Quick Look preview
- **See thumbnail images** in Finder (icon view, column view, etc.) instead of generic file icons
- **Search with Spotlight** by IFF metadata (image dimensions, number of colors, Amiga display mode, embedded text annotations)

## Prerequisites

- **macOS 14 (Sonoma) or later**
- **Xcode** — install from the App Store or [developer.apple.com](https://developer.apple.com/xcode/)
- **XcodeGen** — install with `brew install xcodegen`
- **An Apple Developer account** (free is fine) — needed for code signing the thumbnail extension

### Why Do I Need a Developer Account?

The thumbnail extension *must* be signed with a real Apple Development certificate. macOS enforces "Library Validation" on thumbnail extensions — ad-hoc or unsigned builds are silently ignored by the system. A free Apple Developer account works; you don't need the paid $99/year program.

The preview extension and Spotlight importer would technically work without it, but since they're all bundled in one app, you need it anyway.

## Build & Install

### 1. Clone and Generate the Xcode Project

```bash
git clone https://github.com/user/IFF-it-QuickLook.git  # adjust URL
cd IFF-it-QuickLook
xcodegen generate
```

### 2. Set Your Development Team

Open `project.yml` and replace the `DEVELOPMENT_TEAM` value with your own Apple Team ID:

```yaml
settings:
  DEVELOPMENT_TEAM: "YOUR_TEAM_ID"
```

To find your Team ID: open Xcode, go to **Settings > Accounts**, select your Apple ID, and look at the Team ID next to your Personal Team.

Alternatively, open the generated `IFFQuickLook.xcodeproj` in Xcode, go to each target's **Signing & Capabilities** tab, and select your team there.

### 3. Build (Release)

```bash
xcodebuild -project IFFQuickLook.xcodeproj -scheme IFFQuickLook -configuration Release build
```

> **Important:** Always build Release, not Debug. Debug builds are ~17x slower for bitplane decoding, and you may end up testing against the wrong binary if a stale Debug process is cached.

### 4. Install the App

```bash
# Find where Xcode put the build product
BUILD_DIR=$(xcodebuild -project IFFQuickLook.xcodeproj -scheme IFFQuickLook \
  -configuration Release -showBuildSettings 2>/dev/null \
  | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')

# Copy to /Applications
rm -rf "/Applications/IFF-it QuickLook.app"
cp -R "$BUILD_DIR/IFF-it QuickLook.app" "/Applications/IFF-it QuickLook.app"
```

### 5. Register with the System

```bash
# Tell Launch Services about the app (registers UTI + extensions)
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "/Applications/IFF-it QuickLook.app"

# Reset Quick Look caches
qlmanage -r
qlmanage -r cache
```

### 6. Deploy the Spotlight Importer

The Spotlight importer is embedded in the app bundle, but it also needs to be copied to `~/Library/Spotlight/` for reliable detection:

```bash
BUILD_DIR=$(xcodebuild -project IFFQuickLook.xcodeproj -scheme IFFSpotlightImporter \
  -configuration Release -showBuildSettings 2>/dev/null \
  | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')

rm -rf ~/Library/Spotlight/IFFSpotlightImporter.mdimporter
cp -R "$BUILD_DIR/IFFSpotlightImporter.mdimporter" ~/Library/Spotlight/

# Kill Spotlight daemons so they pick up the new importer
killall mds mdworker mdworker_shared 2>/dev/null

# Re-register
mdimport -r ~/Library/Spotlight/IFFSpotlightImporter.mdimporter
```

### 7. Reboot (First Install Only)

On the **first install**, macOS (especially macOS 15/Sequoia and 26/Tahoe) does not discover newly registered thumbnail extensions until after a reboot. This is a macOS quirk — PlugInKit's protocol matching for `com.apple.quicklook.thumbnail` doesn't pick up new extensions without one.

Subsequent rebuilds do **not** require a reboot — just kill the cached processes (see Troubleshooting below).

## Verify It's Working

### Quick Look Preview

Select any `.iff` file in Finder and press **Space**. You should see the decoded image.

### Thumbnails

Check Finder in icon view — `.iff` files should show image previews instead of generic document icons. If they don't appear immediately, try:

```bash
killall Finder
```

### Spotlight Metadata

```bash
mdls path/to/file.iff
```

You should see attributes like `kMDItemPixelWidth`, `kMDItemPixelHeight`, `kMDItemBitsPerSample`, etc.

## Troubleshooting

### Quick Look Preview Not Showing

macOS caches extension processes aggressively. The nuclear option:

```bash
killall IFFPreviewExtension quicklookd QuickLookUIService 2>/dev/null
qlmanage -r
qlmanage -r cache
```

Then try pressing Space again.

### Thumbnails Not Showing

```bash
# Kill all thumbnail-related processes
killall IFFThumbnailExtension com.apple.quicklook.ThumbnailsAgent Finder 2>/dev/null
qlmanage -r
qlmanage -r cache
```

If this is your first install and you haven't rebooted yet — **reboot**.

Check that the extension is registered:
```bash
pluginkit -mAvvv 2>&1 | grep -A5 "IFFThumbnail"
```

Check that code signing is correct (must show a Team ID, not `(not set)`):
```bash
codesign -dvvv "/Applications/IFF-it QuickLook.app/Contents/PlugIns/IFFThumbnailExtension.appex" 2>&1 | grep TeamIdentifier
```

### Spotlight Importer Not Working

```bash
# Kill Spotlight processes
killall mds mdworker mdworker_shared 2>/dev/null
sleep 3

# Re-register
mdimport -r ~/Library/Spotlight/IFFSpotlightImporter.mdimporter

# Test import (runs in-process, bypasses mdworker — good for debugging)
mdimport -t -d2 path/to/file.iff
```

Check that the importer is registered:
```bash
mdimport -L 2>&1 | grep -i iff
```

### Stale Debug Build Running

A common gotcha: the system may keep a stale Debug process alive even after you build Release.

```bash
ps aux | grep IFFPreview | grep -v grep
```

If the path contains `Products/Debug/` instead of `Products/Release/`, kill it:
```bash
killall IFFPreviewExtension 2>/dev/null
```

## Lessons Learned (The Hard Way)

These are the non-obvious pitfalls we hit while building this project:

1. **Thumbnail extensions require real code signing.** Ad-hoc signing is silently ignored — no error, no log, just nothing happens. A free Apple Developer account is enough.

2. **The UTI must NOT conform to `public.image`.** If it does, Apple's built-in ImageIO thumbnail handler intercepts all requests, tries to decode the file (fails, because ImageIO doesn't understand ILBM), and returns a generic icon. Our extension never gets called. The fix: conform only to `public.data`. And beware — UTI conformance is cached aggressively. If you *ever* register with `public.image`, the system may remember it even after you remove it.

3. **First install requires a reboot.** PlugInKit doesn't discover new thumbnail extensions until after a reboot on macOS 15+. No amount of cache-clearing or daemon-killing helps. Subsequent deploys are fine without rebooting.

4. **macOS caches everything.** Quick Look extension processes stay alive between previews. `quicklookd`, `ThumbnailsAgent`, `mds`, `mdworker` — all cache the old binary. After every rebuild you must kill the relevant processes and reset caches. `lsregister -f` re-registers the app with Launch Services. `qlmanage -r` resets Quick Look. `killall mds` resets Spotlight.

5. **`mdimport -r` alone is not enough for Spotlight.** You must `killall mds mdworker mdworker_shared` first. The old `mds` process holds on to the cached importer binary. Wait 2–3 seconds after killing before re-importing, or the respawning process may grab the old binary.

6. **Debug vs Release matters.** Debug builds are ~17x slower for bitplane decoding. Worse, the system may keep a stale Debug extension process alive while you think you're testing your new Release build. Always verify with `ps aux`.

7. **Three copies of the Spotlight importer can exist.** `~/Library/Spotlight/`, inside the app bundle at `/Applications/`, and in Xcode's DerivedData. This can cause confusion about which one is actually running.

8. **`mdimport -t -d2` is your best friend.** It runs the Spotlight importer in-process (not via mdworker), so you get immediate crash logs and debug output. Regular `mdimport file` goes through mdworker, which swallows errors silently.

## Uninstalling

```bash
rm -rf "/Applications/IFF-it QuickLook.app"
rm -rf ~/Library/Spotlight/IFFSpotlightImporter.mdimporter
killall mds mdworker mdworker_shared quicklookd 2>/dev/null
qlmanage -r
```
