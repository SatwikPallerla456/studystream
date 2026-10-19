import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
func image(_ size: Int, opaque: Bool = false) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSColor(srgbRed: 0.10, green: 0.11, blue: 0.12, alpha: 1).setFill()
    if opaque { NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill() }
    NSBezierPath(roundedRect: NSRect(x: 24, y: 24, width: 976, height: 976), xRadius: 224, yRadius: 224).fill()
    let orange = NSGradient(starting: NSColor(srgbRed: 1, green: 0.67, blue: 0.19, alpha: 1), ending: NSColor(srgbRed: 0.94, green: 0.32, blue: 0.08, alpha: 1))!
    orange.draw(in: NSBezierPath(ovalIn: NSRect(x: 170, y: 160, width: 684, height: 656)), angle: -90)
    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: 516, y: 798)); leaf.curve(to: NSPoint(x: 745, y: 892), controlPoint1: NSPoint(x: 545, y: 935), controlPoint2: NSPoint(x: 694, y: 950)); leaf.curve(to: NSPoint(x: 516, y: 798), controlPoint1: NSPoint(x: 726, y: 781), controlPoint2: NSPoint(x: 611, y: 768))
    NSColor(srgbRed: 0.33, green: 0.60, blue: 0.34, alpha: 1).setFill(); leaf.fill()
    let play = NSBezierPath()
    play.move(to: NSPoint(x: 430, y: 330)); play.line(to: NSPoint(x: 430, y: 648)); play.line(to: NSPoint(x: 685, y: 490)); play.close()
    NSColor(srgbRed: 1, green: 0.96, blue: 0.88, alpha: 1).setFill(); play.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
try image(512).write(to: root.appendingPathComponent("assets/brand/tangerine.png"))
for size in [16, 32, 64, 128, 256, 512, 1024] {
    try image(size).write(to: root.appendingPathComponent("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_\(size).png"))
}
for (density, size) in [("mdpi",48), ("hdpi",72), ("xhdpi",96), ("xxhdpi",144), ("xxxhdpi",192)] {
    try image(size).write(to: root.appendingPathComponent("android/app/src/main/res/mipmap-\(density)/ic_launcher.png"))
}
let iosDirectory = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: iosDirectory.appendingPathComponent("Contents.json"))) as! [String: Any]
for entry in manifest["images"] as! [[String: Any]] {
    guard let filename = entry["filename"] as? String, let dimensions = entry["size"] as? String, let scale = entry["scale"] as? String,
          let points = Double(dimensions.components(separatedBy: "x")[0]), let multiplier = Double(scale.replacingOccurrences(of: "x", with: "")) else { continue }
    try image(Int(points * multiplier), opaque: true).write(to: iosDirectory.appendingPathComponent(filename))
}
for size in [192, 512] {
    for name in ["Icon-\(size).png", "Icon-maskable-\(size).png"] {
        try image(size, opaque: name.contains("maskable")).write(to: root.appendingPathComponent("web/icons/\(name)"))
    }
}
try image(32).write(to: root.appendingPathComponent("web/favicon.png"))
// Windows supports PNG-compressed icon entries. Keep 32- and 256-pixel variants.
let sizes = [32, 256], payloads = sizes.map { image($0) }
var ico = Data([0, 0, 1, 0, 2, 0])
var offset = UInt32(6 + sizes.count * 16)
func append32(_ value: UInt32, to data: inout Data) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
}
for (index, size) in sizes.enumerated() {
    ico.append(contentsOf: [UInt8(size % 256), UInt8(size % 256), 0, 0, 1, 0, 32, 0])
    append32(UInt32(payloads[index].count), to: &ico); append32(offset, to: &ico)
    offset += UInt32(payloads[index].count)
}
for payload in payloads { ico.append(payload) }
try ico.write(to: root.appendingPathComponent("windows/runner/resources/app_icon.ico"))
