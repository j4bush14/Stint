import AppKit
import Testing
@testable import Stint

@Suite("Wallpaper sampling")
struct WallpaperSamplerTests {
    /// A test picture: the top half one color, the bottom half another.
    private func twoToneImage(width: Int, height: Int, top: NSColor, bottom: NSColor) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // CoreGraphics' origin is bottom-left, so the "top" half is the upper y range.
        context.setFillColor(bottom.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        context.setFillColor(top.cgColor)
        context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
        return context.makeImage()!
    }

    private func components(_ color: NSColor) -> (Int, Int, Int) {
        let c = color.usingColorSpace(.sRGB)!
        return (Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()),
                Int((c.blueComponent * 255).rounded()))
    }

    @Test("A picture with the screen's shape maps one to one, flipping y")
    func sameAspect() {
        let rect = WallpaperSampler.imageRect(
            for: CGRect(x: 10, y: 60, width: 20, height: 30),
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 200)
        )
        #expect(rect == CGRect(x: 20, y: 20, width: 40, height: 60))
    }

    @Test("A wider picture is cropped equally on the left and right")
    func widerPicture() {
        let rect = WallpaperSampler.imageRect(
            for: CGRect(x: 0, y: 0, width: 100, height: 100),
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100)
        )
        #expect(rect == CGRect(x: 50, y: 0, width: 100, height: 100))
    }

    @Test("Regions on a second display are relative to that display")
    func secondDisplay() {
        let rect = WallpaperSampler.imageRect(
            for: CGRect(x: 1500, y: 0, width: 100, height: 100),
            screenFrame: CGRect(x: 1500, y: 0, width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100)
        )
        #expect(rect == CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    @Test("Averages the color of a region")
    func average() throws {
        let image = twoToneImage(width: 40, height: 40, top: .red, bottom: .blue)
        let top = try #require(WallpaperSampler.averageColor(of: image, in: CGRect(x: 0, y: 0, width: 40, height: 10)))
        let bottom = try #require(WallpaperSampler.averageColor(of: image, in: CGRect(x: 0, y: 30, width: 40, height: 10)))
        #expect(components(top) == (255, 0, 0))
        #expect(components(bottom) == (0, 0, 255))
    }

    @Test("Samples the top and bottom of the region behind a window")
    func sampleBehindWindow() throws {
        let image = twoToneImage(width: 100, height: 100, top: .systemRed, bottom: .systemBlue)
        let sample = try #require(WallpaperSampler.sample(
            image, region: CGRect(x: 0, y: 0, width: 100, height: 100),
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100)
        ))
        let (r1, _, b1) = components(sample.top)
        let (r2, _, b2) = components(sample.bottom)
        #expect(r1 > b1, "top should be reddish")
        #expect(b2 > r2, "bottom should be bluish")
    }

    @Test("Readable colors keep their hue but are dark enough for white text",
          arguments: [NSColor.white, .yellow, NSColor(srgbRed: 0.9, green: 0.95, blue: 1, alpha: 1), .black, .systemTeal])
    func readable(color: NSColor) {
        let result = WallpaperSampler.readable(color).usingColorSpace(.sRGB)!
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        result.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #expect(b <= 0.58)
        #expect(b >= 0.22)
    }

    @Test("Skips pictures that would trigger a privacy prompt")
    func privacy() {
        let home = URL(fileURLWithPath: "/Users/someone")
        let blocked = ["Library/Containers/com.example/Data/a.jpg", "Desktop/a.jpg", "Downloads/b.heic", "Documents/c.png"]
        for path in blocked {
            #expect(!WallpaperSampler.canRead(home.appendingPathComponent(path), home: home), "\(path)")
        }
    }

    @Test("Reads system wallpapers")
    func systemPictures() throws {
        let pictures = try FileManager.default.contentsOfDirectory(atPath: "/System/Library/Desktop Pictures")
        let image = try #require(pictures.first { $0.hasSuffix(".heic") || $0.hasSuffix(".jpg") || $0.hasSuffix(".png") },
                                 "no system wallpaper image on this Mac")
        let url = URL(fileURLWithPath: "/System/Library/Desktop Pictures").appendingPathComponent(image)
        #expect(WallpaperSampler.canRead(url))
        #expect(WallpaperSampler.loadThumbnail(url) != nil)
    }
}
