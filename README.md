# IFF-it QuickLook

Native macOS support for Amiga IFF/ILBM image files. Preview, thumbnails, and Spotlight search — just like any other image format.
<img width="720" alt="Quick Look preview" src="https://github.com/user-attachments/assets/1bbeb29b-3cc1-483a-b5eb-418ebb49fa9c" />
<img width="720" alt="CleanShot 2026-02-16 at 16 39 02@2x" src="https://github.com/user-attachments/assets/d88722e2-67ae-46e0-afee-f82c634a40f2" />

## Features

### Quick Look Preview
Select an `.iff` file in Finder and press **Space** to see the decoded image instantly.

### Finder Thumbnails
See actual image previews in Finder instead of generic document icons — in icon view, gallery view, column view, everywhere.

### Spotlight Search
Find IFF files by metadata: image dimensions, color mode, author, title, and embedded annotations. All searchable through Spotlight.


<img width="300" alt="Spotlight metadata" src="https://github.com/user-attachments/assets/83002d28-34dc-416e-97e2-d0ece3ab2cf2" />

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
