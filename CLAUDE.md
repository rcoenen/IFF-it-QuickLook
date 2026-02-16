<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# IFF-it QuickLook

macOS Quick Look extension for IFF/ILBM (Amiga Interleaved Bitmap) image files.

## Project Structure

- `project.yml` — XcodeGen spec (run `xcodegen generate` after changes)
- `IFFQuickLook/` — Host app (minimal SwiftUI, registers UTI)
- `IFFPreviewExtension/` — Quick Look preview extension
- `Shared/ILBMParser.swift` — IFF/ILBM parser (shared between targets)

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

## Bundle IDs

- Host app: `com.iffit.IFFQuickLook`
- Extension: `com.iffit.IFFQuickLook.IFFPreviewExtension`
- UTI: `com.amiga.iff-ilbm` (handles `.iff`, `.ilbm`, `.lbm`)
