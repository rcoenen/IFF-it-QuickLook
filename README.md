# IFF-it QuickLook

Native macOS support for Amiga IFF/ILBM image files. Preview, thumbnails, and Spotlight search — just like any other image format.
<img width="1820" height="728" alt="CleanShot 2026-02-16 at 16 33 37@2x" src="https://github.com/user-attachments/assets/4987d2b7-9d5d-42bf-8ccb-61ab9a330c2d" />

## Features

### Quick Look Preview
Select an `.iff` file in Finder and press **Space** to see the decoded image instantly.

### Finder Thumbnails
See actual image previews in Finder instead of generic document icons — in icon view, gallery view, column view, everywhere.

### Spotlight Search
Find IFF files by metadata: image dimensions, color mode, author, title, and embedded annotations. All searchable through Spotlight.

## Supported Formats

Handles `.iff`, `.ilbm`, and `.lbm` files with the following IFF/ILBM features:

| Feature | Details |
|---------|---------|
| **Standard indexed** | 1–8 bitplanes, up to 256 colors |
| **EHB (Extra Half-Brite)** | 64-color mode with auto-generated half-brightness palette |
| **HAM6** | Hold And Modify, 4096 colors (OCS/ECS) |
| **HAM8** | Hold And Modify, 16 million colors (AGA) |
| **SHAM** | Sliced HAM with per-scanline palettes |
| **24-bit / 32-bit** | Direct color with optional alpha channel |
| **PBM** | Planar Bitmap (chunky) format variant |
| **ByteRun1** | PackBits RLE compression |
| **Mask planes** | Transparency masking |

### Metadata Extracted by Spotlight

| Attribute | Source |
|-----------|--------|
| Image dimensions | BMHD chunk |
| Bits per sample | Bitplane count |
| Color space | Indexed, EHB, HAM6, HAM8, SHAM, Direct 24/32-bit |
| Title | NAME chunk |
| Author | AUTH chunk |
| Copyright | (c) chunk |
| Comments | ANNO chunk |

## Installation

See **[INSTALL.md](INSTALL.md)** for build instructions, deployment steps, and troubleshooting.

**TL;DR:** You need Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and a free Apple Developer account (for code signing the thumbnail extension).

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16+

## License

TBD
