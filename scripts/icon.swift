import AppKit

let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 194, yRadius: 194)
        NSGradient(starting: NSColor(srgbRed: 0.17, green: 0.35, blue: 0.78, alpha: 1),
                   ending: NSColor(srgbRed: 0.06, green: 0.10, blue: 0.27, alpha: 1))!
            .draw(in: tile, angle: -75)
        let moon = NSBezierPath(ovalIn: NSRect(x: 245, y: 235, width: 535, height: 555))
        moon.append(NSBezierPath(ovalIn: NSRect(x: 410, y: 340, width: 485, height: 530)))
        moon.windingRule = .evenOdd
        context.saveGState()
        NSBezierPath(ovalIn: NSRect(x: 245, y: 235, width: 535, height: 555)).addClip()
        NSColor(srgbRed: 0.86, green: 0.94, blue: 1, alpha: 1).setFill()
        moon.fill()
        context.restoreGState()
        let star = NSBezierPath()
        star.move(to: NSPoint(x: 733, y: 590))
        for point in [NSPoint(x: 748, y: 630), NSPoint(x: 788, y: 645), NSPoint(x: 748, y: 660), NSPoint(x: 733, y: 700), NSPoint(x: 718, y: 660), NSPoint(x: 678, y: 645), NSPoint(x: 718, y: 630)] { star.line(to: point) }
        star.close()
        star.fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: "\(directory)/icon_\(size)x\(size)\(suffix).png"))
    }
}
