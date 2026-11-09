//
//  PropertySheetWindow.swift
//  UMLExpress
//
//  The AppKit view of the property sheet: a sheet with one control per property
//  (port of org.jetuml.gui.PropertySheet, JetUML 3.10, GPL-3, (C) McGill University).
//

import AppKit
import UMLInteraction
import UMLModel
import UMLOperations
import UMLRendering

/// A text view that tells its frame when the keyboard focus arrives and leaves.
///
/// `textDidBeginEditing` is not reliable for this: it only fires when editing starts, not
/// each time the focus returns to the editor, and it never fires when the window loses the
/// focus. Becoming and resigning the first responder covers all of those cases, which is
/// what a single-line text field shows with its focus ring.
@MainActor
final class EditorTextView: NSTextView {

    /// Called when the editor gains (true) or loses (false) the keyboard focus.
    var focusHandler: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            focusHandler?(true)
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            focusHandler?(false)
        }
        return resigned
    }
}

/// A rounded frame around the multi-line editor, drawn like the bezel of a text field.
///
/// A scroll view only offers square bezels, so the editor is put in a custom view: rounded
/// corners, a one-point border and, while the editor has the keyboard focus, a ring in the
/// accent colour of the user that fades in and out like the focus ring of a text field.
/// (This is a plain `NSView` on purpose: `NSBox` throws away extra subviews, which would
/// take the ring with it.)
@MainActor
final class EditorFrame: NSView {

    /// The radius of the rounded corners, matching a text field bezel.
    static let cornerRadius: CGFloat = 5

    /// The distance between the border and the editor, in points.
    static let borderInset: CGFloat = 2

    /// True while the editor inside has the focus.
    var isActive = false {
        didSet { applyBorder() }
    }

    /// The view that draws the focus ring on top of the editor.
    let focusRing = FocusRingOverlay()

    /// The editor placed inside the frame.
    private(set) var editor: NSView?

    /// How long the ring takes to appear and disappear, in seconds.
    static let fadeDuration: TimeInterval = 0.15

    /// The opacity the ring is fading to, for tests.
    var focusRingTargetOpacity: CGFloat { isActive ? 1 : 0 }

    /// The opacity of the ring, for tests.
    var focusRingOpacity: CGFloat { focusRing.alphaValue }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        focusRing.frame = bounds
        focusRing.autoresizingMask = [.width, .height]
        focusRing.alphaValue = 0
        addSubview(focusRing)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("EditorFrame is created in code")
    }

    /// Puts the editor inside the frame, below the ring.
    func setEditor(_ view: NSView) {
        editor?.removeFromSuperview()
        view.frame = bounds.insetBy(dx: Self.borderInset, dy: Self.borderInset)
        view.autoresizingMask = [.width, .height]
        addSubview(view, positioned: .below, relativeTo: focusRing)
        editor = view
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: Self.cornerRadius, yRadius: Self.cornerRadius)
        NSColor.textBackgroundColor.setFill()
        path.fill()
        Self.idleBorderColor.setStroke()
        path.lineWidth = Self.borderWidth
        path.stroke()
    }

    /// The width of the border in its resting state.
    static let borderWidth: CGFloat = 1

    /// The border colour of an idle frame, the same grey a text field bezel uses.
    static var idleBorderColor: NSColor { .separatorColor }

    private func applyBorder() {
        needsDisplay = true
        animateFocusRing()
    }

    /// Fades the ring in when the editor takes the focus and out when it loses it, the way
    /// a text field shows its ring.
    private func animateFocusRing() {
        let target = focusRingTargetOpacity
        // The final value is set immediately, so the ring is there even when animations
        // are switched off; the animation only smooths the transition.
        let previous = focusRing.alphaValue
        focusRing.alphaValue = target
        focusRing.needsDisplay = true
        guard let layer = focusRing.layer else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = previous
        fade.toValue = target
        fade.duration = Self.fadeDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(fade, forKey: "focusRingFade")
    }
}

