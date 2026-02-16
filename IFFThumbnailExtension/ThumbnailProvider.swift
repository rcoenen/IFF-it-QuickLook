import QuickLookThumbnailing
import AppKit
import os.log

private let logger = Logger(subsystem: "com.iffit.IFFQuickLook.IFFThumbnailExtension", category: "thumbnail")

class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(for request: QLFileThumbnailRequest,
                                   _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        logger.info("provideThumbnail called for \(request.fileURL.path)")

        do {
            let data = try Data(contentsOf: request.fileURL)
            logger.info("Read \(data.count) bytes")

            let cgImage = try ILBMParser.parse(data: data)
            logger.info("Parsed image: \(cgImage.width)x\(cgImage.height)")

            let imgW = CGFloat(cgImage.width)
            let imgH = CGFloat(cgImage.height)
            let aspect = imgW / imgH

            let maxW = request.maximumSize.width
            let maxH = request.maximumSize.height

            var thumbW: CGFloat
            var thumbH: CGFloat
            if aspect >= 1.0 {
                thumbW = min(maxW, imgW)
                thumbH = thumbW / aspect
                if thumbH > maxH {
                    thumbH = maxH
                    thumbW = thumbH * aspect
                }
            } else {
                thumbH = min(maxH, imgH)
                thumbW = thumbH * aspect
                if thumbW > maxW {
                    thumbW = maxW
                    thumbH = thumbW / aspect
                }
            }
            thumbW = max(1, round(thumbW))
            thumbH = max(1, round(thumbH))

            let contextSize = CGSize(width: thumbW, height: thumbH)
            logger.info("Thumbnail size: \(thumbW)x\(thumbH)")

            let reply = QLThumbnailReply(contextSize: contextSize, currentContextDrawing: { () -> Bool in
                guard let ctx = NSGraphicsContext.current?.cgContext else {
                    logger.error("No current CGContext")
                    return false
                }
                ctx.draw(cgImage, in: CGRect(origin: .zero, size: contextSize))
                logger.info("Drew thumbnail successfully")
                return true
            })

            handler(reply, nil)
        } catch {
            logger.error("Error: \(error.localizedDescription)")
            handler(nil, error)
        }
    }
}
