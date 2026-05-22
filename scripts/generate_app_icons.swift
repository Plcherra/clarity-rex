import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func writePNG(_ png: Data, to url: URL) throws {
    try ensureDirectory(url.deletingLastPathComponent())
    try png.write(to: url)
}

func pngData(size: Int, includeBackground: Bool = true) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap"])
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawDiamond(in: NSRect(x: 0, y: 0, width: size, height: size), includeBackground: includeBackground)
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    return png
}

func drawDiamond(in bounds: NSRect, includeBackground: Bool) {
    if includeBackground {
        let background = NSGradient(colors: [
            color(5, 10, 22),
            color(10, 22, 32),
            color(8, 14, 24),
        ])!
        background.draw(in: bounds, angle: -42)

        color(255, 255, 255, 0.035).setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: bounds.width * 0.22, dy: bounds.height * 0.22)).fill()
    } else {
        NSColor.clear.setFill()
        bounds.fill()
    }

    let side = bounds.width * 0.68
    let cornerRadius = side * 0.095
    let rect = NSRect(x: -side / 2, y: -side / 2, width: side, height: side)
    let diamond = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    var transform = AffineTransform()
    transform.translate(x: bounds.midX, y: bounds.midY)
    transform.rotate(byDegrees: 45)
    diamond.transform(using: transform)

    let shadow = NSShadow()
    shadow.shadowColor = color(0, 0, 0, includeBackground ? 0.44 : 0.20)
    shadow.shadowBlurRadius = bounds.width * 0.055
    shadow.shadowOffset = NSSize(width: 0, height: -bounds.height * 0.018)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    color(0, 0, 0, 0.20).setFill()
    diamond.fill()
    NSGraphicsContext.restoreGraphicsState()

    let face = NSGradient(colorsAndLocations:
        (color(21, 24, 86), 0.0),
        (color(9, 58, 82), 0.36),
        (color(18, 124, 119), 0.68),
        (color(56, 173, 131), 1.0)
    )!
    face.draw(in: diamond, angle: -90)

    color(255, 255, 255, 0.055).setStroke()
    diamond.lineWidth = max(1, bounds.width * 0.002)
    diamond.stroke()
}

func png(_ size: Int, _ relativePath: String, includeBackground: Bool = true) throws {
    let data = try pngData(size: size, includeBackground: includeBackground)
    try writePNG(data, to: root.appendingPathComponent(relativePath))
}

try png(1024, "apps/mobile/assets/brand/clarity_mark.png", includeBackground: false)
try png(1024, "apps/mobile/assets/brand/clarity_app_icon.png")

let iosIcons: [(Int, String)] = [
    (20, "Icon-App-20x20@1x.png"),
    (40, "Icon-App-20x20@2x.png"),
    (60, "Icon-App-20x20@3x.png"),
    (29, "Icon-App-29x29@1x.png"),
    (58, "Icon-App-29x29@2x.png"),
    (87, "Icon-App-29x29@3x.png"),
    (40, "Icon-App-40x40@1x.png"),
    (80, "Icon-App-40x40@2x.png"),
    (120, "Icon-App-40x40@3x.png"),
    (120, "Icon-App-60x60@2x.png"),
    (180, "Icon-App-60x60@3x.png"),
    (76, "Icon-App-76x76@1x.png"),
    (152, "Icon-App-76x76@2x.png"),
    (167, "Icon-App-83.5x83.5@2x.png"),
    (1024, "Icon-App-1024x1024@1x.png"),
]

for (size, file) in iosIcons {
    try png(size, "apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/\(file)")
}

let macIcons: [(Int, String)] = [
    (16, "app_icon_16.png"),
    (32, "app_icon_32.png"),
    (64, "app_icon_64.png"),
    (128, "app_icon_128.png"),
    (256, "app_icon_256.png"),
    (512, "app_icon_512.png"),
    (1024, "app_icon_1024.png"),
]

for (size, file) in macIcons {
    try png(size, "apps/mobile/macos/Runner/Assets.xcassets/AppIcon.appiconset/\(file)")
}

let androidIcons: [(Int, String)] = [
    (48, "mipmap-mdpi/ic_launcher.png"),
    (72, "mipmap-hdpi/ic_launcher.png"),
    (96, "mipmap-xhdpi/ic_launcher.png"),
    (144, "mipmap-xxhdpi/ic_launcher.png"),
    (192, "mipmap-xxxhdpi/ic_launcher.png"),
]

for (size, file) in androidIcons {
    try png(size, "apps/mobile/android/app/src/main/res/\(file)")
}

try png(32, "apps/mobile/web/favicon.png")
try png(192, "apps/mobile/web/icons/Icon-192.png")
try png(512, "apps/mobile/web/icons/Icon-512.png")
try png(192, "apps/mobile/web/icons/Icon-maskable-192.png")
try png(512, "apps/mobile/web/icons/Icon-maskable-512.png")

let icoPNG = try pngData(size: 256)
var ico = Data()
func appendLE16(_ value: UInt16) {
    ico.append(UInt8(value & 0x00ff))
    ico.append(UInt8((value & 0xff00) >> 8))
}
func appendLE32(_ value: UInt32) {
    ico.append(UInt8(value & 0x000000ff))
    ico.append(UInt8((value & 0x0000ff00) >> 8))
    ico.append(UInt8((value & 0x00ff0000) >> 16))
    ico.append(UInt8((value & 0xff000000) >> 24))
}

appendLE16(0)
appendLE16(1)
appendLE16(1)
ico.append(0)
ico.append(0)
ico.append(0)
ico.append(0)
appendLE16(1)
appendLE16(32)
appendLE32(UInt32(icoPNG.count))
appendLE32(22)
ico.append(icoPNG)
try ico.write(to: root.appendingPathComponent("apps/mobile/windows/runner/resources/app_icon.ico"))

print("Generated Clarity app icons.")
