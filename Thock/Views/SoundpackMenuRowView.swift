import AppKit

/// A sound pack row in the menu bar with a play button that previews the pack.
/// Clicking the name switches to the pack and closes the menu. Clicking ▶ plays a
/// sample and leaves the menu open.
final class SoundpackMenuRowView: NSView {
    private static let height: CGFloat = 22
    private static let minWidth: CGFloat = 200
    private static let checkColumnWidth: CGFloat = 18
    private static let buttonSize: CGFloat = 16
    private static let buttonTrailingInset: CGFloat = 8

    private let title: String
    private let isCurrent: Bool
    private let onSelect: () -> Void
    private let onPreview: () -> Void

    private let checkmark = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let playButton = NSButton()

    init(title: String, isCurrent: Bool, onSelect: @escaping () -> Void, onPreview: @escaping () -> Void) {
        self.title = title
        self.isCurrent = isCurrent
        self.onSelect = onSelect
        self.onPreview = onPreview
        super.init(frame: NSRect(x: 0, y: 0, width: Self.minWidth, height: Self.height))
        autoresizingMask = .width
        setUpSubviews()
        setUpAccessibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Layout

    private func setUpSubviews() {
        checkmark.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        checkmark.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        checkmark.isHidden = !isCurrent

        label.stringValue = title
        label.font = NSFont.menuFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingTail

        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
        playButton.imagePosition = .imageOnly
        playButton.isBordered = false
        playButton.target = self
        playButton.action = #selector(previewPressed)

        for view in [checkmark, label, playButton] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minWidth),
            heightAnchor.constraint(equalToConstant: Self.height),

            checkmark.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            checkmark.widthAnchor.constraint(equalToConstant: Self.checkColumnWidth - 6),
            checkmark.centerYAnchor.constraint(equalTo: centerYAnchor),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.checkColumnWidth + 4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -8),

            playButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.buttonTrailingInset),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: Self.buttonSize),
            playButton.heightAnchor.constraint(equalToConstant: Self.buttonSize),
        ])
    }

    private func setUpAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel(title)
        setAccessibilitySelected(isCurrent)
        playButton.setAccessibilityLabel(L10n.previewSoundpack(title))
    }

    // MARK: - Highlight

    private var isHighlighted: Bool {
        enclosingMenuItem?.isHighlighted ?? false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { needsDisplay = true }
    override func mouseExited(with event: NSEvent) { needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = isHighlighted
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 4, yRadius: 4).fill()
        }
        let foreground: NSColor = highlighted ? .selectedMenuItemTextColor : .labelColor
        label.textColor = foreground
        checkmark.contentTintColor = foreground
        playButton.contentTintColor = highlighted ? .selectedMenuItemTextColor : .secondaryLabelColor
        super.draw(dirtyRect)
    }

    // MARK: - Actions

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !playButton.frame.contains(point) else { return }
        select()
    }

    override func accessibilityPerformPress() -> Bool {
        select()
        return true
    }

    private func select() {
        let menu = enclosingMenuItem?.menu
        onSelect()
        menu?.cancelTracking()
    }

    @objc private func previewPressed() {
        onPreview()
    }
}
