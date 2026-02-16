## ADDED Requirements

### Requirement: Metadata-Only Parser
The system SHALL provide a `parseMetadata(data:)` function that extracts IFF/ILBM header metadata without decoding the BODY chunk.

The function SHALL return an `IFFMetadata` struct containing:
- Image dimensions (width, height) from BMHD
- Bit depth (numPlanes) from BMHD
- Compression type from BMHD
- CAMG viewport mode flags
- Palette color count from CMAP
- Pixel aspect ratio (xAspect, yAspect) from BMHD
- Text metadata: annotation (ANNO), author (AUTH), copyright (`(c) `), name (NAME)

#### Scenario: Parse standard ILBM metadata
- **WHEN** a valid IFF/ILBM file is provided
- **THEN** `parseMetadata` returns dimensions, bit depth, and any text chunks present without allocating pixel buffers

#### Scenario: Parse file with no text chunks
- **WHEN** an IFF/ILBM file has no ANNO, AUTH, `(c) `, or NAME chunks
- **THEN** the corresponding text fields in `IFFMetadata` are nil

#### Scenario: Parse file with missing BODY
- **WHEN** an IFF/ILBM file has a valid BMHD but no BODY chunk
- **THEN** `parseMetadata` still succeeds (BODY is not required for metadata extraction)

### Requirement: Spotlight Metadata Importer
The system SHALL include an mdimporter bundle that provides IFF/ILBM file metadata to Spotlight and Finder.

The importer SHALL populate these Spotlight attributes:
- `kMDItemPixelWidth` — image width
- `kMDItemPixelHeight` — image height
- `kMDItemBitsPerSample` — number of bitplanes
- `kMDItemColorSpace` — descriptive string: "Indexed", "EHB", "HAM6", "HAM8", "Direct 24-bit", or "Direct 32-bit"
- `kMDItemTitle` — from NAME chunk (if present)
- `kMDItemAuthors` — from AUTH chunk (if present)
- `kMDItemCopyright` — from `(c) ` chunk (if present)
- `kMDItemComment` — from ANNO chunk (if present)

#### Scenario: Finder shows image dimensions
- **WHEN** a user opens Get Info for a .iff file
- **THEN** the "More Info" section displays the image dimensions

#### Scenario: Spotlight indexes IFF metadata
- **WHEN** Spotlight indexes a .iff file
- **THEN** the file is searchable by its metadata attributes (author, title, dimensions)

#### Scenario: Importer handles corrupt files gracefully
- **WHEN** the mdimporter encounters an invalid or corrupt IFF file
- **THEN** it returns an error without crashing and the file gets a generic metadata entry
