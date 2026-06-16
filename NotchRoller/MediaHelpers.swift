import SwiftUI
import Lottie

// MARK: - Media Type Detection

enum MediaType {
    case lottie
    case image  // static or animated GIF
    case none

    static func detect(for filename: String) -> MediaType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "json": return .lottie
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "bmp", "tiff": return .image
        default: return .none
        }
    }
}

// MARK: - Media Path Resolution

/// Resolve full file URL for a media name.
/// Handles backward compat for old Lottie entries stored without ".json" extension.
func resolveMediaPath(for name: String) -> URL? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    // Bundle: exact name (works when name includes extension)
    if let url = Bundle.main.url(forResource: trimmed, withExtension: nil) {
        return url
    }
    // Bundle: try appending .json (backward compat for extensionless names like "eye_blink")
    if !trimmed.contains(".") {
        if let url = Bundle.main.url(forResource: trimmed, withExtension: "json") {
            return url
        }
    }

    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let base = appSupport.appendingPathComponent("notech/lottie")

    // App Support: exact name
    let exact = base.appendingPathComponent(trimmed)
    if FileManager.default.fileExists(atPath: exact.path) {
        return exact
    }
    // App Support: try .json (backward compat)
    if !trimmed.contains(".") {
        let withJson = base.appendingPathComponent(trimmed + ".json")
        if FileManager.default.fileExists(atPath: withJson.path) {
            return withJson
        }
    }

    return nil
}

// MARK: - Lottie Resolution Helper

/// Resolve LottieAnimation from a media name (only if type is Lottie).
func resolveLottieFromMedia(name: String) -> LottieAnimation? {
    guard let url = resolveMediaPath(for: name) else { return nil }
    guard MediaType.detect(for: url.path) == .lottie else { return nil }
    return LottieAnimation.filepath(url.path)
}

// MARK: - Scaled Media Image View

/// Displays images with proper aspect ratio using SwiftUI Image for static images
/// and NSViewRepresentable only for animated GIFs.
struct ScaledMediaImage: View {
    let url: URL
    var size: CGFloat? = nil
    var cornerRadius: CGFloat = 0

    @State private var nsImage: NSImage?

    private var isGif: Bool {
        url.pathExtension.lowercased() == "gif"
    }

    var body: some View {
        Group {
            if let nsImage {
                if isGif {
                    GifImageViewRep(image: nsImage)
                } else {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Color.clear
            }
        }
        // Fixed size mode (SettingsView)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear { nsImage = NSImage(contentsOf: url) }
        .onChange(of: url) { _ in nsImage = NSImage(contentsOf: url) }
    }
}

/// NSViewRepresentable for animated GIF playback only.
private struct GifImageViewRep: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.animates = true
        return iv
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = image
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return nil }
        let pw = proposal.width ?? imgSize.width
        let ph = proposal.height ?? imgSize.height
        let w = min(pw, imgSize.width)
        let h = min(ph, imgSize.height)
        let scale = min(w / imgSize.width, h / imgSize.height)
        return CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
    }
}

// MARK: - Thumbnail Generation

/// Copy a media file to the destination directory, generating a compressed thumbnail
/// for static images. Lottie JSON and animated GIFs are copied as-is.
/// Uses CGImageSource for efficient downsampling without loading the full image.
func copyMediaWithThumbnail(
    sourceURL: URL,
    destDirectory: URL,
    destName: String,
    maxDimension: CGFloat = 256
) throws -> String {
    let fm = FileManager.default
    let ext = sourceURL.pathExtension.lowercased()
    let type = MediaType.detect(for: sourceURL.lastPathComponent)

    // Lottie or unknown: copy as-is
    guard type == .image else {
        return try copyAsIs(sourceURL: sourceURL, destDirectory: destDirectory, destName: destName)
    }

    // GIF: copy as-is (resizing animated frames is complex)
    guard ext != "gif" else {
        return try copyAsIs(sourceURL: sourceURL, destDirectory: destDirectory, destName: destName)
    }

    // Static image: try CGImageSource for efficient thumbnail
    if let cgImage = createThumbnailCGImage(url: sourceURL, maxDimension: maxDimension) {
        let stem = (destName as NSString).deletingPathExtension
        let finalName = stem + ".png"
        let destURL = destDirectory.appendingPathComponent(finalName)
        try? fm.removeItem(at: destURL)

        guard let dest = CGImageDestinationCreateWithURL(destURL as CFURL, "public.png" as CFString, 1, nil) else {
            return try copyAsIs(sourceURL: sourceURL, destDirectory: destDirectory, destName: destName)
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        if CGImageDestinationFinalize(dest) {
            return finalName
        }
    }

    // Fallback: copy as-is
    return try copyAsIs(sourceURL: sourceURL, destDirectory: destDirectory, destName: destName)
}

func copyAsIs(sourceURL: URL, destDirectory: URL, destName: String) throws -> String {
    let dest = destDirectory.appendingPathComponent(destName)
    try? FileManager.default.removeItem(at: dest)
    try FileManager.default.copyItem(at: sourceURL, to: dest)
    return destName
}

/// Efficient thumbnail creation using CGImageSource (avoids loading full image into memory).
private func createThumbnailCGImage(url: URL, maxDimension: CGFloat) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

    // Check original size
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
          let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat,
          let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat else { return nil }

    // Already small enough — no thumbnail needed
    if width <= maxDimension && height <= maxDimension { return nil }

    let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
        kCGImageSourceCreateThumbnailFromImageAlways: true
    ]

    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}
