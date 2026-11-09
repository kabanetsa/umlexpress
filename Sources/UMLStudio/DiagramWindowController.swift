//
//  DiagramWindowController.swift
//  UMLExpress
//
//  Port of org.jetuml.gui.DiagramTab and the tab/toolbar plumbing of
//  org.jetuml.gui.EditorFrame (JetUML 3.10, GPL-3, (C) McGill University).
//
//  One window per diagram; window tabs are native (decision D2 in the plan).
//

import AppKit
import UMLGeometry
import UMLInteraction
import UMLModel
import UMLOperations
import UMLRendering
import UMLValidation

/// Hosts one diagram: a canvas, a tool palette and the file undo/redo state.
@MainActor
public final class DiagramWindowController: NSWindowController, NSToolbarDelegate {

    /// The document state of the window: the diagram and its controller.
    public final class DiagramSession {
        /// The diagram being edited.
        public let diagram: Diagram
        /// The canvas controller.
        public let canvasController: DiagramCanvasController
        /// The file the diagram was loaded from, if any.
        public var fileURL: URL?

        public init(diagram: Diagram) {
            self.diagram = diagram
            let builder = DiagramBuilderFactory.builder(for: diagram)
            let validator = DiagramValidatorFactory.validator(for: diagram)
                ?? ClassDiagramValidator(diagram)
            self.canvasController = DiagramCanvasController(builder: builder, validator: validator)
        }
    }

    /// The size of a palette button, in points: large enough for a 25x25 tool icon.
    static let toolButtonSize = NSSize(width: 40, height: 36)

    /// Toolbar item identifiers; the standard ones are not used because the window has
    /// no undo manager.
    static let undoIdentifier = NSToolbarItem.Identifier("undo")
    static let redoIdentifier = NSToolbarItem.Identifier("redo")
    static let zoomInIdentifier = NSToolbarItem.Identifier("zoomIn")
    static let zoomOutIdentifier = NSToolbarItem.Identifier("zoomOut")
    static let actualSizeIdentifier = NSToolbarItem.Identifier("actualSize")

    public let session: DiagramSession
    private var canvasView: DiagramCanvasView!

    /// The property sheet currently presented, if any.
    ///
    /// The controller must stay alive while the sheet is open: AppKit keeps the sheet
    /// *window* alive but the controls hold only weak references to their target and
    /// delegates, so a deallocated controller means a dead Done button.
    private(set) var propertySheetController: PropertySheetWindow?
    private var toolButtons: [NSButton] = []

    public init(session: DiagramSession) {
        self.session = session
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = session.fileURL?.lastPathComponent ?? "Untitled"
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "UMLExpressDiagram"
        super.init(window: window)

        canvasView = DiagramCanvasView(controller: session.canvasController)
        canvasView.onDoubleClick = { [weak self] in self?.editSelected(nil) }

        let scrollView = CanvasScrollView(frame: window.contentLayoutRect)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = canvasView
        scrollView.autoresizingMask = [.width, .height]

        let palette = makeToolPalette()
        let content = NSView(frame: window.contentLayoutRect)
        palette.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(palette)
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            palette.topAnchor.constraint(equalTo: content.topAnchor),
            palette.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            palette.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            palette.widthAnchor.constraint(equalToConstant: 52),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: palette.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        window.contentView = content

        let toolbar = NSToolbar(identifier: "UMLExpressDiagramToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("DiagramWindowController is created in code")
    }

    // MARK: - Tool palette

    /// Builds the vertical palette of creation tools, one button per prototype.
    private func makeToolPalette() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)

        let selectionButton = makeToolButton(title: "", tool: nil, tag: -1)
        stack.addArrangedSubview(selectionButton)

