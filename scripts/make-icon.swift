// Draws the Caliche CopyClip icon (a clipboard with a "C") and writes Resources/AppIcon.icns.
// Run with: swift scripts/make-icon.swift
import AppKit

let green = NSColor(red: 0.13, green: 0.70, blue: 0.35, alpha: 1)
let darkGreen = NSColor(red: 0.06, green: 0.48, blue: 0.24, alpha: 1)

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024 // Everything is laid out on Apple's 1024 pt icon grid.

    // Background tile (824 pt with the standard macOS margin), green gradient with a soft shadow.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 20 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.set()
    NSGradient(starting: green.blended(withFraction: 0.25, of: .white)!, ending: darkGreen)!
        .draw(in: tilePath, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Clipboard board.
    let board = NSRect(x: 262 * s, y: 190 * s, width: 500 * s, height: 600 * s)
    NSGraphicsContext.saveGraphicsState()
    let boardShadow = NSShadow()
    boardShadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    boardShadow.shadowBlurRadius = 18 * s
    boardShadow.shadowOffset = NSSize(width: 0, height: -8 * s)
    boardShadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: board, xRadius: 60 * s, yRadius: 60 * s).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Clip at the top of the board.
    let clip = NSRect(x: 392 * s, y: 730 * s, width: 240 * s, height: 110 * s)
    NSColor(white: 0.22, alpha: 1).setFill()
    NSBezierPath(roundedRect: clip, xRadius: 40 * s, yRadius: 40 * s).fill()
    let hole = NSRect(x: 482 * s, y: 790 * s, width: 60 * s, height: 26 * s)
    green.setFill()
    NSBezierPath(roundedRect: hole, xRadius: 13 * s, yRadius: 13 * s).fill()

    // Big "C" for Caliche on the board.
    let font = NSFont.systemFont(ofSize: 300 * s, weight: .black)
    let rounded = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: 300 * s) ?? font
    let letter = NSAttributedString(string: "C", attributes: [.font: rounded, .foregroundColor: green])
    let letterSize = letter.size()
    letter.draw(at: NSPoint(x: 512 * s - letterSize.width / 2, y: 400 * s))

    // Three "copied text" lines under the C.
    let lineColor = NSColor(white: 0.82, alpha: 1)
    lineColor.setFill()
    for (index, width) in [340.0, 280.0, 220.0].enumerated() {
        let y = (340 - Double(index) * 55) * s
        NSBezierPath(roundedRect: NSRect(x: 342 * s, y: y, width: width * s, height: 26 * s),
                     xRadius: 13 * s, yRadius: 13 * s).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let png = drawIcon(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try png.write(to: iconset.appendingPathComponent(name))
    }
}

let resources = root.appendingPathComponent("Resources")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try drawIcon(size: 1024).representation(using: .png, properties: [:])!
    .write(to: root.appendingPathComponent("docs/icono.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Listo: Resources/AppIcon.icns" : "iconutil falló")
