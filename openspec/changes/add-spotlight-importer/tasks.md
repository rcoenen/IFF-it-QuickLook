## 1. Parser Enhancement
- [ ] 1.1 Add `IFFMetadata` struct to `ILBMParser` with fields: width, height, numPlanes, compression, camgFlags, paletteColorCount, xAspect, yAspect, annotation, author, copyright, name
- [ ] 1.2 Add `parseMetadata(data:)` static function that walks IFF chunks (BMHD, CMAP, CAMG, ANNO, AUTH, `(c) `, NAME) and returns `IFFMetadata` without decoding BODY

## 2. Spotlight Importer Target
- [ ] 2.1 Create `IFFSpotlightImporter/` directory
- [ ] 2.2 Create `GetMetadataForFile.swift` with `@_cdecl("GetMetadataForFile")` entry point that calls `ILBMParser.parseMetadata()` and populates Spotlight attributes
- [ ] 2.3 Create `Info.plist` with `CFBundleDocumentTypes` declaring `com.amiga.iff-ilbm` with role `MDImporter`
- [ ] 2.4 Create `IFFSpotlightImporter.entitlements` with App Sandbox

## 3. Build Configuration
- [ ] 3.1 Add `IFFSpotlightImporter` target to `project.yml` as `type: bundle` with `WRAPPER_EXTENSION: mdimporter`
- [ ] 3.2 Add as dependency of `IFFQuickLook` host app
- [ ] 3.3 Add copy files build phase to embed at `Contents/Library/Spotlight/`

## 4. Verification
- [ ] 4.1 Build succeeds: `xcodegen generate && xcodebuild -scheme IFFQuickLook -configuration Release build`
- [ ] 4.2 Deploy to /Applications and verify mdimporter is embedded
- [ ] 4.3 Force re-index: `mdimport /path/to/file.iff`
- [ ] 4.4 Verify metadata: `mdls /path/to/file.iff` shows pixel dimensions, bit depth, etc.
- [ ] 4.5 Finder Get Info shows image metadata in "More Info"
