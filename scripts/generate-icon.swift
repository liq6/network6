#!/usr/bin/env swift
// Generates the Network6 app icon as a PNG file.
// Usage: swift scripts/generate-icon.swift <output-path> [size]

import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let iconSize = CommandLine.arguments.count > 2 ? CGFloat(Double(CommandLine.arguments[2]) ?? 512) : 512.0

let size = NSSize(width: iconSize, height: iconSize)
let scale = iconSize / 256.0

let image = NSImage(size: size, flipped: false) { rect in
    let s = scale // shorthand

    // Background: rounded square gradient
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 8 * s, dy: 8 * s), xRadius: 48 * s, yRadius: 48 * s)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1),
        NSColor(red: 0.05, green: 0.15, blue: 0.3, alpha: 1)
    ])
    gradient?.draw(in: bgPath, angle: -45)

    // Globe circle
    let globeRect = NSRect(x: 58 * s, y: 58 * s, width: 140 * s, height: 140 * s)
    let globePath = NSBezierPath(ovalIn: globeRect)
    NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 0.3).setFill()
    globePath.fill()
    NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.8).setStroke()
    globePath.lineWidth = 3 * s
    globePath.stroke()

    // Horizontal lines on globe
    for y in stride(from: 90, through: 190, by: 25) {
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: 75 * s, y: CGFloat(y) * s))
        linePath.line(to: NSPoint(x: 181 * s, y: CGFloat(y) * s))
        NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.3).setStroke()
        linePath.lineWidth = 1 * s
        linePath.stroke()
    }

    // Vertical ellipse on globe
    let vertPath = NSBezierPath(ovalIn: NSRect(x: 100 * s, y: 58 * s, width: 56 * s, height: 140 * s))
    NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.3).setStroke()
    vertPath.lineWidth = 1 * s
    vertPath.stroke()

    // Connection dots
    let dots: [(CGFloat, CGFloat, CGFloat)] = [
        (95, 160, 6), (155, 180, 5), (170, 110, 7),
        (80, 100, 5), (130, 75, 6)
    ]
    for (x, y, r) in dots {
        let dotRect = NSRect(x: (x - r/2) * s, y: (y - r/2) * s, width: r * s, height: r * s)
        NSColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 0.9).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    // Center dot (user)
    let centerDot = NSRect(x: 120 * s, y: 120 * s, width: 16 * s, height: 16 * s)
    NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1).setFill()
    NSBezierPath(ovalIn: centerDot).fill()
    NSColor.white.setStroke()
    let centerPath = NSBezierPath(ovalIn: centerDot)
    centerPath.lineWidth = 2 * s
    centerPath.stroke()

    // "N6" text
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28 * s, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let text = "N6" as NSString
    let textSize = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (iconSize - textSize.width) / 2, y: 18 * s), withAttributes: attrs)

    return true
}

// Save as PNG
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Error: Failed to create PNG\n", stderr)
    exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
print("✅ Icon saved to \(outputPath) (\(Int(iconSize))x\(Int(iconSize)))")
