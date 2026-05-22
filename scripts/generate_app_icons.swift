import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("apps/mobile/assets/brand/clarity_source_logo.png")

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    throw NSError(
        domain: "IconGeneration",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not load source logo at \(sourceURL.path)"]
    )
}

func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func writePNG(_ png: Data, to url: URL) throws {
    try ensureDirectory(url.deletingLastPathComponent())
    try png.write(to: url)
}

func drawSourceImage(in bounds: NSRect) {
    NSColor.clear.setFill()
    bounds.fill()
    sourceImage.draw(
        in: bounds,
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .sourceOver,
        fraction: 1.0
    )
}

func bitmap(size: Int) throws -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
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
    rep.size = NSSize(width: size, height: size)
    return rep
}

func sourcePNGData(size: Int, transparentMark: Bool = false) throws -> Data {
    let rep = try bitmap(size: size)
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawSourceImage(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    if transparentMark {
        applyLogoMask(to: rep)
    }

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
    }
    return png
}

func applyLogoMask(to rep: NSBitmapImageRep) {
    guard let data = rep.bitmapData else { return }
    let width = rep.pixelsWide
    let height = rep.pixelsHigh
    let bytesPerRow = rep.bytesPerRow
    let samples = rep.samplesPerPixel

    for y in 0..<height {
        for x in 0..<width {
            let offset = y * bytesPerRow + x * samples
            let red = Double(data[offset])
            let green = Double(data[offset + 1])
            let blue = Double(data[offset + 2])

            let logoScore = green - (blue * 0.55) - (red * 0.25) - 20
            let alpha = max(0, min(1, logoScore / 30))
            data[offset + 3] = alpha < 0.02 ? 0 : UInt8((alpha * 255).rounded())
        }
    }
}

func png(_ size: Int, _ relativePath: String, transparentMark: Bool = false) throws {
    let data = try sourcePNGData(size: size, transparentMark: transparentMark)
    try writePNG(data, to: root.appendingPathComponent(relativePath))
}

try png(1024, "apps/mobile/assets/brand/clarity_mark.png", transparentMark: true)
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

let icoPNG = try sourcePNGData(size: 256)
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

print("Generated Clarity app icons from \(sourceURL.path).")
