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

/// Resolve full file path for a media name.
/// Handles backward compat for old Lottie entries stored without ".json" extension.
func resolveMediaPath(for name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    // Bundle: exact name (works when name includes extension)
    if let path = Bundle.main.path(forResource: trimmed, ofType: nil) {
        return path
    }
    // Bundle: try appending .json (backward compat for extensionless names like "eye_blink")
    if !trimmed.contains(".") {
        if let path = Bundle.main.path(forResource: trimmed, ofType: "json") {
            return path
        }
    }

    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let base = appSupport.appendingPathComponent("notech/lottie")

    // App Support: exact name
    let exact = base.appendingPathComponent(trimmed).path
    if FileManager.default.fileExists(atPath: exact) {
        return exact
    }
    // App Support: try .json (backward compat)
    if !trimmed.contains(".") {
        let withJson = base.appendingPathComponent(trimmed + ".json").path
        if FileManager.default.fileExists(atPath: withJson) {
            return withJson
        }
    }

    return nil
}

// MARK: - Lottie Resolution Helper

/// Resolve LottieAnimation from a media name (only if type is Lottie).
func resolveLottieFromMedia(name: String) -> LottieAnimation? {
    guard let path = resolveMediaPath(for: name) else { return nil }
    guard MediaType.detect(for: path) == .lottie else { return nil }
    return LottieAnimation.filepath(path)
}

// MARK: - Scaled Media Image View

/// Displays images with proper aspect ratio using SwiftUI Image for static images
/// and NSViewRepresentable only for animated GIFs.
struct ScaledMediaImage: View {
    let path: String
    let size: CGFloat
    var cornerRadius: CGFloat = 0

    @State private var nsImage: NSImage?

    private var isGif: Bool {
        (path as NSString).pathExtension.lowercased() == "gif"
    }

    var body: some View {
        Group {
            if let nsImage {
                if isGif {
                    GifImageViewRep(image: nsImage)
                } else {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear { nsImage = NSImage(contentsOf: URL(fileURLWithPath: path)) }
        .onChange(of: path) { _, _ in nsImage = NSImage(contentsOf: URL(fileURLWithPath: path)) }
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
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        if let tiffData = nsImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            let stem = (destName as NSString).deletingPathExtension
            let finalName = stem + ".png"
            let destURL = destDirectory.appendingPathComponent(finalName)
            try? fm.removeItem(at: destURL)
            try pngData.write(to: destURL)
            return finalName
        }
    }

    // Fallback: copy as-is
    return try copyAsIs(sourceURL: sourceURL, destDirectory: destDirectory, destName: destName)
}

private func copyAsIs(sourceURL: URL, destDirectory: URL, destName: String) throws -> String {
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
