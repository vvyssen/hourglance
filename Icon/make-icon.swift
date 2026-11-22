// Renders the Hourglance app icon: a dark fullscreen "display" with a glowing
// time pill tucked into its top-right corner. Usage: swift Icon/make-icon.swift out.png
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

// macOS Big Sur+ icon grid: 824pt body centred on a 1024 canvas.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(bodyPath); ctx.setFillColor(rgb(0x111522)); ctx.fillPath()
ctx.restoreGState()

// Body: deep night gradient (a fullscreen app)
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0x252B45), rgb(0x10131F)], [0, 1]),
                       start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

// Warm light spilling from the top-right corner — the "glance"
ctx.drawRadialGradient(gradient([rgb(0xFFB547, 0.30), rgb(0xFFB547, 0)], [0, 1]),
                       startCenter: CGPoint(x: body.maxX - 150, y: body.maxY - 150), startRadius: 0,
                       endCenter: CGPoint(x: body.maxX - 150, y: body.maxY - 150), endRadius: 560, options: [])

// Faint content lines: whatever you're working on in fullscreen
let lines: [(CGFloat, CGFloat, UInt32)] = [(0.50, 0.16, 0x7C88C9), (0.40, 0.10, 0x7C88C9),
                                           (0.58, 0.10, 0x7C88C9), (0.30, 0.10, 0x7C88C9), (0.46, 0.08, 0x7C88C9)]
for (i, (w, a, c)) in lines.enumerated() {
    let r = CGRect(x: body.minX + 96, y: body.minY + 150 + CGFloat(i) * 78, width: body.width * w, height: 30)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 15, cornerHeight: 15, transform: nil))
    ctx.setFillColor(rgb(c, a)); ctx.fillPath()
}

// Inner top highlight
ctx.addPath(bodyPath); ctx.setStrokeColor(rgb(0xFFFFFF, 0.08)); ctx.setLineWidth(4); ctx.strokePath()
ctx.restoreGState()

// The time pill in the corner
let pill = CGRect(x: body.maxX - 84 - 360, y: body.maxY - 84 - 144, width: 360, height: 144)
let pillPath = CGPath(roundedRect: pill, cornerWidth: 72, cornerHeight: 72, transform: nil)
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()   // keep the glow inside the icon shape
ctx.setShadow(offset: .zero, blur: 60, color: rgb(0xFFA53D, 0.75))
ctx.addPath(pillPath); ctx.setFillColor(rgb(0xFFB547)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(pillPath); ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0xFFD27A), rgb(0xFF9A3C)], [0, 1]),
                       start: CGPoint(x: 0, y: pill.maxY), end: CGPoint(x: 0, y: pill.minY), options: [])
ctx.restoreGState()

// Digits
let base = NSFont.systemFont(ofSize: 106, weight: .heavy)
let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 106) } ?? base
let attrs: [NSAttributedString.Key: Any] = [
    .font: font, .foregroundColor: NSColor(cgColor: rgb(0x1A1F33))!, .kern: -2,
]
let text = NSAttributedString(string: "9:41", attributes: attrs)
let ts = text.size()
text.draw(at: CGPoint(x: pill.midX - ts.width / 2, y: pill.midY - ts.height / 2 + 2))

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
