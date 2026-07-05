#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let canvasSize: CGFloat = 1024
let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let iconCornerRadius: CGFloat = 185
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func ellipse(in rect: CGRect) -> CGPath {
    CGPath(ellipseIn: rect, transform: nil)
}

func drawLinearGradient(
    _ context: CGContext,
    in rect: CGRect,
    colors: [CGColor],
    locations: [CGFloat],
    start: CGPoint,
    end: CGPoint
) {
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
        return
    }

    context.saveGState()
    context.addRect(rect)
    context.clip()
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

func fillRoundedRect(_ context: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor) {
    context.addPath(roundedRect(rect, radius))
    context.setFillColor(fill)
    context.fillPath()
}

func strokeRoundedRect(
    _ context: CGContext,
    _ rect: CGRect,
    radius: CGFloat,
    stroke: CGColor,
    lineWidth: CGFloat
) {
    context.addPath(roundedRect(rect, radius))
    context.setStrokeColor(stroke)
    context.setLineWidth(lineWidth)
    context.strokePath()
}

func drawDot(_ context: CGContext, center: CGPoint, radius: CGFloat, fill: CGColor) {
    context.addPath(ellipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)))
    context.setFillColor(fill)
    context.fillPath()
}

func drawCard(_ context: CGContext) {
    let cardRect = CGRect(x: 278, y: 336, width: 468, height: 470)
    let cardRadius: CGFloat = 48
    let headerHeight: CGFloat = 82

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -24), blur: 34, color: color(0x032433, alpha: 0.26))
    fillRoundedRect(context, cardRect, radius: cardRadius, fill: color(0xf7fbff))
    context.restoreGState()

    context.saveGState()
    context.addPath(roundedRect(cardRect, cardRadius))
    context.clip()

    fillRoundedRect(
        context,
        CGRect(x: cardRect.minX, y: cardRect.maxY - headerHeight, width: cardRect.width, height: headerHeight + cardRadius),
        radius: cardRadius,
        fill: color(0xe8f5f7)
    )

    let dotY = cardRect.maxY - headerHeight / 2
    drawDot(context, center: CGPoint(x: cardRect.minX + 50, y: dotY), radius: 8, fill: color(0xff7f78))
    drawDot(context, center: CGPoint(x: cardRect.minX + 78, y: dotY), radius: 8, fill: color(0xffce5b))
    drawDot(context, center: CGPoint(x: cardRect.minX + 106, y: dotY), radius: 8, fill: color(0x56d28f))

    context.restoreGState()

    strokeRoundedRect(context, cardRect.insetBy(dx: 1.5, dy: 1.5), radius: cardRadius - 1.5, stroke: color(0xffffff, alpha: 0.72), lineWidth: 3)
    strokeRoundedRect(context, cardRect.insetBy(dx: 2.5, dy: 2.5), radius: cardRadius - 2.5, stroke: color(0x0b5363, alpha: 0.12), lineWidth: 2)
}

func drawShelf(_ context: CGContext) {
    let shelfRect = CGRect(x: 232, y: 280, width: 560, height: 56)
    fillRoundedRect(context, shelfRect, radius: 18, fill: color(0xe7fbf8))
    strokeRoundedRect(context, shelfRect.insetBy(dx: 1, dy: 1), radius: 17, stroke: color(0xffffff, alpha: 0.50), lineWidth: 2)
}

func drawIcon(_ context: CGContext) {
    let shell = roundedRect(iconRect, iconCornerRadius)
    context.clear(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

    context.saveGState()
    context.addPath(shell)
    context.clip()

    drawLinearGradient(
        context,
        in: iconRect,
        colors: [color(0x073f50), color(0x13968e)],
        locations: [0, 1],
        start: CGPoint(x: iconRect.minX, y: iconRect.maxY),
        end: CGPoint(x: iconRect.maxX, y: iconRect.minY)
    )

    drawCard(context)
    drawShelf(context)

    context.restoreGState()
}

func renderIcon(pixelSize: Int, to url: URL) throws {
    guard let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "SillIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create \(pixelSize)x\(pixelSize) bitmap context"])
    }

    context.interpolationQuality = .high
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.scaleBy(x: CGFloat(pixelSize) / canvasSize, y: CGFloat(pixelSize) / canvasSize)
    drawIcon(context)

    guard let image = context.makeImage() else {
        throw NSError(domain: "SillIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not make CGImage for \(pixelSize)x\(pixelSize)"])
    }

    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    guard let data = rep.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
        throw NSError(domain: "SillIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG for \(pixelSize)x\(pixelSize)"])
    }

    try data.write(to: url, options: .atomic)
}

func appendFourCC(_ value: String, to data: inout Data) {
    precondition(value.utf8.count == 4)
    data.append(contentsOf: value.utf8)
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { bytes in
        data.append(contentsOf: bytes)
    }
}

func icnsRecord(type: String, pngURL: URL) throws -> Data {
    let pngData = try Data(contentsOf: pngURL)
    var record = Data()
    appendFourCC(type, to: &record)
    appendUInt32(UInt32(pngData.count + 8), to: &record)
    record.append(pngData)
    return record
}

func writeICNS(from iconsetURL: URL, to outputURL: URL) throws {
    let records: [(type: String, name: String)] = [
        ("icp4", "icon_16x16.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("icp5", "icon_32x32.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic08", "icon_256x256.png"),
        ("ic14", "icon_256x256@2x.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png")
    ]

    var body = Data()
    for record in records {
        body.append(try icnsRecord(type: record.type, pngURL: iconsetURL.appendingPathComponent(record.name)))
    }

    var icns = Data()
    appendFourCC("icns", to: &icns)
    appendUInt32(UInt32(body.count + 8), to: &icns)
    icns.append(body)
    try icns.write(to: outputURL, options: .atomic)
}

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetURL = rootURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

let iconFiles: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for iconFile in iconFiles {
    try renderIcon(pixelSize: iconFile.pixels, to: iconsetURL.appendingPathComponent(iconFile.name))
}

try writeICNS(from: iconsetURL, to: icnsURL)

print("Wrote \(iconFiles.count) PNG files to \(iconsetURL.path)")
print("Wrote \(icnsURL.path)")
