// Renders a 1024x1024 ScreenshotButton app icon PNG.
// Used by bin/gen-icon. Commit regenerated PNGs, not this intermediate output.
//
// Design: macOS "squircle" rounded square with a blue→indigo vertical gradient
// background, four white L-shaped corner marks forming a camera viewfinder.
// Intentionally minimal — no SF Symbols (Apple HIG prohibits SF Symbols in
// app icons) and no brand flourishes.

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

// Viewfinder: 4 L-shaped corner marks, white, thick, squared caps.
context.resetClip()
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.setLineWidth(64)
context.setLineCap(.square)

let inset: CGFloat = 240
let armLength: CGFloat = 200

// Each L is drawn as two line segments sharing a vertex at the corner.
func drawL(cornerX: CGFloat, cornerY: CGFloat, armX: CGFloat, armY: CGFloat) {
    context.move(to: CGPoint(x: cornerX + armX, y: cornerY))
    context.addLine(to: CGPoint(x: cornerX, y: cornerY))
    context.addLine(to: CGPoint(x: cornerX, y: cornerY + armY))
    context.strokePath()
}

drawL(cornerX: inset,        cornerY: size - inset, armX:  armLength, armY: -armLength) // top-left
drawL(cornerX: size - inset, cornerY: size - inset, armX: -armLength, armY: -armLength) // top-right
drawL(cornerX: inset,        cornerY: inset,        armX:  armLength, armY:  armLength) // bottom-left
drawL(cornerX: size - inset, cornerY: inset,        armX: -armLength, armY:  armLength) // bottom-right

guard let cgImage = context.makeImage() else { exit(1) }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else { exit(1) }

let outputURL = URL(fileURLWithPath: outputPath)
try pngData.write(to: outputURL)
