import AppKit

let output = CommandLine.arguments[1]
let destination = CommandLine.arguments[2]
let iconset = URL(fileURLWithPath: output).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let side = CGFloat(pixels)
        let rect = NSRect(x: side * 0.07, y: side * 0.07, width: side * 0.86, height: side * 0.86)
        NSColor(calibratedRed: 0.14, green: 0.17, blue: 0.22, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: side * 0.21, yRadius: side * 0.21).fill()
        let config = NSImage.SymbolConfiguration(pointSize: side * 0.49, weight: .medium)
            .applying(.init(paletteColors: [NSColor(calibratedRed: 1, green: 0.68, blue: 0.20, alpha: 1)]))
        NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)?
            .draw(in: NSRect(x: side * 0.23, y: side * 0.23, width: side * 0.54, height: side * 0.54))
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
    }
}
// Modern ICNS entries contain PNG data. Write the container directly so building
// does not depend on iconutil's image conversion service being available.
func bigEndianLength(_ count: Int) -> Data {
    var value = UInt32(count).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
let entries = [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")
]
var body = Data()
for (type, filename) in entries {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    body.append(Data(type.utf8))
    body.append(bigEndianLength(png.count + 8))
    body.append(png)
}
var container = Data("icns".utf8)
container.append(bigEndianLength(body.count + 8))
container.append(body)
try container.write(to: URL(fileURLWithPath: destination))
