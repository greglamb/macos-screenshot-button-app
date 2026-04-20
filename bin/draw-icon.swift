// Renders a 1024x1024 ScreenshotButton app icon PNG.
// Used by bin/gen-icon. Commit regenerated PNGs, not this intermediate output.
//
// Design: macOS "squircle" rounded square with a blue→indigo vertical gradient
// background, white rounded-rectangle frame with a concentric ring and filled
// center dot — evoking SF Symbol `camera.metering.center.weighted`, which is
// also used as the menu-bar glyph. Intentionally minimal — no SF Symbols in
// the icon itself (Apple HIG prohibits that) and no brand flourishes.

import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: draw-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let outputPath = CommandLine.arguments[1]

let size: CGFloat = 1024
let cornerRadius: CGFloat = 180
let rect = CGRect(x: 0, y: 0, width: size, height: size)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write("failed to create CGContext\n".data(using: .utf8)!)
    exit(1)
}

// Clip to the rounded-square "squircle" (approximated by CGPath corner radius).
let clipPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
context.addPath(clipPath)
context.clip()

// Vertical gradient background (top brighter, bottom deeper).
let topColor = CGColor(red: 0.32, green: 0.44, blue: 0.82, alpha: 1.0)
let bottomColor = CGColor(red: 0.18, green: 0.24, blue: 0.55, alpha: 1.0)
guard let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [topColor, bottomColor] as CFArray,
    locations: [0.0, 1.0]
) else {
    exit(1)
}
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// Center-weighted metering motif: rounded-rect frame + concentric ring +
// filled center dot. All white, centered on the squircle.
context.resetClip()
let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
context.setStrokeColor(white)
context.setFillColor(white)

// Outer rounded-rect frame.
let frameInset: CGFloat = 220
let frameRect = CGRect(
    x: frameInset,
    y: frameInset,
    width: size - 2 * frameInset,
    height: size - 2 * frameInset
)
let framePath = CGPath(
    roundedRect: frameRect,
    cornerWidth: 56,
    cornerHeight: 56,
    transform: nil
)
context.setLineWidth(56)
context.addPath(framePath)
context.strokePath()

// Concentric ring (the "weighted" measurement zone).
let center = CGPoint(x: size / 2, y: size / 2)
let ringRadius: CGFloat = 200
context.setLineWidth(40)
context.strokeEllipse(in: CGRect(
    x: center.x - ringRadius,
    y: center.y - ringRadius,
    width: ringRadius * 2,
    height: ringRadius * 2
))

// Filled center dot.
let dotRadius: CGFloat = 96
context.fillEllipse(in: CGRect(
    x: center.x - dotRadius,
    y: center.y - dotRadius,
    width: dotRadius * 2,
    height: dotRadius * 2
))

guard let cgImage = context.makeImage() else { exit(1) }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else { exit(1) }

let outputURL = URL(fileURLWithPath: outputPath)
try pngData.write(to: outputURL)
