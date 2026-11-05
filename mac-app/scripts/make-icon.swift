// Draws the TestForge app icon (R4g, D-111) at 1024 × 1024: a phone on a blue squircle with a passing check.
// Usage: swift scripts/make-icon.swift Assets/AppIcon-1024.png
import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "Assets/AppIcon-1024.png"
let side: CGFloat = 1024
// macOS icon grid: the squircle sits inside an 824 pt square, leaving room for the system shadow.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileRadius: CGFloat = 185

guard let context = CGContext(
	data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
	space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
	bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
	fatalError("no bitmap context")
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
	CGColor(
		srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
		green: CGFloat((hex >> 8) & 0xFF) / 255,
		blue: CGFloat(hex & 0xFF) / 255,
		alpha: alpha
	)
}

// Tile: soft drop shadow, then a top-to-bottom blue gradient.
let tilePath = CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, alpha: 0.35))
context.addPath(tilePath)
context.setFillColor(color(0x0B4FD1))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(tilePath)
context.clip()
let tileGradient = CGGradient(colorsSpace: nil, colors: [color(0x3D8BFF), color(0x0A3FB8)] as CFArray, locations: [0, 1])
if let tileGradient {
	context.drawLinearGradient(tileGradient, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
}
context.restoreGState()

// Phone: white body, blue screen with three "test step" rows.
let phone = CGRect(x: 322, y: 210, width: 380, height: 604)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x001A4D, alpha: 0.45))
context.addPath(CGPath(roundedRect: phone, cornerWidth: 70, cornerHeight: 70, transform: nil))
context.setFillColor(color(0xFFFFFF))
context.fillPath()
context.restoreGState()

let screen = phone.insetBy(dx: 26, dy: 26)
context.addPath(CGPath(roundedRect: screen, cornerWidth: 48, cornerHeight: 48, transform: nil))
context.setFillColor(color(0xEAF2FF))
context.fillPath()

// Dynamic Island, so the card reads as a phone.
context.addPath(CGPath(roundedRect: CGRect(x: phone.midX - 62, y: screen.maxY - 58, width: 124, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil))
context.setFillColor(color(0x1C1C1E))
context.fillPath()

for (index, width) in [200, 160, 184].enumerated() {
	let rowY = screen.maxY - 150 - CGFloat(index) * 105
	context.addEllipse(in: CGRect(x: screen.minX + 40, y: rowY, width: 44, height: 44))
	context.setFillColor(color(0x34C759))
	context.fillPath()
	context.addPath(CGPath(roundedRect: CGRect(x: screen.minX + 104, y: rowY + 8, width: CGFloat(width), height: 28), cornerWidth: 14, cornerHeight: 14, transform: nil))
	context.setFillColor(color(0xB9D2FF))
	context.fillPath()
}

// Badge: green circle with a white check, overlapping the phone's lower right corner.
let badge = CGRect(x: 560, y: 170, width: 300, height: 300)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0x003314, alpha: 0.45))
context.addEllipse(in: badge)
context.setFillColor(color(0x30D158))
context.fillPath()
context.restoreGState()
context.addEllipse(in: badge.insetBy(dx: 12, dy: 12))
context.setStrokeColor(color(0xFFFFFF, alpha: 0.9))
context.setLineWidth(10)
context.strokePath()

context.setStrokeColor(color(0xFFFFFF))
context.setLineWidth(42)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: badge.minX + 82, y: badge.midY + 2))
context.addLine(to: CGPoint(x: badge.minX + 132, y: badge.midY - 52))
context.addLine(to: CGPoint(x: badge.maxX - 72, y: badge.midY + 62))
context.strokePath()

guard let image = context.makeImage() else {
	fatalError("no image")
}
let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
	fatalError("no PNG data")
}
let url = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: url)
print("wrote \(url.path)")
