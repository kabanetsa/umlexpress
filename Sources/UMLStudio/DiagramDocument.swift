//
//  Export.swift, DiagramDocument.swift, MainMenu.swift
//  UMLExpress
//
//  Port of the export features of org.jetuml.gui.DiagramCanvas (createImage,
//  createSvgImage) and of the document/menu plumbing of org.jetuml.gui.EditorFrame and
//  MenuFactory (JetUML 3.10, GPL-3, (C) McGill University).
//

import AppKit
import CoreGraphics
import ImageIO
import UMLRendering
import UMLGeometry
import UMLInteraction
import UMLModel
import UMLOperations
import UMLPersistence
import UMLValidation

/// Renders a diagram to an image file, as the "Export Image" menu item does.
@MainActor
public enum DiagramExporter {

    /// The margin around an exported diagram, in pixels.
    public static let padding = 7

    /// The SVG description of a diagram.
    public static func svg(_ diagram: Diagram) -> String {
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let context = SVGRenderingContext(viewport: renderer.diagramBounds())
        renderer.drawDiagram(context)
        return context.create()
    }

    /// A bitmap of the diagram, with a white margin around it.
    public static func image(_ diagram: Diagram) -> NSImage? {
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let bounds = renderer.diagramBounds()
        let width = bounds.width + padding * 2
        let height = bounds.height + padding * 2
        guard let context = CGContext(
            data: nil, width: max(width, 1), height: max(height, 1), bitsPerComponent: 8,
            bytesPerRow: max(width, 1) * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        // A y-down coordinate system, like the canvas.
        context.translateBy(x: 0, y: CGFloat(max(height, 1)))
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(ColorScheme.current.background.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: max(width, 1), height: max(height, 1)))
        context.translateBy(x: CGFloat(padding - bounds.x), y: CGFloat(padding - bounds.y))
        renderer.drawDiagram(CGRenderingContext(context))
        guard let cgImage = context.makeImage() else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    /// A one-page PDF of the diagram (a bonus of the Core Graphics pipeline).
    public static func pdf(_ diagram: Diagram) -> Data? {
        let renderer = DiagramRendererFactory.renderer(for: diagram)
        let bounds = renderer.diagramBounds()
        let width = bounds.width + padding * 2
        let height = bounds.height + padding * 2
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else {
            return nil
        }
        var mediaBox = CGRect(x: 0, y: 0, width: max(width, 1), height: max(height, 1))
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }
        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: CGFloat(max(height, 1)))
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(ColorScheme.current.background.cgColor)
        context.fill(mediaBox)
        context.translateBy(x: CGFloat(padding - bounds.x), y: CGFloat(padding - bounds.y))
        renderer.drawDiagram(CGRenderingContext(context))
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    /// Writes the diagram as SVG or PNG depending on the extension.
    public static func write(_ diagram: Diagram, to url: URL) throws {
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let data = pdf(diagram) else {
                throw NSError(domain: "UMLExpress", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "Cannot render the PDF"])
            }
            try data.write(to: url)
        case "svg":
            try svg(diagram).write(to: url, atomically: true, encoding: .utf8)
        case "png", "jpeg", "jpg", "tiff":
            guard let image = image(diagram),
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff) else {
                throw NSError(domain: "UMLExpress", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Cannot render the diagram"])
            }
            let type: NSBitmapImageRep.FileType = url.pathExtension.lowercased() == "png"
                ? .png : .jpeg
            guard let data = rep.representation(using: type, properties: [:]) else {
                throw NSError(domain: "UMLExpress", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Cannot encode the image"])
            }
            try data.write(to: url)
        default:
            // Plain `.jet` output.
            try DiagramCoding.encode(diagram).write(to: url)
        }
    }
}

/// A window tab that shows one diagram: the document of the application.
///
/// The original keeps diagrams in `DiagramTab` objects inside a single `EditorFrame`;
/// the port uses one window per diagram with native window tabs (decision D2).
@MainActor
public final class DiagramDocument {

    /// The file the diagram belongs to, if any.
    public var fileURL: URL?

    /// The editing session of the diagram.
    public let session: DiagramWindowController.DiagramSession

    /// The window controller of this document.
    public let windowController: DiagramWindowController

    /// Creates a document for a diagram.
    public init(diagram: Diagram, fileURL: URL? = nil) {
        self.fileURL = fileURL
        self.session = DiagramWindowController.DiagramSession(diagram: diagram)
        self.session.fileURL = fileURL
        self.windowController = DiagramWindowController(session: session)
    }

