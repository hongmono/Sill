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

func drawRadialGradient(
    _ context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    colors: [CGColor],
    locations: [CGFloat]
) {
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
        return
    }

    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
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

func drawPill(_ context: CGContext, _ rect: CGRect, color: CGColor) {
    fillRoundedRect(context, rect, radius: rect.height / 2, fill: color)
}

func drawCaptureCorners(_ context: CGContext, in rect: CGRect, color: CGColor) {
    let length: CGFloat = 34
    let inset: CGFloat = 14
    let lineWidth: CGFloat = 7
    let minX = rect.minX + inset
    let maxX = rect.maxX - inset
    let minY = rect.minY + inset
    let maxY = rect.maxY - inset

    context.saveGState()
    context.setStrokeColor(color)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)

    context.move(to: CGPoint(x: minX, y: maxY - length))
    context.addLine(to: CGPoint(x: minX, y: maxY))
    context.addLine(to: CGPoint(x: minX + length, y: maxY))

    context.move(to: CGPoint(x: maxX - length, y: maxY))
    context.addLine(to: CGPoint(x: maxX, y: maxY))
    context.addLine(to: CGPoint(x: maxX, y: maxY - length))

    context.move(to: CGPoint(x: maxX, y: minY + length))
    context.addLine(to: CGPoint(x: maxX, y: minY))
    context.addLine(to: CGPoint(x: maxX - length, y: minY))

    context.move(to: CGPoint(x: minX + length, y: minY))
    context.addLine(to: CGPoint(x: minX, y: minY))
    context.addLine(to: CGPoint(x: minX, y: minY + length))

    context.strokePath()
    context.restoreGState()
}

func withCardTransform(_ context: CGContext, rect: CGRect, degrees: CGFloat, draw: () -> Void) {
    context.saveGState()
    context.translateBy(x: rect.midX, y: rect.midY)
    context.rotate(by: degrees * .pi / 180)
    context.translateBy(x: -rect.midX, y: -rect.midY)
    draw()
    context.restoreGState()
}

func drawCard(
    _ context: CGContext,
    rect: CGRect,
    degrees: CGFloat,
    accent: CGColor,
    front: Bool
) {
    withCardTransform(context, rect: rect, degrees: degrees) {
        let path = roundedRect(rect, front ? 42 : 36)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -18), blur: front ? 30 : 24, color: color(0x062235, alpha: front ? 0.30 : 0.22))
        context.addPath(path)
        context.setFillColor(color(0xf8fbff, alpha: front ? 0.98 : 0.93))
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.clip()

        let headerHeight: CGFloat = front ? 72 : 64
        let header = CGRect(x: rect.minX, y: rect.maxY - headerHeight, width: rect.width, height: headerHeight)
        drawLinearGradient(
            context,
            in: header,
            colors: [color(0xffffff, alpha: 0.98), color(0xeaf5fb, alpha: 0.98)],
            locations: [0, 1],
            start: CGPoint(x: header.minX, y: header.maxY),
            end: CGPoint(x: header.maxX, y: header.minY)
        )

        let dotY = header.midY
        for (index, dotColor) in [color(0xff7f7a), color(0xffcf5b), color(0x54d18c)].enumerated() {
            let dot = CGRect(x: rect.minX + 34 + CGFloat(index) * 25, y: dotY - 7, width: 14, height: 14)
            context.addPath(ellipse(in: dot))
            context.setFillColor(dotColor)
            context.fillPath()
        }

        drawPill(
            context,
            CGRect(x: rect.minX + 124, y: dotY - 9, width: rect.width * 0.42, height: 18),
            color: color(0x95bfd0, alpha: 0.45)
        )

        let contentInset: CGFloat = front ? 40 : 34
        let screenshot = CGRect(
            x: rect.minX + contentInset,
            y: rect.minY + (front ? 105 : 88),
            width: rect.width - contentInset * 2,
            height: rect.height - headerHeight - (front ? 160 : 132)
        )

        context.saveGState()
        context.addPath(roundedRect(screenshot, front ? 28 : 24))
        context.clip()
        drawLinearGradient(
            context,
            in: screenshot,
            colors: [color(0xd8f4f5), color(0xf4fbff), color(0xb9dde9)],
            locations: [0, 0.46, 1],
            start: CGPoint(x: screenshot.minX, y: screenshot.minY),
            end: CGPoint(x: screenshot.maxX, y: screenshot.maxY)
        )

        fillRoundedRect(
            context,
            CGRect(x: screenshot.minX + 24, y: screenshot.minY + 26, width: screenshot.width * 0.42, height: screenshot.height * 0.58),
            radius: 18,
            fill: color(0xffffff, alpha: 0.58)
        )
        fillRoundedRect(
            context,
            CGRect(x: screenshot.midX + 7, y: screenshot.midY - 12, width: screenshot.width * 0.36, height: screenshot.height * 0.33),
            radius: 16,
            fill: color(0x2f9fa9, alpha: 0.22)
        )
        fillRoundedRect(
            context,
            CGRect(x: screenshot.midX + 11, y: screenshot.minY + 32, width: screenshot.width * 0.32, height: 18),
            radius: 9,
            fill: color(0x0b5772, alpha: 0.18)
        )
        context.restoreGState()

        strokeRoundedRect(context, screenshot, radius: front ? 28 : 24, stroke: color(0xffffff, alpha: 0.70), lineWidth: 3)

        if front {
            drawCaptureCorners(context, in: screenshot.insetBy(dx: 9, dy: 8), color: accent)
            drawPill(
                context,
                CGRect(x: rect.minX + contentInset, y: rect.minY + 58, width: rect.width * 0.44, height: 16),
                color: color(0x86aebf, alpha: 0.34)
            )
            drawPill(
                context,
                CGRect(x: rect.minX + contentInset, y: rect.minY + 34, width: rect.width * 0.30, height: 14),
                color: color(0x86aebf, alpha: 0.24)
            )
        } else {
            drawPill(
                context,
                CGRect(x: rect.minX + contentInset, y: rect.minY + 44, width: rect.width * 0.48, height: 14),
                color: color(0x8bb4c3, alpha: 0.28)
            )
        }

        context.restoreGState()
        strokeRoundedRect(context, rect.insetBy(dx: 1.5, dy: 1.5), radius: front ? 41 : 35, stroke: color(0xffffff, alpha: front ? 0.74 : 0.54), lineWidth: 3)
        strokeRoundedRect(context, rect.insetBy(dx: 2.5, dy: 2.5), radius: front ? 40 : 34, stroke: color(0x275f76, alpha: front ? 0.13 : 0.10), lineWidth: 2)
    }
}

