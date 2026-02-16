# Finder Thumbnail Previews for .iff Files

## Status: Working

Thumbnail extension is built, signed, and working. Finder shows image previews for .iff/.ilbm/.lbm files.

## What We Built

- `IFFThumbnailExtension/` — a `QLThumbnailProvider` app-extension that decodes IFF/ILBM files and returns thumbnail images
- Registered with extension point `com.apple.quicklook.thumbnail`
- Shares `ILBMParser.swift` with the preview extension
- Embedded in the host app at `Contents/PlugIns/IFFThumbnailExtension.appex`

## Requirements

### 1. Proper Code Signing (Critical)

The thumbnail extension **must** be signed with an Apple Developer certificate (not ad-hoc). ThumbnailsAgent uses Library Validation which requires a Team ID.

In `project.yml`:
```yaml
settings:
  DEVELOPMENT_TEAM: "YOUR_TEAM_ID"

targets:
  IFFQuickLook:
    settings:
      CODE_SIGN_IDENTITY: "Apple Development"
```

Verify with:
```bash
codesign -dvvv "/Applications/IFF-it QuickLook.app/Contents/PlugIns/IFFThumbnailExtension.appex" 2>&1 | grep TeamIdentifier
```
Must show a 10-character alphanumeric Team ID, NOT `(not set)`.

### 2. UTI Must NOT Conform to `public.image`

If `com.amiga.iff-ilbm` conforms to `public.image`, the built-in `ImageThumbnailExtension` intercepts ALL requests. It tries ImageIO (which can't decode ILBM), fails, and returns a generic icon — our extension never gets called.

**Fix**: Use `UTExportedTypeDeclarations` (takes priority over imported) with only `public.data`:
```xml
<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
        </array>
        ...
    </dict>
</array>
```

**Important**: UTI conformance is additive and cached aggressively. If you ever register with `public.image`, the system remembers it even after removal. `UTExportedTypeDeclarations` gives your app ownership and higher priority than `UTImportedTypeDeclarations`.

### 3. Reboot Required After First Install

On macOS 26 (Tahoe), PlugInKit's protocol matching for `com.apple.quicklook.thumbnail` does not pick up newly registered extensions until after a **reboot**. Killing daemons, resetting caches, and `pluginkit -r` are insufficient — a full reboot is required for the ThumbnailsAgent to discover the extension through PlugInKit.

This appears to be a macOS 26-specific behavior. Subsequent rebuilds/deploys should not require rebooting (killing processes and resetting caches is enough).

## Debugging Thumbnails

### Check UTI assignment
```bash
mdls -name kMDItemContentType -name kMDItemContentTypeTree /path/to/file.iff
```

### Check UTType conformance (authoritative, not cached)
```bash
swift -e 'import UniformTypeIdentifiers; if let t = UTType("com.amiga.iff-ilbm") { print("conforms to public.image:", t.conforms(to: .image)); print("conforms to public.data:", t.conforms(to: .data)) }'
```

### Check extension is registered
```bash
pluginkit -mAvvv 2>&1 | grep -A5 "IFFThumbnail"
```

### Check if extension is actually invoked
```bash
log stream --predicate 'subsystem == "com.iffit.IFFQuickLook.IFFThumbnailExtension" OR process == "IFFThumbnailExtension"' --level debug
```

### Check what the system dispatches to
```bash
log stream --predicate 'process == "com.apple.quicklook.ThumbnailsAgent" AND eventMessage CONTAINS "Launching"' --level debug
```
If it shows `com.apple.quicklook.thumbnail.ImageExtension`, the built-in handler is intercepting (likely a `public.image` conformance issue).

### Nuclear reset
```bash
killall IFFThumbnailExtension com.apple.quicklook.ThumbnailsAgent quicklookd extensionkitservice Finder 2>/dev/null
qlmanage -r && qlmanage -r cache
pluginkit -r
```
If this doesn't work, reboot.

## Architecture Notes

macOS 26 has two parallel thumbnail dispatch paths:

1. **ExtensionKit** (system-only): Apple's built-in handlers at `/System/Library/ExtensionKit/Extensions/` use `EXExtensionPointIdentifier: com.apple.quicklook.thumbnail.secure` (private, not available to third-party)

2. **PlugInKit** (third-party): Our extension uses `NSExtensionPointIdentifier: com.apple.quicklook.thumbnail` and is discovered by PlugInKit, then handed to ThumbnailsAgent

Both paths feed into `ThumbnailsAgent`. When no third-party PlugInKit extension matches, ThumbnailsAgent falls back to the ExtensionKit system handlers.

## References

- [Apple: Providing Thumbnails of Your Custom File Types](https://developer.apple.com/documentation/quicklookthumbnailing/providing-thumbnails-of-your-custom-file-types)
- [Eclectic Light: How does QuickLook create Thumbnails and Previews?](https://eclecticlight.co/2024/11/04/how-does-quicklook-create-thumbnails-and-previews-with-an-update-to-mints/)
- [Eclectic Light: How Sequoia has changed QuickLook](https://eclecticlight.co/2024/10/31/how-sequoia-has-changed-quicklook-and-its-thumbnails/)
- [Apple Developer Forums: QLThumbnailProvider doesn't work](https://developer.apple.com/forums/thread/681132)
- [TN3127: Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements)
