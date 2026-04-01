import AppKit

let size = CGSize(width: 1024, height: 1024)
let backgroundColor = NSColor(calibratedRed: 244 / 255, green: 241 / 255, blue: 236 / 255, alpha: 1)
let charcoal = NSColor(calibratedRed: 47 / 255, green: 47 / 255, blue: 47 / 255, alpha: 1)
let accent = NSColor(calibratedRed: 163 / 255, green: 177 / 255, blue: 138 / 255, alpha: 1)

let image = NSImage(size: size)
image.lockFocus()

let canvasRect = NSRect(origin: .zero, size: size)
backgroundColor.setFill()
NSBezierPath(roundedRect: canvasRect, xRadius: 224, yRadius: 224).fill()

accent.withAlphaComponent(0.14).setFill()
NSBezierPath(ovalIn: NSRect(x: 340, y: 340, width: 344, height: 344)).fill()

let eyePath = NSBezierPath()
eyePath.move(to: NSPoint(x: 232, y: 512))
eyePath.curve(
    to: NSPoint(x: 792, y: 512),
    controlPoint1: NSPoint(x: 310, y: 404),
    controlPoint2: NSPoint(x: 404, y: 350)
)
eyePath.curve(
    to: NSPoint(x: 232, y: 512),
    controlPoint1: NSPoint(x: 713, y: 620),
    controlPoint2: NSPoint(x: 620, y: 674)
)
eyePath.lineWidth = 42
eyePath.lineJoinStyle = .round
eyePath.lineCapStyle = .round
charcoal.setStroke()
eyePath.stroke()

let irisPath = NSBezierPath(ovalIn: NSRect(x: 436, y: 436, width: 152, height: 152))
irisPath.lineWidth = 34
charcoal.setStroke()
irisPath.stroke()

accent.setFill()
NSBezierPath(ovalIn: NSRect(x: 494, y: 494, width: 36, height: 36)).fill()

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to render PNG data.")
}

let outputURL = URL(fileURLWithPath: "assets/blinker-app-icon.png")
try pngData.write(to: outputURL)