func drawShelf(_ context: CGContext) {
    let cap = CGRect(x: 196, y: 271, width: 632, height: 48)
    let face = CGRect(x: 232, y: 224, width: 560, height: 78)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -20), blur: 30, color: color(0x052235, alpha: 0.32))
    context.addPath(roundedRect(face, 34))
    context.setFillColor(color(0xd8f2f0, alpha: 0.98))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(roundedRect(face, 34))
    context.clip()
    drawLinearGradient(
        context,
        in: face,
        colors: [color(0xf1ffff), color(0xb9dfe0), color(0x80b9c4)],
        locations: [0, 0.48, 1],
        start: CGPoint(x: face.midX, y: face.maxY),
        end: CGPoint(x: face.midX, y: face.minY)
    )
    context.restoreGState()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -9), blur: 16, color: color(0x0a3346, alpha: 0.22))
    context.addPath(roundedRect(cap, 24))
    context.setFillColor(color(0xf6ffff, alpha: 0.98))
    context.fillPath()
    context.restoreGState()

    drawLinearGradient(
        context,
        in: cap,
        colors: [color(0xffffff), color(0xd6f1ee)],
        locations: [0, 1],
        start: CGPoint(x: cap.midX, y: cap.maxY),
        end: CGPoint(x: cap.midX, y: cap.minY)
    )

    fillRoundedRect(
        context,
        CGRect(x: cap.minX + 34, y: cap.maxY - 14, width: cap.width - 68, height: 8),
        radius: 4,
        fill: color(0xffffff, alpha: 0.72)
    )
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
        colors: [color(0x083b63), color(0x0b6e82), color(0x13a39b)],
        locations: [0, 0.58, 1],
        start: CGPoint(x: iconRect.minX, y: iconRect.maxY),
        end: CGPoint(x: iconRect.maxX, y: iconRect.minY)
    )

    drawRadialGradient(
        context,
        center: CGPoint(x: 350, y: 770),
        radius: 520,
        colors: [color(0x70d4d1, alpha: 0.34), color(0x70d4d1, alpha: 0)],
        locations: [0, 1]
    )
    drawRadialGradient(
        context,
        center: CGPoint(x: 790, y: 250),
        radius: 420,
        colors: [color(0x69b6ff, alpha: 0.20), color(0x69b6ff, alpha: 0)],
        locations: [0, 1]
    )

    context.saveGState()
    context.setBlendMode(.softLight)
    context.setFillColor(color(0xffffff, alpha: 0.16))
    context.fill(CGRect(x: iconRect.minX, y: iconRect.midY + 54, width: iconRect.width, height: iconRect.height * 0.35))
    context.restoreGState()

    fillRoundedRect(context, CGRect(x: 176, y: 190, width: 672, height: 74), radius: 37, fill: color(0x05263a, alpha: 0.16))

    drawCard(
        context,
        rect: CGRect(x: 231, y: 350, width: 330, height: 405),
        degrees: -8.5,
        accent: color(0x29b9bf, alpha: 0.88),
        front: false
    )
    drawCard(
        context,
        rect: CGRect(x: 470, y: 336, width: 328, height: 420),
        degrees: 8,
        accent: color(0x5aaef2, alpha: 0.86),
        front: false
    )
    drawCard(
        context,
        rect: CGRect(x: 317, y: 283, width: 397, height: 472),
        degrees: -1.6,
        accent: color(0x0aa7a5, alpha: 0.94),
        front: true
    )

    drawShelf(context)
    context.restoreGState()

    context.saveGState()
    context.addPath(shell)
    context.clip()
    context.addPath(shell)
    context.setStrokeColor(color(0xffffff, alpha: 0.22))
    context.setLineWidth(3)
    context.strokePath()
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
