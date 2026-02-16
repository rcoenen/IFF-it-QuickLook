import Foundation
import CoreGraphics
import ImageIO

// MARK: - IFF/ILBM Parser

/// Parses IFF ILBM (Interleaved Bitmap) image files into CGImage.
/// Supports: standard indexed color, EHB (Extra Half-Brite), HAM6, HAM8, and 24-bit direct color.
/// Compression: uncompressed and ByteRun1 (PackBits).
enum ILBMParser {

    // MARK: - Errors

    enum ParseError: Error, LocalizedError {
        case invalidData
        case notILBMForm
        case missingBMHD
        case missingBODY
        case unsupportedCompression(UInt8)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidData: return "Invalid or corrupt IFF data"
            case .notILBMForm: return "Not an IFF ILBM file"
            case .missingBMHD: return "Missing BMHD chunk"
            case .missingBODY: return "Missing BODY chunk"
            case .unsupportedCompression(let c): return "Unsupported compression type: \(c)"
            case .decodingFailed: return "Failed to decode image data"
            }
        }
    }

    // MARK: - Structures

    struct BitmapHeader {
        let width: UInt16
        let height: UInt16
        let xOrigin: Int16
        let yOrigin: Int16
        let numPlanes: UInt8
        let masking: UInt8
        let compression: UInt8
        let transparentColor: UInt16
        let xAspect: UInt8
        let yAspect: UInt8
        let pageWidth: Int16
        let pageHeight: Int16
    }

    // Amiga viewport mode flags
    struct CAMGFlags {
        static let ham: UInt32  = 0x0800
        static let ehb: UInt32  = 0x0080
    }

    // MARK: - Metadata

    struct IFFMetadata {
        let width: UInt16
        let height: UInt16
        let numPlanes: UInt8
        let compression: UInt8
        let camgFlags: UInt32
        let paletteColorCount: Int
        let xAspect: UInt8
        let yAspect: UInt8
        let name: String?
        let author: String?
        let copyright: String?
        let annotation: String?

        var colorMode: String {
            if numPlanes == 32 { return "Direct 32-bit" }
            if numPlanes == 24 { return "Direct 24-bit" }
            if camgFlags & CAMGFlags.ham != 0 {
                return numPlanes <= 6 ? "HAM6" : "HAM8"
            }
            if camgFlags & CAMGFlags.ehb != 0 { return "EHB" }
            return "Indexed"
        }
    }

    static func parseMetadata(data: Data) throws -> IFFMetadata {
        guard data.count >= 12 else { throw ParseError.invalidData }

        let formTag = readTag(data, offset: 0)
        guard formTag == "FORM" else { throw ParseError.notILBMForm }

        let typeTag = readTag(data, offset: 8)
        guard typeTag == "ILBM" || typeTag == "PBM " else { throw ParseError.notILBMForm }

        var bmhd: BitmapHeader?
        var cmapCount = 0
        var camg: UInt32 = 0
        var name: String?
        var author: String?
        var copyright: String?
        var annotation: String?

        var offset = 12
        while offset + 8 <= data.count {
            let tag = readTag(data, offset: offset)
            let size = Int(readUInt32(data, offset: offset + 4))
            let chunkStart = offset + 8

            guard chunkStart + size <= data.count else { break }

            switch tag {
            case "BMHD":
                bmhd = parseBMHD(data, offset: chunkStart)
            case "CMAP":
                cmapCount = size / 3
            case "CAMG":
                if size >= 4 { camg = readUInt32(data, offset: chunkStart) }
            case "NAME":
                name = readString(data, offset: chunkStart, size: size)
            case "AUTH":
                author = readString(data, offset: chunkStart, size: size)
            case "(c) ":
                copyright = readString(data, offset: chunkStart, size: size)
            case "ANNO":
                annotation = readString(data, offset: chunkStart, size: size)
            default:
                break
            }

            offset = chunkStart + size + (size & 1)
        }

        guard let header = bmhd else { throw ParseError.missingBMHD }

        return IFFMetadata(
            width: header.width,
            height: header.height,
            numPlanes: header.numPlanes,
            compression: header.compression,
            camgFlags: camg,
            paletteColorCount: cmapCount,
            xAspect: header.xAspect,
            yAspect: header.yAspect,
            name: name,
            author: author,
            copyright: copyright,
            annotation: annotation
        )
    }

    // MARK: - Public API

    static func parse(data: Data) throws -> CGImage {
        guard data.count >= 12 else { throw ParseError.invalidData }

        let formTag = readTag(data, offset: 0)
        guard formTag == "FORM" else { throw ParseError.notILBMForm }

        let typeTag = readTag(data, offset: 8)
        guard typeTag == "ILBM" || typeTag == "PBM " else { throw ParseError.notILBMForm }

        let isPBM = (typeTag == "PBM ")

        var bmhd: BitmapHeader?
        var cmap: [UInt8]?
        var camg: UInt32 = 0
        var bodyOffset = 0
        var bodySize = 0

        // Parse chunks — just record BODY offset, don't copy it
        var offset = 12
        while offset + 8 <= data.count {
            let tag = readTag(data, offset: offset)
            let size = Int(readUInt32(data, offset: offset + 4))
            let chunkStart = offset + 8

            guard chunkStart + size <= data.count else { break }

            switch tag {
            case "BMHD":
                bmhd = parseBMHD(data, offset: chunkStart)
            case "CMAP":
                cmap = Array(data[chunkStart..<chunkStart + size])
            case "CAMG":
                if size >= 4 {
                    camg = readUInt32(data, offset: chunkStart)
                }
            case "BODY":
                bodyOffset = chunkStart
                bodySize = size
            default:
                break
            }

            offset = chunkStart + size + (size & 1)
        }

        guard let header = bmhd else { throw ParseError.missingBMHD }
        guard bodySize > 0 else { throw ParseError.missingBODY }

        let palette = buildPalette(cmap: cmap, camg: camg, numPlanes: header.numPlanes)

        let width = Int(header.width)
        let height = Int(header.height)
        let numPlanes = Int(header.numPlanes)

        // Work directly with Data's underlying buffer — zero copy for uncompressed
        let pixels: [UInt8]

        if header.compression == 1 {
            // ByteRun1: must decompress into new buffer
            let bodySlice = data[bodyOffset..<bodyOffset + bodySize]
            let decompressed = decompressByteRun1(bodySlice)
            pixels = decompressed.withUnsafeBufferPointer { buf in
                decodeBody(buf: buf, isPBM: isPBM, width: width, height: height,
                          numPlanes: numPlanes, camg: camg, palette: palette, hasMask: header.masking == 1)
            }
        } else if header.compression == 0 {
            // Uncompressed: access Data bytes directly, no copy
            pixels = data.withUnsafeBytes { rawBuf in
                let basePtr = rawBuf.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let buf = UnsafeBufferPointer(start: basePtr + bodyOffset, count: bodySize)
                return decodeBody(buf: buf, isPBM: isPBM, width: width, height: height,
                                 numPlanes: numPlanes, camg: camg, palette: palette, hasMask: header.masking == 1)
            }
        } else {
            throw ParseError.unsupportedCompression(header.compression)
        }

        return try createCGImage(pixels: pixels, width: width, height: height)
    }

    // MARK: - Unified Decoder Dispatch

    private static func decodeBody(
        buf: UnsafeBufferPointer<UInt8>,
        isPBM: Bool, width: Int, height: Int, numPlanes: Int,
        camg: UInt32, palette: [(r: UInt8, g: UInt8, b: UInt8)], hasMask: Bool
    ) -> [UInt8] {
        if isPBM {
            return decodePBM(buf, width: width, height: height, palette: palette)
        } else if numPlanes == 24 {
            return decode24Bit(buf, width: width, height: height)
        } else if numPlanes == 32 {
            return decode32Bit(buf, width: width, height: height)
        } else if camg & CAMGFlags.ham != 0 {
            return decodeHAM(buf, width: width, height: height, numPlanes: numPlanes, palette: palette)
        } else {
            return decodeIndexed(buf, width: width, height: height, numPlanes: numPlanes, palette: palette, hasMask: hasMask)
        }
    }

    // MARK: - Chunk Readers

    private static func readTag(_ data: Data, offset: Int) -> String {
        let bytes = data[offset..<offset+4]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        return UInt32(data[offset]) << 24
             | UInt32(data[offset+1]) << 16
             | UInt32(data[offset+2]) << 8
             | UInt32(data[offset+3])
    }

    private static func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        return UInt16(data[offset]) << 8 | UInt16(data[offset+1])
    }

    private static func readInt16(_ data: Data, offset: Int) -> Int16 {
        return Int16(bitPattern: readUInt16(data, offset: offset))
    }

    private static func readString(_ data: Data, offset: Int, size: Int) -> String? {
        guard size > 0 else { return nil }
        let bytes = data[offset..<offset + size]
        // Trim trailing nulls
        let trimmed = bytes.prefix(while: { $0 != 0 })
        return String(bytes: trimmed, encoding: .isoLatin1)
    }

    private static func parseBMHD(_ data: Data, offset: Int) -> BitmapHeader {
        return BitmapHeader(
            width: readUInt16(data, offset: offset),
            height: readUInt16(data, offset: offset + 2),
            xOrigin: readInt16(data, offset: offset + 4),
            yOrigin: readInt16(data, offset: offset + 6),
            numPlanes: data[offset + 8],
            masking: data[offset + 9],
            compression: data[offset + 10],
            transparentColor: readUInt16(data, offset: offset + 12),
            xAspect: data[offset + 14],
            yAspect: data[offset + 15],
            pageWidth: readInt16(data, offset: offset + 16),
            pageHeight: readInt16(data, offset: offset + 18)
        )
    }

    // MARK: - Palette

    private static func buildPalette(cmap: [UInt8]?, camg: UInt32, numPlanes: UInt8) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []

        if let cmap = cmap {
            let count = cmap.count / 3
            for i in 0..<count {
                palette.append((cmap[i*3], cmap[i*3+1], cmap[i*3+2]))
            }
        }

        let expected = 1 << min(Int(numPlanes), 8)
        while palette.count < expected {
            palette.append((0, 0, 0))
        }

        if camg & CAMGFlags.ehb != 0 && numPlanes == 6 {
            let base = Array(palette.prefix(32))
            while palette.count < 64 {
                let i = palette.count - 32
                palette.append(i < base.count ? (base[i].r >> 1, base[i].g >> 1, base[i].b >> 1) : (0, 0, 0))
            }
        }

        return palette
    }

    // MARK: - ByteRun1 Decompression

    private static func decompressByteRun1(_ data: Data) -> [UInt8] {
        var result: [UInt8] = []
        result.reserveCapacity(data.count * 2)
        var i = data.startIndex

        while i < data.endIndex {
            let n = Int8(bitPattern: data[i])
            i += 1

            if n >= 0 {
                let count = Int(n) + 1
                let end = min(i + count, data.endIndex)
                result.append(contentsOf: data[i..<end])
                i = end
            } else if n != -128 {
                let count = Int(-n) + 1
                guard i < data.endIndex else { break }
                let byte = data[i]
                i += 1
                for _ in 0..<count {
                    result.append(byte)
                }
            }
        }

        return result
    }

    // MARK: - Decode Indexed (Interleaved Bitplanes)

    private static func decodeIndexed(
        _ buf: UnsafeBufferPointer<UInt8>,
        width: Int, height: Int, numPlanes: Int,
        palette: [(r: UInt8, g: UInt8, b: UInt8)],
        hasMask: Bool
    ) -> [UInt8] {
        let bytesPerRow = ((width + 15) / 16) * 2
        let totalPlanes = numPlanes + (hasMask ? 1 : 0)
        let rowBytes = bytesPerRow * totalPlanes
        let bufCount = buf.count

        var indices = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            let rowStart = y * rowBytes
            let pixelRow = y * width

            for plane in 0..<numPlanes {
                let planeStart = rowStart + plane * bytesPerRow
                let planeBit = UInt8(1 << plane)

                for byteIdx in 0..<bytesPerRow {
                    let offset = planeStart + byteIdx
                    guard offset < bufCount else { continue }
                    let byte = buf[offset]
                    guard byte != 0 else { continue }

                    let baseX = byteIdx * 8
                    if byte & 0x80 != 0 { let x = baseX;     if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x40 != 0 { let x = baseX + 1; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x20 != 0 { let x = baseX + 2; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x10 != 0 { let x = baseX + 3; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x08 != 0 { let x = baseX + 4; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x04 != 0 { let x = baseX + 5; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x02 != 0 { let x = baseX + 6; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x01 != 0 { let x = baseX + 7; if x < width { indices[pixelRow + x] |= planeBit } }
                }
            }
        }

        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let paletteCount = palette.count

        for i in 0..<(width * height) {
            let ci = Int(indices[i])
            let pi = i * 4
            if ci < paletteCount {
                pixels[pi]     = palette[ci].r
                pixels[pi + 1] = palette[ci].g
                pixels[pi + 2] = palette[ci].b
            }
        }

        return pixels
    }

    // MARK: - Fast Bitplane Extraction (shared helper for HAM)

    private static func extractBitplanes(
        _ buf: UnsafeBufferPointer<UInt8>, width: Int, height: Int,
        numPlanes: Int, bytesPerRow: Int, rowBytes: Int
    ) -> [UInt16] {
        var indices = [UInt16](repeating: 0, count: width * height)
        let bufCount = buf.count

        for y in 0..<height {
            let rowStart = y * rowBytes
            let pixelRow = y * width

            for plane in 0..<numPlanes {
                let planeStart = rowStart + plane * bytesPerRow
                let planeBit = UInt16(1 << plane)

                for byteIdx in 0..<bytesPerRow {
                    let offset = planeStart + byteIdx
                    guard offset < bufCount else { continue }
                    let byte = buf[offset]
                    guard byte != 0 else { continue }

                    let baseX = byteIdx * 8
                    if byte & 0x80 != 0 { let x = baseX;     if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x40 != 0 { let x = baseX + 1; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x20 != 0 { let x = baseX + 2; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x10 != 0 { let x = baseX + 3; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x08 != 0 { let x = baseX + 4; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x04 != 0 { let x = baseX + 5; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x02 != 0 { let x = baseX + 6; if x < width { indices[pixelRow + x] |= planeBit } }
                    if byte & 0x01 != 0 { let x = baseX + 7; if x < width { indices[pixelRow + x] |= planeBit } }
                }
            }
        }
        return indices
    }

    // MARK: - Decode HAM (Hold And Modify)

    private static func decodeHAM(
        _ buf: UnsafeBufferPointer<UInt8>,
        width: Int, height: Int, numPlanes: Int,
        palette: [(r: UInt8, g: UInt8, b: UInt8)]
    ) -> [UInt8] {
        let bytesPerRow = ((width + 15) / 16) * 2
        let colorPlanes = numPlanes < 7 ? 4 : 6
        let rowBytes = bytesPerRow * numPlanes
        let shift = 8 - colorPlanes
        let colorMask = UInt16((1 << colorPlanes) - 1)
        let modShift = colorPlanes

        let indices = extractBitplanes(buf, width: width, height: height,
                                       numPlanes: numPlanes, bytesPerRow: bytesPerRow, rowBytes: rowBytes)

        var pixels = [UInt8](repeating: 255, count: width * height * 4)

        for y in 0..<height {
            let pixelRow = y * width
            var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0

            for x in 0..<width {
                let value = indices[pixelRow + x]
                let colorValue = Int(value & colorMask)
                let modifier = Int(value >> modShift)

                switch modifier {
                case 0:
                    if colorValue < palette.count {
                        r = palette[colorValue].r
                        g = palette[colorValue].g
                        b = palette[colorValue].b
                    }
                case 1: b = UInt8(colorValue << shift)
                case 2: r = UInt8(colorValue << shift)
                case 3: g = UInt8(colorValue << shift)
                default: break
                }

                let pi = (pixelRow + x) * 4
                pixels[pi]     = r
                pixels[pi + 1] = g
                pixels[pi + 2] = b
            }
        }

        return pixels
    }

    // MARK: - Decode 24-bit Direct Color

    private static func decode24Bit(_ buf: UnsafeBufferPointer<UInt8>, width: Int, height: Int) -> [UInt8] {
        let bytesPerRow = ((width + 15) / 16) * 2
        let rowBytes = bytesPerRow * 24
        let bufCount = buf.count

        var pixels = [UInt8](repeating: 255, count: width * height * 4)

        for y in 0..<height {
            let rowStart = y * rowBytes
            let pixelRow = y * width

            for byteIdx in 0..<bytesPerRow {
                let baseX = byteIdx * 8
                var channelBytes = (
                    UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),
                    UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),
                    UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0),UInt8(0)
                )
                withUnsafeMutableBytes(of: &channelBytes) { ptr in
                    let cb = ptr.bindMemory(to: UInt8.self)
                    for plane in 0..<24 {
                        let offset = rowStart + plane * bytesPerRow + byteIdx
                        if offset < bufCount { cb[plane] = buf[offset] }
                    }
                }

                withUnsafeBytes(of: &channelBytes) { ptr in
                    let cb = ptr.bindMemory(to: UInt8.self)
                    for bit in 0..<8 {
                        let x = baseX + bit
                        guard x < width else { return }
                        let mask = UInt8(0x80 >> bit)

                        var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0
                        for plane in 0..<8 {
                            if cb[plane] & mask != 0 { r |= UInt8(1 << plane) }
                            if cb[plane + 8] & mask != 0 { g |= UInt8(1 << plane) }
                            if cb[plane + 16] & mask != 0 { b |= UInt8(1 << plane) }
                        }

                        let pi = (pixelRow + x) * 4
                        pixels[pi] = r; pixels[pi+1] = g; pixels[pi+2] = b
                    }
                }
            }
        }

        return pixels
    }

    // MARK: - Decode 32-bit (24-bit + alpha)

    private static func decode32Bit(_ buf: UnsafeBufferPointer<UInt8>, width: Int, height: Int) -> [UInt8] {
        let bytesPerRow = ((width + 15) / 16) * 2
        let rowBytes = bytesPerRow * 32
        let bufCount = buf.count

        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            let rowStart = y * rowBytes
            let pixelRow = y * width

            for byteIdx in 0..<bytesPerRow {
                let baseX = byteIdx * 8
                var channelBytes = [UInt8](repeating: 0, count: 32)
                for plane in 0..<32 {
                    let offset = rowStart + plane * bytesPerRow + byteIdx
                    if offset < bufCount { channelBytes[plane] = buf[offset] }
                }

                for bit in 0..<8 {
                    let x = baseX + bit
                    guard x < width else { break }
                    let mask = UInt8(0x80 >> bit)

                    var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0, a: UInt8 = 0
                    for plane in 0..<8 {
                        if channelBytes[plane] & mask != 0 { r |= UInt8(1 << plane) }
                        if channelBytes[plane + 8] & mask != 0 { g |= UInt8(1 << plane) }
                        if channelBytes[plane + 16] & mask != 0 { b |= UInt8(1 << plane) }
                        if channelBytes[plane + 24] & mask != 0 { a |= UInt8(1 << plane) }
                    }

                    let pi = (pixelRow + x) * 4
                    pixels[pi] = r; pixels[pi+1] = g; pixels[pi+2] = b; pixels[pi+3] = a
                }
            }
        }

        return pixels
    }

    // MARK: - Decode PBM (Planar Bitmap - chunky)

    private static func decodePBM(
        _ buf: UnsafeBufferPointer<UInt8>,
        width: Int, height: Int,
        palette: [(r: UInt8, g: UInt8, b: UInt8)]
    ) -> [UInt8] {
        let rowBytes = ((width + 1) / 2) * 2
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * rowBytes + x
                guard offset < buf.count else { continue }
                let colorIndex = Int(buf[offset])

                let pi = (y * width + x) * 4
                if colorIndex < palette.count {
                    pixels[pi]     = palette[colorIndex].r
                    pixels[pi + 1] = palette[colorIndex].g
                    pixels[pi + 2] = palette[colorIndex].b
                    pixels[pi + 3] = 255
                }
            }
        }

        return pixels
    }

    // MARK: - CGImage Creation

    private static func createCGImage(pixels: [UInt8], width: Int, height: Int) throws -> CGImage {
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw ParseError.decodingFailed
        }

        return cgImage
    }
}