        let prototypes = session.diagram.diagramKind.prototypes
        for (index, prototype) in prototypes.enumerated() {
            let button = makeToolButton(title: Self.shortLabel(for: prototype), tool: prototype, tag: index)
            stack.addArrangedSubview(button)
        }
        return stack
    }

    /// The icon of a palette entry, drawn by the element renderer as in the original.
    ///
    /// The original draws a 25×25 icon per tool with the renderers themselves, so the
    /// palette always matches what the tool creates. The text label stands in as a
    /// fallback for element types whose renderer has no icon.
    func toolIcon(for prototype: any DiagramElement) -> NSImage? {
        guard let cgImage = session.canvasController.renderer.icon(of: prototype) else {
            return nil
        }
        let side = CGFloat(IconRendering.buttonSize)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: side, height: side))
        // The icons are drawn by the renderers with the colours of the current scheme, so
        // they must not be turned into (monochrome) template images.
        image.isTemplate = false
        return image
    }

    /// The palette buttons, for tests.
    func toolPaletteButtons() -> [NSButton] { toolButtons }

    /// Redraws the palette icons, which the renderers draw with the current colour scheme.
    ///
    /// Icons are rendered once per button, so switching to dark mode has to refresh them.
    public func refreshToolIcons() {
        let prototypes = session.diagram.diagramKind.prototypes
        for (index, button) in toolButtons.enumerated() where index > 0 {
            let prototypeIndex = index - 1
            guard prototypeIndex < prototypes.count,
                  let icon = toolIcon(for: prototypes[prototypeIndex]) else {
                continue
            }
            button.image = icon
        }
    }

    private func makeToolButton(title: String, tool: (any DiagramElement)?, tag: Int) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(toolSelected(_:)))
        button.tag = tag
        button.bezelStyle = .smallSquare
        button.setButtonType(.pushOnPushOff)
        button.widthAnchor.constraint(equalToConstant: Self.toolButtonSize.width).isActive = true
        button.heightAnchor.constraint(equalToConstant: Self.toolButtonSize.height).isActive = true
        if let tool {
            if let icon = toolIcon(for: tool) {
                button.image = icon
                button.imagePosition = .imageOnly
                button.title = ""
            }
            button.toolTip = Prototypes.shared.tooltip(tool, verbose: false)
        } else {
            button.image = NSImage(systemSymbolName: "cursorarrow",
                                   accessibilityDescription: "Selection tool")
            button.imagePosition = .imageOnly
            button.toolTip = "Selection tool"
        }
        toolButtons.append(button)
        return button
    }

    /// A short label for a prototype, standing in for the original's icons.
    static func shortLabel(for prototype: any DiagramElement) -> String {
        switch prototype {
        case is ClassNode: "C"
        case is InterfaceNode: "I"
        case is PackageNode: "P"
        case is PackageDescriptionNode: "p"
        case is NoteNode: "N"
        case is ActorNode: "A"
        case is UseCaseNode: "U"
        case is StateNode: "S"
        case is InitialStateNode: "•"
        case is FinalStateNode: "◉"
        case is ObjectNode: "O"
        case is FieldNode: "F"
        case is ImplicitParameterNode: "||"
        case is PointNode: "·"
        case is GeneralizationEdge: "△"
        case is AggregationEdge: "◊"
        case is AssociationEdge: "—"
        case is DependencyEdge: "⋯"
        case is NoteEdge: "- -"
        case is StateTransitionEdge: "↝"
        case is CallEdge: "→"
        case is ReturnEdge: "←"
        case is ObjectReferenceEdge: "⇢"
        case is ObjectCollaborationEdge: "⇠"
        case is UseCaseAssociationEdge: "–"
        case is UseCaseDependencyEdge: "≪"
        case is UseCaseGeneralizationEdge: "△"
        default: "?"
        }
    }

    @objc private func toolSelected(_ sender: NSButton) {
        for button in toolButtons where button !== sender {
            button.state = .off
        }
        if sender.tag < 0 {
            session.canvasController.selectTool(nil)
        } else {
            let prototypes = session.diagram.diagramKind.prototypes
            guard sender.tag < prototypes.count else { return }
            session.canvasController.selectTool(prototypes[sender.tag])
        }
    }

    // MARK: - NSToolbarDelegate

    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.undoIdentifier, Self.redoIdentifier, .flexibleSpace,
         Self.zoomOutIdentifier, Self.zoomInIdentifier, Self.actualSizeIdentifier]
    }

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.undoIdentifier, Self.redoIdentifier, .flexibleSpace,
         Self.zoomOutIdentifier, Self.zoomInIdentifier, Self.actualSizeIdentifier]
    }

    public func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                        willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        switch itemIdentifier {
        case Self.undoIdentifier:
            item.label = "Undo"
            item.image = IconCatalog.image(named: "edit-undo", fallback: "arrow.uturn.backward")
            item.target = self
            item.action = #selector(undo(_:))
        case Self.redoIdentifier:
            item.label = "Redo"
            item.image = IconCatalog.image(named: "edit-redo", fallback: "arrow.uturn.forward")
            item.target = self
            item.action = #selector(redo(_:))
        case Self.zoomInIdentifier:
            item.label = "Zoom In"
            item.image = IconCatalog.image(named: "zoom-in", fallback: "plus.magnifyingglass")
            item.target = self
            item.action = #selector(zoomIn(_:))
        case Self.zoomOutIdentifier:
            item.label = "Zoom Out"
            item.image = IconCatalog.image(named: "zoom-out", fallback: "minus.magnifyingglass")
            item.target = self
            item.action = #selector(zoomOut(_:))
        case Self.actualSizeIdentifier:
            item.label = "Actual Size"
            item.image = IconCatalog.image(named: "zoom-original", fallback: "1.magnifyingglass")
            item.target = self
            item.action = #selector(resetZoom(_:))
        default:
            return nil
        }
        return item
    }

    // MARK: - Commands

    @objc public func undo(_ sender: Any?) {
        session.canvasController.undo()
        canvasView.needsDisplay = true
    }

    @objc public func redo(_ sender: Any?) {
        session.canvasController.redo()
        canvasView.needsDisplay = true
    }

    /// Opens the property sheet for the selected element, as a double click does in the
    /// original.
    @objc public func editSelected(_ sender: Any?) {
        guard let window else { return }
        guard let sheet = PropertySheetWindow(controller: session.canvasController,
                                              onChange: { [weak self] in
            self?.canvasView.needsDisplay = true
        }) else {
            NSSound.beep()
            return
        }
        // Retain the sheet controller for as long as the sheet is presented.
        propertySheetController = sheet
        window.beginSheet(sheet.window!) { [weak self] _ in
            self?.propertySheetController = nil
            self?.canvasView.needsDisplay = true
        }
    }

    /// Presents the property sheet and returns its controller, for tests.
    @discardableResult
    func presentPropertySheet() -> PropertySheetWindow? {
        editSelected(nil)
        return propertySheetController
    }

    /// Zooms in (the original offers the same command in its View menu).
    @objc public func zoomIn(_ sender: Any?) {
        canvasView.zoomIn()
    }

    /// Zooms out.
    @objc public func zoomOut(_ sender: Any?) {
        canvasView.zoomOut()
    }

    /// Restores the default zoom.
    @objc public func resetZoom(_ sender: Any?) {
        canvasView.resetZoom()
    }

    /// The view that shows the diagram, for tests.
    public var canvas: DiagramCanvasView { canvasView }
}