    /// A new, empty diagram of the given kind.
    public static func newDocument(kind: DiagramKind = .class) -> DiagramDocument {
        DiagramDocument(diagram: Diagram(kind: kind))
    }

    /// Loads a document from a `.jet` file.
    public static func open(_ url: URL) throws -> DiagramDocument {
        let data = try Data(contentsOf: url)
        let diagram = try DiagramCoding.decode(data)
        return DiagramDocument(diagram: diagram, fileURL: url)
    }

    /// Saves the diagram to `url`, or to the current file.
    public func save(to url: URL? = nil) throws {
        guard let target = url ?? fileURL else {
            throw NSError(domain: "UMLExpress", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "The document has no file"])
        }
        try DiagramCoding.encode(session.diagram).write(to: target)
        fileURL = target
        session.fileURL = target
        session.canvasController.diagramSaved()
        windowController.window?.title = target.lastPathComponent
    }

    /// A duplicate of this document: a independent copy of the graph, without a file.
    public func duplicateDocument() -> DiagramDocument {
        DiagramDocument(diagram: session.diagram.duplicate())
    }

    /// The title shown in the window and its tab.
    public var title: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    /// True if the document has unsaved changes.
    public var hasUnsavedChanges: Bool { session.canvasController.hasUnsavedChanges }
}

/// Builds the application's main menu.
///
/// Port of `org.jetuml.gui.MenuFactory` adapted to the macOS menu conventions.
@MainActor
public enum MainMenu {

    /// The titles of the "New Diagram" submenu, in the order of `DiagramKind.allCases`
    /// (`DiagramKind.allCases`), with the tag of each item matching its index.
    public static let newDiagramTitles = [
        "Class Diagram", "Sequence Diagram", "State Diagram", "Object Diagram",
        "Use Case Diagram",
    ]

    /// The diagram kind a "New Diagram" menu item asks for.
    public static func diagramKind(forMenuItem item: NSMenuItem) -> DiagramKind {
        let kinds = DiagramKind.allCases
        guard item.tag >= 0, item.tag < kinds.count else {
            return .class
        }
        return kinds[item.tag]
    }

    /// The style a "Palette Style" menu item asks for.
    public static func paletteStyle(forMenuItem item: NSMenuItem) -> PaletteIconStyle {
        let styles = PaletteIconStyle.allCases
        guard item.tag >= 0, item.tag < styles.count else {
            return .drafting
        }
        return styles[item.tag]
    }

