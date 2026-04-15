import SwiftUI

@main
struct Network6AppMain: App {
    @StateObject private var viewModel = NetworkViewModel()

    init() {
        // Make the process a regular app (dock icon + window activation)
        NSApplication.shared.setActivationPolicy(.regular)
        setDockIcon()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1100, minHeight: 600)
                .onAppear {
                    // Bring window to front
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1400, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Export CSV…") {
                    viewModel.exportCSV()
                }
                .keyboardShortcut("e", modifiers: [.command])

                Button("Export JSON…") {
                    viewModel.exportJSON()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }

    /// Generates and sets a custom dock icon programmatically.
    private func setDockIcon() {
        let size = NSSize(width: 256, height: 256)
        let image = NSImage(size: size, flipped: false) { rect in
            // Background: rounded square gradient
            let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 8, dy: 8), xRadius: 48, yRadius: 48)
            let gradient = NSGradient(colors: [
                NSColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1),
                NSColor(red: 0.05, green: 0.15, blue: 0.3, alpha: 1)
            ])
            gradient?.draw(in: bgPath, angle: -45)

            // Globe circle
            let globeRect = NSRect(x: 58, y: 58, width: 140, height: 140)
            let globePath = NSBezierPath(ovalIn: globeRect)
            NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 0.3).setFill()
            globePath.fill()
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.8).setStroke()
            globePath.lineWidth = 3
            globePath.stroke()

            // Horizontal lines on globe
            for y in stride(from: 90, through: 190, by: 25) {
                let linePath = NSBezierPath()
                linePath.move(to: NSPoint(x: 75, y: CGFloat(y)))
                linePath.line(to: NSPoint(x: 181, y: CGFloat(y)))
                NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.3).setStroke()
                linePath.lineWidth = 1
                linePath.stroke()
            }

            // Vertical ellipse on globe
            let vertPath = NSBezierPath(ovalIn: NSRect(x: 100, y: 58, width: 56, height: 140))
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.3).setStroke()
            vertPath.lineWidth = 1
            vertPath.stroke()

            // Connection dots
            let dots: [(CGFloat, CGFloat, CGFloat)] = [
                (95, 160, 6), (155, 180, 5), (170, 110, 7),
                (80, 100, 5), (130, 75, 6)
            ]
            for (x, y, r) in dots {
                let dotRect = NSRect(x: x - r/2, y: y - r/2, width: r, height: r)
                NSColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 0.9).setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            }

            // Center dot (user)
            let centerDot = NSRect(x: 120, y: 120, width: 16, height: 16)
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1).setFill()
            NSBezierPath(ovalIn: centerDot).fill()
            NSColor.white.setStroke()
            let centerPath = NSBezierPath(ovalIn: centerDot)
            centerPath.lineWidth = 2
            centerPath.stroke()

            // "N6" text
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let text = "N6" as NSString
            let textSize = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: (256 - textSize.width) / 2, y: 18), withAttributes: attrs)

            return true
        }

        NSApplication.shared.applicationIconImage = image
    }
}

import AppKit

