import AppKit
import ImageIO

/// Picks colors from the part of the desktop picture that sits behind a window.
/// Pure functions only, so the geometry and color math are unit-testable.
enum WallpaperSampler {
    /// Colors for the top and bottom of a region, ready to use behind white text.
    struct Sample: Equatable, Sendable {
        var top: NSColor
        var bottom: NSColor

        /// One representative color for accents (the play button, settings tint).
        var accent: NSColor { top.blended(withFraction: 0.5, of: bottom) ?? top }
    }

    /// Whether Stint can read the picture without a privacy prompt. Pictures inside other
    /// apps' containers, or in Desktop / Documents / Downloads, are skipped; the panel's clear
    /// glass still shows the wallpaper itself in that case.
    static func canRead(_ url: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let path = url.standardizedFileURL.path
        let protected = ["Desktop", "Documents", "Downloads", "Library/Containers", "Library/Group Containers"]
            .map { home.appendingPathComponent($0).path + "/" }
        guard !protected.contains(where: path.hasPrefix) else { return false }
        return FileManager.default.isReadableFile(atPath: path)
    }

    /// A small decoded copy of the picture; sampling doesn't need full resolution.
    static func loadThumbnail(_ url: URL, maxPixelSize: Int = 512) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Maps a region in screen coordinates (origin bottom-left) to pixel coordinates in an
    /// image (origin top-left) that is aspect-filled onto the screen, as macOS draws wallpapers.
    static func imageRect(for region: CGRect, screenFrame: CGRect, imageSize: CGSize) -> CGRect {
        // Image pixels per screen point. Filling scales the picture until it covers the screen,
        // so the tighter of the two ratios applies and the other axis overflows.
        let scale = min(imageSize.width / screenFrame.width, imageSize.height / screenFrame.height)
        // The overflow is cropped equally on both sides.
        let cropX = (imageSize.width - screenFrame.width * scale) / 2
        let cropY = (imageSize.height - screenFrame.height * scale) / 2
        let local = region.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        let rect = CGRect(
            x: cropX + local.minX * scale,
            y: cropY + (screenFrame.height - local.maxY) * scale,
            width: local.width * scale,
            height: local.height * scale
        )
        return rect.intersection(CGRect(origin: .zero, size: imageSize))
    }

    /// Average color of `rect` (image pixel coordinates, origin top-left).
    static func averageColor(of image: CGImage, in rect: CGRect) -> NSColor? {
        guard !rect.isEmpty, let cropped = image.cropping(to: rect.integral) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        let drew = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drew else { return nil }
        return NSColor(srgbRed: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                       blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }

    /// Samples the top and bottom thirds of the region behind a window.
    static func sample(_ image: CGImage, region: CGRect, screenFrame: CGRect) -> Sample? {
        let size = CGSize(width: image.width, height: image.height)
        let rect = imageRect(for: region, screenFrame: screenFrame, imageSize: size)
        guard rect.height >= 3 else { return nil }
        let third = rect.height / 3
        let top = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: third)
        let bottom = CGRect(x: rect.minX, y: rect.maxY - third, width: rect.width, height: third)
        guard let topColor = averageColor(of: image, in: top),
              let bottomColor = averageColor(of: image, in: bottom) else { return nil }
        return Sample(top: readable(topColor), bottom: readable(bottomColor))
    }

    /// Keeps a sampled color's hue but makes it dark and colorful enough for white text,
    /// so a bright sky or a pale wall still gives a legible panel.
    static func readable(_ color: NSColor) -> NSColor {
        let c = color.usingColorSpace(.sRGB) ?? color
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        c.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let isGray = saturation < 0.08
        return NSColor(hue: hue,
                       saturation: isGray ? saturation : min(1, max(saturation * 1.15, 0.3)),
                       brightness: min(max(brightness, 0.22), 0.58),
                       alpha: 1)
    }
}
