import Cocoa
import QuickLookUI

class PreviewViewController: NSViewController, QLPreviewingController {

    private var imageView: NSImageView!

    override func loadView() {
        let view = NSView()
        view.wantsLayer = true

        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        self.view = view
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let data = try Data(contentsOf: url)
        let cgImage = try ILBMParser.parse(data: data)

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Compute a display size that fits within the Quick Look panel
        let displaySize = fittedSize(imageWidth: imageWidth, imageHeight: imageHeight)

        // Key: set the rep's point size to the display size.
        // This tells AppKit to render the full pixel data scaled into this point rect.
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = displaySize

        let nsImage = NSImage(size: displaySize)
        nsImage.addRepresentation(rep)

        await MainActor.run {
            imageView.image = nsImage
            preferredContentSize = displaySize
        }
    }

    private func fittedSize(imageWidth: CGFloat, imageHeight: CGFloat) -> NSSize {
        let maxW: CGFloat = 1200
        let maxH: CGFloat = 900

        let aspect = imageWidth / imageHeight
        var w = min(imageWidth, maxW)
        var h = w / aspect
        if h > maxH {
            h = maxH
            w = h * aspect
        }

        return NSSize(width: round(max(w, 200)), height: round(max(h, 200)))
    }
}
