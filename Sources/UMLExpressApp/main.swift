//
//  main.swift
//  UMLExpress
//
//  Port of org.jetuml.JetUML (JetUML 3.10, GPL-3, (C) McGill University).
//

import AppKit
import UMLModel
import UMLRendering
import UMLPersistence
import UMLStudio

/// The application delegate: owns the open documents and implements the menu commands.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, EditorActions, RecentFileOpening,
    WelcomeWindowDelegate {

    private var documents: [DiagramDocument] = []
    private var welcomeWindow: WelcomeWindowController?
    private var openPanel: NSOpenPanel?
    private var savePanel: NSSavePanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The icons are drawn in the rendering layer, which cannot ask AppKit for the
        // system accent colour itself.
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
        IconStyleSettings.accentColor = RGBAColor(red: Double(accent.redComponent),
                                                  green: Double(accent.greenComponent),
                                                  blue: Double(accent.blueComponent),
                                                  alpha: 1.0)
        RecentFilesMenuDelegate.shared.opener = self
        RecentFilesMenuDelegate.shared.clearHandler = { [weak self] in
            self?.welcomeWindow?.recentFiles = []
        }
        NSApp.mainMenu = MainMenu.build(target: self)
        // Files passed on the command line (also handy for testing).
        let arguments = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }
        for path in arguments {
            let url = URL(fileURLWithPath: path)
            do {
                let document = try DiagramDocument.open(url)
                documents.append(document)
                document.windowController.showWindow(nil)
                document.windowController.window?.makeKeyAndOrderFront(nil)
            } catch {
                present(error)
            }
        }
        if documents.isEmpty {
            showWelcome(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Opens the files the user double-clicked in the Finder ("Open With").
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            do {
                let document = try DiagramDocument.open(url)
                documents.append(document)
                document.windowController.showWindow(nil)
                document.windowController.window?.makeKeyAndOrderFront(nil)
            } catch {
                present(error)
            }
        }
    }

    // MARK: - Documents

    private var currentDocument: DiagramDocument? {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
              let controller = window.windowController as? DiagramWindowController else {
            return docs().last
        }
        return documents.first { $0.windowController === controller } ?? docs().last
    }

    private func docs() -> [DiagramDocument] { documents }

    private func createDocument(kind: DiagramKind) -> DiagramDocument {
        let document = DiagramDocument.newDocument(kind: kind)
        documents.append(document)
        document.windowController.showWindow(nil)
        document.windowController.window?.makeKeyAndOrderFront(nil)
        return document
    }

    /// Creates a new diagram; the menu item carries the kind, so "File > New Diagram >
    /// State Diagram" opens a state diagram even when another diagram is already open.
    @objc func newDocument(_ sender: Any?) {
        let kind: DiagramKind
        if let item = sender as? NSMenuItem {
            kind = MainMenu.diagramKind(forMenuItem: item)
        } else {
            kind = .class
        }
        welcomeWindow?.window?.close()
        _ = createDocument(kind: kind)
    }

    /// Shows the welcome window with the diagram shortcuts and recent files.
    /// Switches the style of the tool palette and repaints the palettes of all windows.
    @objc func selectPaletteStyle(_ sender: Any?) {
        guard let item = sender as? NSMenuItem else { return }
        IconStyleSettings.current = MainMenu.paletteStyle(forMenuItem: item)
        for document in documents {
            document.windowController.refreshToolIcons()
            document.windowController.window?.contentView?.needsDisplay = true
        }
    }

    @objc func zoomIn(_ sender: Any?) {
        currentDocument?.windowController.zoomIn(sender)
    }

    @objc func zoomOut(_ sender: Any?) {
        currentDocument?.windowController.zoomOut(sender)
    }

    @objc func resetZoom(_ sender: Any?) {
        currentDocument?.windowController.resetZoom(sender)
    }

    @objc func showWelcome(_ sender: Any?) {
        if welcomeWindow == nil {
            welcomeWindow = WelcomeWindowController()
            welcomeWindow?.delegate = self
        }
        welcomeWindow?.recentFiles = RecentFilesMenuDelegate.shared.queue.recentFiles
        welcomeWindow?.present()
    }

    // MARK: - WelcomeWindowDelegate

    /// Creates a diagram of the kind chosen in the welcome window.
    func newDiagram(_ kind: DiagramKind) {
        welcomeWindow?.window?.close()
        _ = createDocument(kind: kind)
    }

    /// Opens a file chosen in the welcome window.
    func openRecent(_ url: URL) {
        welcomeWindow?.window?.close()
        openRecentFile(url)
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.nameFieldStringValue = "*.jet"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            let document = try DiagramDocument.open(url)
            documents.append(document)
            document.windowController.showWindow(nil)
            document.windowController.window?.makeKeyAndOrderFront(nil)
            RecentFilesMenuDelegate.shared.queue.add(url)
        } catch {
            present(error)
        }
    }

    /// Opens a file chosen from the "Open Recent" menu.
    @objc func openRecentFile(_ url: URL) {
        do {
            let document = try DiagramDocument.open(url)
            documents.append(document)
            document.windowController.showWindow(nil)
            document.windowController.window?.makeKeyAndOrderFront(nil)
            RecentFilesMenuDelegate.shared.queue.add(url)
        } catch {
            RecentFilesMenuDelegate.shared.queue.remove(url)
            present(error)
        }
    }

    @objc func saveDocument(_ sender: Any?) {
        guard let document = currentDocument else { return }
        if let url = document.fileURL {
            do {
                try document.save(to: url)
                RecentFilesMenuDelegate.shared.queue.add(url)
            } catch { present(error) }
        } else {
            saveDocumentAs(sender)
        }
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        guard let document = currentDocument else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(document.session.diagram.diagramKind.fileExtension).jet"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            try document.save(to: url)
            RecentFilesMenuDelegate.shared.queue.add(url)
        } catch { present(error) }
    }

    @objc func duplicateDiagram(_ sender: Any?) {
        guard let document = currentDocument else { return }
        let duplicate = document.duplicateDocument()
        documents.append(duplicate)
        duplicate.windowController.showWindow(nil)
        duplicate.windowController.window?.makeKeyAndOrderFront(nil)
    }

    @objc func copyDiagramToClipboard(_ sender: Any?) {
        guard let document = currentDocument else { return }
        ClipboardImage.copy(document.session.diagram)
    }

    @objc func exportImage(_ sender: Any?) {
        guard let document = currentDocument else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "diagram.svg"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do { try DiagramExporter.write(document.session.diagram, to: url) } catch { present(error) }
    }

    // MARK: - Editing

    @objc func undo(_ sender: Any?) { currentDocument?.windowController.undo(sender) }
    @objc func redo(_ sender: Any?) { currentDocument?.windowController.redo(sender) }

    @objc func cut(_ sender: Any?) {
        currentDocument?.session.canvasController.cut()
    }

    @objc func copy(_ sender: Any?) {
        currentDocument?.session.canvasController.copy()
    }

    @objc func paste(_ sender: Any?) {
        currentDocument?.session.canvasController.paste()
    }

    @objc func delete(_ sender: Any?) {
        currentDocument?.session.canvasController.removeSelected()
    }

    @objc func selectAll(_ sender: Any?) {
        currentDocument?.session.canvasController.selectAll()
    }

    /// Shows the font panel; the chosen font is used for all diagrams.
    @objc func showFontPanel(_ sender: Any?) {
        NSFontManager.shared.target = self
        NSFontManager.shared.setSelectedFont(NSFont(name: StringRenderer.baseFont.family,
                                                    size: CGFloat(StringRenderer.baseFont.size))
                                                ?? NSFont.systemFont(ofSize: 12), isMultiple: false)
        NSFontManager.shared.orderFrontFontPanel(sender)
    }

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let manager = sender ?? NSFontManager.shared as NSFontManager? else { return }
        let current = NSFont(name: StringRenderer.baseFont.family,
                            size: CGFloat(StringRenderer.baseFont.size)) ?? NSFont.systemFont(ofSize: 12)
        let converted = manager.convert(current)
        StringRenderer.baseFont = TextStyle(family: converted.fontName,
                                            size: Int(converted.pointSize.rounded()))
        for document in documents {
            document.windowController.refreshToolIcons()
            document.windowController.window?.contentView?.needsDisplay = true
        }
    }

    @objc func toggleDarkMode(_ sender: Any?) {
        ColorScheme.current = ColorScheme.current == .light ? .dark : .light
        for document in documents {
            document.windowController.refreshToolIcons()
            document.windowController.window?.contentView?.needsDisplay = true
        }
    }

    // MARK: - Errors

    private func present(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "UMLExpress"
        alert.informativeText = (error as? DiagramPersistenceError)?.message ?? error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
