# IFF-it QuickLook

macOS Quick Look extension for IFF/ILBM (Amiga Interleaved Bitmap) image files.

## Project Structure

- `project.yml` — XcodeGen spec (run `xcodegen generate` after changes)
- `IFFQuickLook/` — Host app (minimal SwiftUI, registers UTI)
- `IFFPreviewExtension/` — Quick Look preview extension
- `IFFThumbnailExtension/` — Quick Look thumbnail extension
- `IFFSpotlightImporter/` — Spotlight metadata importer (mdimporter)
- `Shared/ILBMParser.swift` — IFF/ILBM parser (shared between all targets)

## Build & Install

Always build **Release** for real testing (Debug is ~17x slower for bitplane decoding):

```bash
xcodegen generate
xcodebuild -project IFFQuickLook.xcodeproj -scheme IFFQuickLook -configuration Release build
```

## Deploying the Quick Look Extension

**IMPORTANT**: macOS caches Quick Look extension processes aggressively. After building, you MUST follow ALL these steps to ensure the new binary is picked up:

```bash
# 1. Kill any running extension process (it stays alive between previews)
killall IFFPreviewExtension 2>/dev/null

# 2. Kill the Quick Look daemon
killall quicklookd 2>/dev/null
killall QuickLookUIService 2>/dev/null

# 3. Copy the built app to /Applications
rm -rf "/Applications/IFF-it QuickLook.app"
cp -R "$(xcodebuild -project IFFQuickLook.xcodeproj -scheme IFFQuickLook -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/IFF-it QuickLook.app" "/Applications/IFF-it QuickLook.app"

# 4. Force re-register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "/Applications/IFF-it QuickLook.app"

# 5. Reset Quick Look caches
qlmanage -r
qlmanage -r cache
```

### Verification

Check which binary the system is actually running:
```bash
# See registered extension path and UUID
pluginkit -mAvvv -p com.apple.quicklook.preview 2>&1 | grep -A5 "iffit"

# See running extension process (check Debug vs Release!)
ps aux | grep IFFPreview | grep -v grep
```

**Common gotcha**: The system may keep a stale Debug process alive even after you build Release. Always check `ps aux` to verify the running process path contains `Products/Release/`, not `Products/Debug/`.

## Deploying the Spotlight Importer

The Spotlight importer (`IFFSpotlightImporter.mdimporter`) is built as a separate scheme and deployed to `~/Library/Spotlight/`.

```bash
# 1. Build the importer
xcodebuild -project IFFQuickLook.xcodeproj -scheme IFFSpotlightImporter -configuration Release build

# 2. Deploy to ~/Library/Spotlight
rm -rf ~/Library/Spotlight/IFFSpotlightImporter.mdimporter
cp -R "$(xcodebuild -project IFFQuickLook.xcodeproj -scheme IFFSpotlightImporter -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/IFFSpotlightImporter.mdimporter" ~/Library/Spotlight/

# 3. Kill Spotlight processes (MUST do this — mdimport -r alone is NOT enough)
killall mds mdworker mdworker_shared 2>/dev/null

# 4. Re-register the importer
mdimport -r ~/Library/Spotlight/IFFSpotlightImporter.mdimporter
```

### Verification

```bash
# Test import in-process (bypasses mdworker, useful for debugging)
mdimport -t -d2 path/to/file.iff

# List registered importers (stale until mds is killed)
mdimport -L 2>&1 | grep -i iff

# Check metadata on a file
mdls path/to/file.iff
```

**Common gotcha**: Three copies of the importer may be registered (~/Library/Spotlight, /Applications app bundle, DerivedData). After killing `mds`, allow 2-3 seconds before re-importing or the old process may respawn with cached binary.

## Deploying the Thumbnail Extension

The thumbnail extension is embedded in the host app and deployed with it. No separate deployment needed — it goes out with the Quick Look extension deployment above.

**Important notes**:
- Thumbnail extensions need a real Apple Developer certificate (not ad-hoc) due to Library Validation
- First install may require a reboot on macOS 26/Tahoe
- The UTI must NOT conform to `public.image` or Apple's built-in ImageIO handler will intercept

## Bundle IDs

- Host app: `com.iffit.IFFQuickLook`
- Preview extension: `com.iffit.IFFQuickLook.IFFPreviewExtension`
- Thumbnail extension: `com.iffit.IFFQuickLook.IFFThumbnailExtension`
- Spotlight importer: `com.iffit.IFFQuickLook.IFFSpotlightImporter`
- UTI: `com.amiga.iff-ilbm` (handles `.iff`, `.ilbm`, `.lbm`)
