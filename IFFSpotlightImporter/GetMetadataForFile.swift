import Foundation
import CoreServices

@_cdecl("GetMetadataForFile")
public func getMetadataForFile(
    _ thisInterface: UnsafeMutableRawPointer?,
    _ attributes: CFMutableDictionary,
    _ contentTypeUTI: CFString,
    _ pathToFile: CFString
) -> DarwinBoolean {
    let path = pathToFile as String
    let url = URL(fileURLWithPath: path)

    guard let data = try? Data(contentsOf: url),
          let metadata = try? ILBMParser.parseMetadata(data: data) else {
        return false
    }

    let dict = attributes as NSMutableDictionary
    dict[kMDItemPixelWidth as String] = Int(metadata.width)
    dict[kMDItemPixelHeight as String] = Int(metadata.height)
    dict[kMDItemBitsPerSample as String] = Int(metadata.numPlanes)
    dict[kMDItemColorSpace as String] = metadata.colorMode

    if let name = metadata.name {
        dict[kMDItemTitle as String] = name
    }
    if let author = metadata.author {
        dict[kMDItemAuthors as String] = [author]
    }
    if let copyright = metadata.copyright {
        dict[kMDItemCopyright as String] = copyright
    }
    if let annotation = metadata.annotation {
        dict[kMDItemComment as String] = annotation
    }

    return true
}
