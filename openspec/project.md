# Project Context

## Purpose
IFF-it QuickLook is a macOS app that adds native system integration for IFF/ILBM (Amiga Interleaved Bitmap) image files. It provides Quick Look previews, Finder thumbnails, and UTI registration so macOS recognizes `.iff`, `.ilbm`, and `.lbm` files as images.

## Tech Stack
- **Language**: Swift 5.9
- **Platforms**: macOS 14.0+ (Sonoma)
- **UI**: SwiftUI (host app), AppKit (preview extension)
- **Frameworks**: QuickLookUI, QuickLookThumbnailing, CoreGraphics, ImageIO
- **Build**: XcodeGen (`project.yml` → `IFFQuickLook.xcodeproj`), Xcode 16
- **Code signing**: Apple Development (team `T9377257FH`), automatic signing

## Project Conventions

### Code Style
- Pure Swift, no Objective-C
- Parser is an `enum` (namespace, no instances) with `static` functions
- Extensions use AppKit directly (no SwiftUI) for preview/thumbnail rendering
- `os.log` `Logger` for diagnostics in extensions (subsystem: `com.iffit.IFFQuickLook.<target>`)
- MARK comments to organize sections (`// MARK: - Section Name`)

### Architecture Patterns
- **Shared parser**: `Shared/ILBMParser.swift` is compiled into each target that needs it (not a framework — each extension/app target lists `Shared/` in its sources)
- **Extension-per-feature**: Each system integration point is a separate app extension target embedded in the host app
- **Host app as container**: The host app (`IFFQuickLook`) primarily exists to register the UTI and embed extensions. It has a minimal informational UI.
- **Zero-copy where possible**: The parser avoids copying the BODY chunk data for uncompressed files, working directly with `UnsafeBufferPointer` into `Data`'s backing store

### Target Structure
| Target | Type | Bundle ID | Purpose |
|--------|------|-----------|---------|
| IFFQuickLook | application | `com.iffit.IFFQuickLook` | Host app, UTI registration |
| IFFPreviewExtension | app-extension | `com.iffit.IFFQuickLook.IFFPreviewExtension` | Quick Look full preview |
| IFFThumbnailExtension | app-extension | `com.iffit.IFFQuickLook.IFFThumbnailExtension` | Finder thumbnail icons |

### Testing Strategy
- No automated test target currently; manual testing with sample IFF files
- Standalone test scripts (`test_parser.swift`, `test_bench.swift`, `test_convert.swift`) exist for ad-hoc verification
- Always build **Release** for real testing (Debug is ~17x slower for bitplane decoding)
- Deployment verification via `pluginkit`, `mdls`, `ps aux`, and `qlmanage` commands (see CLAUDE.md)

### Git Workflow
- `main` branch is the primary branch
- Development on `master` (to be merged to `main`)
- `IFFQuickLook.xcodeproj/` is generated and not committed (use `xcodegen generate`)
- Commit messages: short summary line, optional body explaining why

## Domain Context

### IFF/ILBM Format
IFF (Interchange File Format) is a chunked container format from the Amiga era. ILBM (Interleaved Bitmap) is the image sub-format. Key concepts:

- **Chunks**: Tagged data blocks (4-char ID + 32-bit size + data). Key chunks:
  - `BMHD` — Bitmap header (dimensions, bit depth, compression, aspect ratio)
  - `CMAP` — Color palette (RGB triples)
  - `CAMG` — Amiga viewport mode flags (HAM, EHB modes)
  - `BODY` — Pixel data (interleaved bitplanes)
  - `ANNO` — Text annotation
  - `AUTH` — Author name
  - `(c) ` — Copyright notice
  - `NAME` — Image title
- **Bitplanes**: Pixels stored as interleaved planes (1 bit per plane per pixel), not chunky RGB
- **Color modes**: Standard indexed, EHB (Extra Half-Brite, 64 colors from 32), HAM6 (Hold And Modify, 4096 colors), HAM8 (262144 colors), 24-bit direct, 32-bit direct+alpha
- **PBM**: Variant with chunky (non-interleaved) pixel data
- **Compression**: None (0) or ByteRun1/PackBits (1)

### UTI Registration
- Custom UTI: `com.amiga.iff-ilbm`
- Conforms to `public.data` only (NOT `public.image` — this is critical; conforming to `public.image` causes Apple's built-in ImageIO thumbnail handler to intercept and fail)
- Registered as `UTExportedTypeDeclarations` (takes priority over imported)
- File extensions: `.iff`, `.ilbm`, `.lbm`
- MIME types: `image/x-ilbm`, `image/iff`

## Important Constraints
- **UTI must NOT conform to `public.image`**: Apple's built-in `ImageThumbnailExtension` intercepts all `public.image` types, tries ImageIO (which can't decode ILBM), fails silently, and our extension never gets called
- **Code signing required**: Thumbnail extension must be signed with a real Apple Developer certificate (not ad-hoc) because `ThumbnailsAgent` uses Library Validation
- **macOS caches aggressively**: After building, must kill extension processes, quicklookd, and reset QL caches (see CLAUDE.md deploy steps)
- **First install requires reboot**: On macOS 26/Tahoe, PlugInKit doesn't discover new thumbnail extensions until after a reboot
- **Sandboxed**: All targets use App Sandbox. Extensions that need file access get it from the system (Quick Look passes the file URL)

## External Dependencies
- None. The project has zero third-party dependencies. All parsing is implemented from scratch using only Foundation and CoreGraphics.