/// Draws the focus highlight around the multi-line editor.
///
/// The shape, the corner radius and the colour reproduce the focus ring of a text field:
/// the accent colour of the user, drawn as a soft wide stroke with a solid line on top so
/// that it stays crisp on any background. (AppKit's own `NSFocusRingPlacement` draws
/// nothing outside a widget's own focus-ring pass, so the ring is drawn here.)
@MainActor
final class FocusRingOverlay: NSView {

    /// The accent colour of the focus ring, as the system uses it.
    static var accentColor: NSColor { .controlAccentColor }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FocusRingOverlay is created in code")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // The ring is decoration: clicks belong to the editor underneath.
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = EditorFrame.cornerRadius
        // A soft, wide stroke first: it reads as the glow of the system focus ring.
        let glow = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1),
                                xRadius: radius, yRadius: radius)
        glow.lineWidth = 3
        Self.accentColor.withAlphaComponent(0.45).setStroke()
        glow.stroke()
        // A solid line on top, so that the ring is clearly visible.
        let line = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5),
                                xRadius: radius, yRadius: radius)
        line.lineWidth = 1.5
        Self.accentColor.setStroke()
        line.stroke()
    }
}

/// A sheet that edits the properties of a diagram element.
public final class PropertySheetWindow: NSWindowController {

    /// The editing model; exposed for tests, which check the labels of the rows.
    private(set) var model: PropertySheetModel
    private let controller: DiagramCanvasController
    private var textFields: [String: NSTextField] = [:]
    private var textViews: [String: NSTextView] = [:]
    private var editorFrames: [String: EditorFrame] = [:]
    private var checkBoxes: [String: NSButton] = [:]
    private var popUps: [String: NSPopUpButton] = [:]
    private var changeHandler: (() -> Void)?
    /// The values when the sheet was opened, used to build the undo operation on close.
    private let initialValues: [(name: PropertyName, value: Any)]

    /// Creates a property sheet for the element selected in the controller.
    public init?(controller: DiagramCanvasController, onChange: @escaping () -> Void) {
        guard let model = controller.propertySheetModel() else {
            return nil
        }
        self.model = model
        self.controller = controller
        self.changeHandler = onChange
        self.initialValues = model.snapshot()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 60),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        window.title = "Properties"
        super.init(window: window)
        window.delegate = self