    /// Builds the main menu, using the given target for document commands.
    public static func build(target: AnyObject) -> NSMenu {
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About UMLExpress", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit UMLExpress", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        // A submenu, so that the type of the new diagram can be chosen explicitly; the
        // class diagram keeps the plain "New" shortcut.
        let newItem = NSMenuItem(title: "New Diagram", action: nil, keyEquivalent: "")
        let newMenu = NSMenu(title: "New Diagram")
        for (tag, title) in Self.newDiagramTitles.enumerated() {
            let item = NSMenuItem(title: title, action: #selector(EditorActions.newDocument(_:)),
                                  keyEquivalent: tag == 0 ? "n" : "")
            item.tag = tag
            item.target = target
            newMenu.addItem(item)
        }
        newItem.submenu = newMenu
        fileMenu.addItem(newItem)
        addItem(fileMenu, "Open…", #selector(EditorActions.openDocument(_:)), "o", target)
        let recentItem = NSMenuItem(title: "Open Recent", action: nil, keyEquivalent: "")
        let recentMenu = NSMenu(title: "Open Recent")
        recentMenu.delegate = RecentFilesMenuDelegate.shared
        recentItem.submenu = recentMenu
        fileMenu.addItem(recentItem)
        fileMenu.addItem(.separator())
        addItem(fileMenu, "Save", #selector(EditorActions.saveDocument(_:)), "s", target)
        addItem(fileMenu, "Save As…", #selector(EditorActions.saveDocumentAs(_:)), "S", target)
        fileMenu.addItem(.separator())
        addItem(fileMenu, "Duplicate", #selector(EditorActions.duplicateDiagram(_:)), "D", target)
        addItem(fileMenu, "Export Image…", #selector(EditorActions.exportImage(_:)), "e", target)
        addItem(fileMenu, "Copy Diagram to Clipboard",
                #selector(EditorActions.copyDiagramToClipboard(_:)), "", target)
        fileMenu.addItem(.separator())
        addItem(fileMenu, "Close", #selector(NSWindow.performClose(_:)), "w", target)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        addItem(editMenu, "Undo", #selector(EditorActions.undo(_:)), "z", target)
        addItem(editMenu, "Redo", #selector(EditorActions.redo(_:)), "Z", target)
        editMenu.addItem(.separator())
        addItem(editMenu, "Cut", #selector(EditorActions.cut(_:)), "x", target)
        addItem(editMenu, "Copy", #selector(EditorActions.copy(_:)), "c", target)
        addItem(editMenu, "Paste", #selector(EditorActions.paste(_:)), "v", target)
        addItem(editMenu, "Delete", #selector(EditorActions.delete(_:)), "\u{8}", target)
        editMenu.addItem(.separator())
        addItem(editMenu, "Select All", #selector(EditorActions.selectAll(_:)), "a", target)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let styleItem = NSMenuItem(title: "Palette Style", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu(title: "Palette Style")
        for (tag, style) in PaletteIconStyle.allCases.enumerated() {
            let item = NSMenuItem(title: style.menuTitle,
                                  action: #selector(EditorActions.selectPaletteStyle(_:)),
                                  keyEquivalent: "")
            item.tag = tag
            item.target = target
            styleMenu.addItem(item)
        }
        styleItem.submenu = styleMenu
        viewMenu.addItem(styleItem)
        viewMenu.addItem(.separator())
        addItem(viewMenu, "Zoom In", #selector(EditorActions.zoomIn(_:)), "+", target)
        addItem(viewMenu, "Zoom Out", #selector(EditorActions.zoomOut(_:)), "-", target)
        addItem(viewMenu, "Actual Size", #selector(EditorActions.resetZoom(_:)), "0", target)
        viewMenu.addItem(.separator())
        addItem(viewMenu, "Dark Mode", #selector(EditorActions.toggleDarkMode(_:)), "d", target)
        addItem(viewMenu, "Font…", #selector(EditorActions.showFontPanel(_:)), "t", target)
        addItem(viewMenu, "Welcome", #selector(EditorActions.showWelcome(_:)), "", target)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        return mainMenu
    }

    private static func addItem(_ menu: NSMenu, _ title: String, _ action: Selector,
                                _ key: String, _ target: AnyObject?) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        menu.addItem(item)
    }
}

/// Fills the "Open Recent" menu from the recent-files queue when it is shown.
@MainActor
public final class RecentFilesMenuDelegate: NSObject, NSMenuDelegate {

    /// The shared delegate.
    public static let shared = RecentFilesMenuDelegate()

    private override init() { super.init() }

    /// The queue populating the menu.
    public var queue = RecentFilesQueue()

    /// Set by the application delegate to open a file chosen from the menu.
    public weak var opener: (any RecentFileOpening)?

    /// Called when the queue is emptied, so that an open welcome window can refresh.
    public var clearHandler: (() -> Void)?

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let files = queue.recentFiles
        if files.isEmpty {
            let empty = NSMenuItem(title: "No Recent Files", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for file in files {
            let item = NSMenuItem(title: file.lastPathComponent,
                                  action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = file
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear Menu", action: #selector(clearRecent(_:)), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        opener?.openRecentFile(url)
    }

    @objc private func clearRecent(_ sender: Any?) {
        queue.clear()
        clearHandler?()
    }
}

/// Implemented by the application delegate to react to a recent file selection.
@MainActor
public protocol RecentFileOpening: AnyObject {
    func openRecentFile(_ url: URL)
}

/// The document-level commands of the application menu.
@objc @MainActor public protocol EditorActions {
    func newDocument(_ sender: Any?)
    func openDocument(_ sender: Any?)
    func saveDocument(_ sender: Any?)
    func saveDocumentAs(_ sender: Any?)
    func exportImage(_ sender: Any?)
    func duplicateDiagram(_ sender: Any?)
    func copyDiagramToClipboard(_ sender: Any?)
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
    func cut(_ sender: Any?)
    func copy(_ sender: Any?)
    func paste(_ sender: Any?)
    func delete(_ sender: Any?)
    func selectAll(_ sender: Any?)
    func selectPaletteStyle(_ sender: Any?)
    func zoomIn(_ sender: Any?)
    func zoomOut(_ sender: Any?)
    func resetZoom(_ sender: Any?)
    func toggleDarkMode(_ sender: Any?)
    func showFontPanel(_ sender: Any?)
    func showWelcome(_ sender: Any?)
}
