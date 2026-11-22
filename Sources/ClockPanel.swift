import Cocoa

/// Receives clicks only while the user holds the configured modifier over the clock
/// (the controller toggles the panel's ignoresMouseEvents); otherwise clicks pass through.
final class ClickView: NSView {
    var onClick: ((NSEvent, NSView) -> Void)?
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) != nil ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?(event, self) }
    override func rightMouseDown(with event: NSEvent) { onClick?(event, self) }
}

final class ClockPanel: NSPanel {
    let label = NSTextField(labelWithString: "")
    let box = ClickView()
    private var lastKey = ""

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true              // click-through by default
        level = .statusBar                     // above fullscreen windows and the menu bar strip
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true

        box.wantsLayer = true
        label.alignment = .center
        label.lineBreakMode = .byClipping
        box.addSubview(label)
        contentView = box
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func layout(text: String, on screen: NSScreen, menuBarHeight: CGFloat, styleVersion: Int) {
        let key = "\(text)|\(screen.frame)|\(menuBarHeight)|\(styleVersion)"
        guard key != lastKey else { return }
        lastKey = key

        let size = Prefs.fontSize, scale = size / 13
        label.font = .monospacedDigitSystemFont(ofSize: size, weight: Prefs.weight.ns)
        let style = Prefs.style()
        label.textColor = style.text
        label.stringValue = text
        box.layer?.backgroundColor = style.background?.cgColor
        label.shadow = style.shadow ? {
            let s = NSShadow(); s.shadowColor = NSColor.black.withAlphaComponent(0.8)
            s.shadowBlurRadius = 2; s.shadowOffset = .zero; return s
        }() : nil

        let textSize = label.intrinsicContentSize
        let margin: CGFloat = 6
        var h = ceil(textSize.height + 4 * scale)
        if Prefs.corner.isTop { h = min(h, max(menuBarHeight - 4, textSize.height + 2)) }   // stay inside the menu bar strip
        h = max(h, 16)
        let capsule = Prefs.shape == .capsule
        let padX = capsule ? max(8 * scale, h * 0.45) : 8 * scale
        let w = ceil(textSize.width + padX * 2)
        box.layer?.cornerRadius = capsule ? h / 2 : min(Prefs.cornerRadius * scale, h / 2)

        let f = screen.frame
        let x = Prefs.corner.isRight ? f.maxX - w - margin : f.minX + margin
        // Top corners: centred in the menu bar strip (next to the notch on MacBooks). Bottom: just above the edge.
        let y = Prefs.corner.isTop ? f.maxY - (menuBarHeight + h) / 2 : f.minY + margin
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
        box.frame = NSRect(x: 0, y: 0, width: w, height: h)
        label.frame = NSRect(x: 0, y: (h - textSize.height) / 2, width: w, height: textSize.height)
    }
}