        let content = buildContent()
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        let fitting = content.fittingSize
        let height = max(fitting.height, CGFloat(90 + model.rows.count * 34))
        let width = max(fitting.width, 460)
        content.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window.setContentSize(NSSize(width: width, height: height))
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("PropertySheetWindow is created in code")
    }

    // MARK: - Layout

    private func buildContent() -> NSView {
        // A plain container gives the sheet an opaque background; the stack view itself is
        // transparent.
        let container = NSView()
        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 10
        grid.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        grid.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: container.topAnchor),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        for row in model.rows {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.spacing = 10

            let label = NSTextField(labelWithString: row.label)
            label.alignment = .right
            label.textColor = .labelColor
            label.widthAnchor.constraint(equalToConstant: 110).isActive = true
            rowStack.addArrangedSubview(label)
            rowStack.addArrangedSubview(makeControl(for: row))
            grid.addArrangedSubview(rowStack)
        }

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let done = NSButton(title: "Done", target: self, action: #selector(closeSheet(_:)))
        done.keyEquivalent = "\r"
        buttons.addArrangedSubview(done)
        grid.addArrangedSubview(buttons)

        return container
    }

    /// The font of every editor in the sheet, multi-line or not.
    static let editorFont = NSFont.systemFont(ofSize: 12)

    /// The inset of the text inside a multi-line editor, so that the text lines up with
    /// the text of a single-line field.
    static let editorInset = NSSize(width: 2, height: 2)

    private func makeControl(for row: PropertyRow) -> NSView {
        switch row.kind {
        case .multilineText:
            let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 260, height: 70))
            textView.string = row.value
            // The same font as the single-line fields, so that both kinds of editor look
            // alike.
            textView.font = Self.editorFont
            textView.delegate = self
            textView.isRichText = false
            // The frame draws the white background, so that its rounded corners stay clean.
            textView.drawsBackground = false
            textView.textContainerInset = Self.editorInset
            textViews[row.name.rawValue] = textView
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 260, height: 70))
            scroll.documentView = textView
            scroll.hasVerticalScroller = true
            scroll.borderType = .noBorder
            scroll.drawsBackground = false
            // The rounded frame gives the editor the look of a single-line text field.
            let frame = EditorFrame(frame: NSRect(x: 0, y: 0, width: 260, height: 70))
            textView.focusHandler = { [weak frame] focused in
                frame?.isActive = focused
            }
            frame.setEditor(scroll)
            frame.widthAnchor.constraint(equalToConstant: 260).isActive = true
            frame.heightAnchor.constraint(equalToConstant: 70).isActive = true
            editorFrames[row.name.rawValue] = frame
            return frame
        case .boolean:
            let checkBox = NSButton(checkboxWithTitle: "", target: self, action: #selector(booleanChanged(_:)))
            checkBox.state = row.value == "true" ? .on : .off
            checkBox.identifier = NSUserInterfaceItemIdentifier(row.name.rawValue)
            checkBoxes[row.name.rawValue] = checkBox
            return checkBox
        case let .choice(options):
            let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
            popUp.addItems(withTitles: options)
            popUp.selectItem(withTitle: row.value)
            popUp.target = self
            popUp.action = #selector(choiceChanged(_:))
            popUp.identifier = NSUserInterfaceItemIdentifier(row.name.rawValue)
            popUps[row.name.rawValue] = popUp
            return popUp
        case .text:
            let field = NSTextField(string: row.value)
            field.font = Self.editorFont
            // A rounded bezel, so that the border matches the frame of the editors above;
            // it turns blue with the focus ring while the field is being edited.
            field.bezelStyle = .roundedBezel
            field.lineBreakMode = .byTruncatingTail
            field.usesSingleLineMode = true
            field.widthAnchor.constraint(equalToConstant: 260).isActive = true
            field.target = self
            field.action = #selector(textChanged(_:))
            field.delegate = self
            field.identifier = NSUserInterfaceItemIdentifier(row.name.rawValue)
            textFields[row.name.rawValue] = field
            return field
        }
    }

    // MARK: - Actions

    /// Applies an edit to the element immediately, as the original dialog does while the
    /// user types; the undo step is recorded once, when the sheet closes.
    private func apply(_ value: String, for identifier: NSUserInterfaceItemIdentifier?) {
        guard let identifier, let name = PropertyName(rawValue: identifier.rawValue) else {
            return
        }
        model.setRawValue(value, for: name)
        changeHandler?()
    }

    /// Reads the current value of every control into the element.
    ///
    /// The controls apply their edits as they change, but a value typed and never committed
    /// (no tab, no Enter) would otherwise be lost when the sheet closes.
    func applyAllControlValues() {
        for row in model.rows {
            let key = row.name.rawValue
            switch row.kind {
            case .text:
                if let field = textFields[key] {
                    model.setRawValue(field.stringValue, for: row.name)
                }
            case .multilineText:
                if let view = textViews[key] {
                    model.setRawValue(view.string, for: row.name)
                }
            case .boolean:
                if let checkBox = checkBoxes[key] {
                    model.setRawValue(checkBox.state == .on ? "true" : "false", for: row.name)
                }
            case .choice:
                if let popUp = popUps[key] {
                    model.setRawValue(popUp.titleOfSelectedItem ?? row.value, for: row.name)
                }
            }
        }
    }

    /// Records the changes made in this sheet as a single undoable operation.
    ///
    /// The original collects them with a `PropertyChangeTracker` and stores the result as an
    /// already executed operation, so one undo reverts the whole editing session.
    func commitPendingChanges() {
        applyAllControlValues()
        let operation = model.operation(since: initialValues)
        if !operation.isEmpty {
            controller.storeAlreadyAppliedPropertyChange(operation)
        }
        changeHandler?()
    }

    @objc private func closeSheet(_ sender: Any?) {
        commitPendingChanges()
        if let window {
            window.sheetParent?.endSheet(window)
        }
        changeHandler?()
    }

    /// Escape closes the sheet and keeps the changes, as the original dialog does.
    public override func cancelOperation(_ sender: Any?) {
        closeSheet(sender)
    }

    @objc private func booleanChanged(_ sender: NSButton) {
        apply(sender.state == .on ? "true" : "false", for: sender.identifier)
    }

    @objc private func choiceChanged(_ sender: NSPopUpButton) {
        apply(sender.titleOfSelectedItem ?? "", for: sender.identifier)
    }

    @objc private func textChanged(_ sender: NSTextField) {
        apply(sender.stringValue, for: sender.identifier)
    }
}

