//
//  make-icon.swift
//  UMLExpress
//
//  Generates the application icon (a UML class box) as a 1024×1024 PNG, and from it an
//  `.icns` bundle via `iconutil`. Run with:  swift Scripts/make-icon.swift <output-dir>
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = outputDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> CGImage? {
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return nil
    }
    let scale = CGFloat(pixels) / 1024.0
    // Background: rounded "Tahoe-ish" square with a soft gradient.
    let background = CGPath(
        roundedRect: CGRect(x: 60 * scale, y: 60 * scale, width: 904 * scale, height: 904 * scale),
        cornerWidth: 200 * scale, cornerHeight: 200 * scale, transform: nil)
    context.addPath(background)
    context.setFillColor(CGColor(red: 0.20, green: 0.42, blue: 0.78, alpha: 1))
    context.fillPath()

    // A white class box with a name compartment, a separator and two "members".
    let box = CGRect(x: 220 * scale, y: 330 * scale, width: 584 * scale, height: 380 * scale)
    let boxPath = CGPath(roundedRect: box, cornerWidth: 26 * scale, cornerHeight: 26 * scale, transform: nil)
    context.addPath(boxPath)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()

    context.setStrokeColor(CGColor(red: 0.20, green: 0.42, blue: 0.78, alpha: 1))
    context.setLineWidth(14 * scale)
    context.beginPath()
    context.move(to: CGPoint(x: box.minX, y: box.maxY - 110 * scale))
    context.addLine(to: CGPoint(x: box.maxX, y: box.maxY - 110 * scale))
    context.move(to: CGPoint(x: box.minX, y: box.maxY - 240 * scale))
    context.addLine(to: CGPoint(x: box.maxX, y: box.maxY - 240 * scale))
    context.strokePath()

    // Text-like bars in the compartments.
    context.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1))
    for (index, width) in [300, 220, 260].enumerated() {
        let y = box.maxY - 70 * scale - CGFloat(index) * 130 * scale
        context.fill(CGRect(x: box.minX + 60 * scale, y: y, width: CGFloat(width) * scale,
                            height: 26 * scale))
    }
    return context.makeImage()
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, pixels) in sizes {
    guard let image = renderIcon(pixels: pixels) else {
        FileHandle.standardError.write(Data("cannot render the icon\n".utf8))
        exit(1)
    }
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    try (data as Data).write(to: iconset.appendingPathComponent("\(name).png"))
}
print("wrote \(iconset.path)")
