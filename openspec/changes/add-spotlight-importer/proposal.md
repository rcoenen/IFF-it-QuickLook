# Change: Add Spotlight Metadata Importer for IFF/ILBM files

## Why
Finder's "More Info" section shows `--` for .iff files because no Spotlight importer extracts metadata. IFF/ILBM files contain rich metadata (dimensions, color depth, author, annotations) that should be surfaced in Finder and Spotlight search.

## What Changes
- Add `ILBMParser.parseMetadata()` — lightweight metadata-only function that walks IFF chunks without decoding pixel data
- Add `IFFSpotlightImporter` target — an mdimporter bundle that extracts image metadata for Spotlight/Finder
- Update `project.yml` with new target and embedding configuration

## Impact
- Affected specs: spotlight-metadata (new capability)
- Affected code:
  - `Shared/ILBMParser.swift` — add `IFFMetadata` struct and `parseMetadata()` function
  - `project.yml` — add target, dependency, embed build phase
  - New: `IFFSpotlightImporter/` directory (entry point, Info.plist)
