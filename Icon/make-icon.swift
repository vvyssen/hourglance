// Renders the Hourglance app icon: a fullscreen "app" with the clock exactly as
// Hourglance draws it, in the top-right corner: a rounded rectangle (corner radius
// = 0.3 × height, as in ClockPanel), black at 60% opacity, white medium-weight digits,
// 24-hour format. Usage: swift Icon/make-icon.swift out.png
import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func gradient(_ colors: [CGColor], _ locs: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locs)!
}
func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// macOS icon grid: 824pt body centred on a 1024 canvas.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = rounded(body, 185)

// Background styles. Usage: swift Icon/make-icon.swift out.png [style]
struct Style { let top: UInt32, bottom: UInt32, band: CGColor, line: CGColor }
let styles: [String: Style] = [
    "light":    Style(top: 0xFDFDFE, bottom: 0xE9EBEF, band: rgb(0x000000, 0.05), line: rgb(0x8A93A6, 0.35)),
    "notch":    Style(top: 0xF7F7F9, bottom: 0xE6E8EC, band: rgb(0x000000, 1.00), line: rgb(0x8A93A6, 0.35)),
    "graphite": Style(top: 0x9AA0AA, bottom: 0x5E636C, band: rgb(0xFFFFFF, 0.10), line: rgb(0xFFFFFF, 0.28)),
    "sand":     Style(top: 0xF8E3C8, bottom: 0xE9A97E, band: rgb(0xFFFFFF, 0.22), line: rgb(0xFFFFFF, 0.45)),
]
let styleName = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "light"
let st = styles[styleName]!

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.30))
ctx.addPath(bodyPath); ctx.setFillColor(rgb(st.bottom)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
ctx.drawLinearGradient(gradient([rgb(st.top), rgb(st.bottom)], [0, 1]),
                       start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])

// Top band: the strip the clock sits in (app toolbar, or the black notch strip in fullscreen)
let toolbar = CGRect(x: body.minX, y: body.maxY - 300, width: body.width, height: 300)
ctx.setFillColor(st.band); ctx.fill(toolbar)
for (i, w) in [0.56, 0.40, 0.62, 0.34, 0.50].enumerated() {
    let r = CGRect(x: body.minX + 96, y: body.minY + 110 + CGFloat(i) * 76, width: body.width * w, height: 32)
    ctx.addPath(rounded(r, 16)); ctx.setFillColor(st.line); ctx.fillPath()
}
// Hairline edge so light icons don't dissolve into light backgrounds
ctx.addPath(bodyPath); ctx.setStrokeColor(rgb(0x000000, 0.10)); ctx.setLineWidth(4); ctx.strokePath()

// The clock, same proportions as the real one (58×20pt, radius 6, 13pt digits) scaled ×7.5
let k: CGFloat = 7.5
let clock = CGRect(x: body.maxX - 96 - 58 * k, y: toolbar.midY - 10 * k, width: 58 * k, height: 20 * k)
ctx.addPath(rounded(clock, 6 * k)); ctx.setFillColor(rgb(0x000000, 0.6)); ctx.fillPath()
ctx.restoreGState()

let font = NSFont.monospacedDigitSystemFont(ofSize: 13 * k, weight: .medium)
let text = NSAttributedString(string: "09:41", attributes: [.font: font, .foregroundColor: NSColor.white])
let ts = text.size()
text.draw(at: CGPoint(x: clock.midX - ts.width / 2, y: clock.midY - ts.height / 2))

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