extension PropertySheetWindow: NSWindowDelegate {
    /// Closing the sheet by any route keeps the edits, as in the original dialog.
    public func windowWillClose(_ notification: Notification) {
        commitPendingChanges()
    }

    /// The focus ring of a text field disappears when its window stops being the key
    /// window; the frame of an editor does the same.
    public func windowDidResignKey(_ notification: Notification) {
        for frame in editorFrames.values {
            frame.isActive = false
        }
    }

    /// Restores the highlight when the window becomes key again and an editor has the
    /// focus.
    public func windowDidBecomeKey(_ notification: Notification) {
        guard let firstResponder = window?.firstResponder else { return }
        for (key, frame) in editorFrames {
            frame.isActive = textViews[key] === firstResponder
        }
    }
}

extension PropertySheetWindow {

    /// The text field used to edit a property, for tests.
    func textField(for name: PropertyName) -> NSTextField? {
        textFields[name.rawValue]
    }

    /// The multi-line editor used to edit a property, for tests.
    func textView(for name: PropertyName) -> NSTextView? {
        textViews[name.rawValue]
    }

    /// The pop-up used to edit an enumerated property, for tests.
    func popUp(for name: PropertyName) -> NSPopUpButton? {
        popUps[name.rawValue]
    }

    /// The rounded frame that contains a text view, if any.
    private func editorFrame(for view: NSTextView) -> EditorFrame? {
        guard let key = textViews.first(where: { $0.value === view })?.key else {
            return nil
        }
        return editorFrames[key]
    }

    /// The rounded frame around a multi-line editor, for tests.
    func editorFrame(for name: PropertyName) -> EditorFrame? {
        editorFrames[name.rawValue]
    }

    /// The checkbox used to edit a boolean property, for tests.
    func checkBox(for name: PropertyName) -> NSButton? {
        checkBoxes[name.rawValue]
    }
}

extension PropertySheetWindow: NSTextFieldDelegate {
    /// Applies the text as it is typed, like the original dialog.
    public func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        apply(field.stringValue, for: field.identifier)
    }

    public func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        apply(field.stringValue, for: field.identifier)
    }
}

extension PropertySheetWindow: NSTextViewDelegate {
    /// Applies the text as it is typed, like the original dialog.
    public func textDidBeginEditing(_ notification: Notification) {
        guard let view = notification.object as? NSTextView else { return }
        editorFrame(for: view)?.isActive = true
    }

    public func textDidChange(_ notification: Notification) {
        guard let view = notification.object as? NSTextView else { return }
        guard let key = textViews.first(where: { $0.value === view })?.key else { return }
        apply(view.string, for: NSUserInterfaceItemIdentifier(key))
    }

    public func textDidEndEditing(_ notification: Notification) {
        guard let view = notification.object as? NSTextView else { return }
        editorFrame(for: view)?.isActive = false
        guard let key = textViews.first(where: { $0.value === view })?.key else { return }
        apply(view.string, for: NSUserInterfaceItemIdentifier(key))
    }
}
