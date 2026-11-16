//
//  TextClipboardTests.swift
//  UMLExpress
//
//  The Edit menu goes through the responder chain, so that copying and pasting text in the
//  property sheet works: the diagram commands must not swallow the shortcuts while a text
//  field has the focus.
//

import AppKit
import XCTest
@testable import UMLGeometry
@testable import UMLInteraction
@testable import UMLModel
@testable import UMLRendering
@testable import UMLStudio

@MainActor
final class TextClipboardTests: XCTestCase {

    private func makeSheet() -> (DiagramDocument, PropertySheetWindow) {
        CanvasClipboard.shared.clear()
        let document = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("A")
        node.moveTo(Point(x: 10, y: 10))
        document.session.diagram.addRootNode(node)
        document.session.canvasController.setSelection(node)
        let sheet = PropertySheetWindow(controller: document.session.canvasController,
                                        onChange: {})!
        return (document, sheet)
    }

    /// The Edit commands have no explicit target: they are resolved through the responder
    /// chain, which is what lets the text editors handle them.
    func testEditMenuUsesTheResponderChain() throws {
        final class Target: NSObject, EditorActions {
            func newDocument(_ sender: Any?) {}
            func openDocument(_ sender: Any?) {}
            func saveDocument(_ sender: Any?) {}
            func saveDocumentAs(_ sender: Any?) {}
            func exportImage(_ sender: Any?) {}
            func duplicateDiagram(_ sender: Any?) {}
            func copyDiagramToClipboard(_ sender: Any?) {}
            func undo(_ sender: Any?) {}
            func redo(_ sender: Any?) {}
            func cut(_ sender: Any?) {}
            func copy(_ sender: Any?) {}
            func paste(_ sender: Any?) {}
            func delete(_ sender: Any?) {}
            func selectAll(_ sender: Any?) {}
            func selectPaletteStyle(_ sender: Any?) {}
            func zoomIn(_ sender: Any?) {}
            func zoomOut(_ sender: Any?) {}
            func resetZoom(_ sender: Any?) {}
            func toggleDarkMode(_ sender: Any?) {}
            func showFontPanel(_ sender: Any?) {}
            func showWelcome(_ sender: Any?) {}
        }
        let target = Target()
        let menu = MainMenu.build(target: target)
        let editMenu = try XCTUnwrap(menu.items.first { $0.submenu?.title == "Edit" }?.submenu)
        let titles = ["Undo", "Redo", "Cut", "Copy", "Paste", "Delete", "Select All"]
        for title in titles {
            let item = try XCTUnwrap(editMenu.items.first { $0.title == title })
            XCTAssertNil(item.target, "\(title) must go through the responder chain")
        }
    }

    /// The canvas answers the same selectors for the diagram.
    func testCanvasViewHandlesTheEditingCommands() {
        let document = DiagramDocument.newDocument()
        let view = document.windowController.canvas
        for selector in [#selector(NSText.copy(_:)), #selector(NSText.cut(_:)),
                         #selector(NSText.paste(_:)), #selector(NSText.delete(_:))] {
            XCTAssertTrue(view.responds(to: selector), "the canvas must handle \(selector)")
        }
    }

    /// Text copied in one property sheet can be pasted into the field of another one.
    func testCopyAndPasteTextBetweenSheets() throws {
        let (firstDocument, firstSheet) = makeSheet()
        let source = try XCTUnwrap(firstSheet.textView(for: .name))
        source.string = "Copied text"
        firstSheet.window?.makeFirstResponder(source)
        source.selectAll(nil)
        source.copy(nil)

        // A second document with its own sheet.
        let secondDocument = DiagramDocument.newDocument()
        let node = ClassNode()
        node.setName("B")
        node.moveTo(Point(x: 10, y: 10))
        secondDocument.session.diagram.addRootNode(node)
        secondDocument.session.canvasController.setSelection(node)
        let secondSheet = try XCTUnwrap(PropertySheetWindow(
            controller: secondDocument.session.canvasController, onChange: {}))
        let destination = try XCTUnwrap(secondSheet.textView(for: .name))
        secondSheet.window?.makeFirstResponder(destination)
        destination.setSelectedRange(NSRange(location: 0, length: destination.string.count))
        destination.paste(nil)

        XCTAssertEqual("Copied text", destination.string)
        secondSheet.commitPendingChanges()
        XCTAssertEqual("Copied text", node.name,
                       "the pasted text must reach the element, not the diagram clipboard")
        XCTAssertTrue(firstDocument.session.diagram.rootNodes.count == 1)
    }

    /// A single-line field of a line diagram takes pasted text as well.
    func testPasteIntoSingleLineField() throws {
        let document = DiagramDocument.newDocument()
        let first = ClassNode()
        first.setName("A")
        first.moveTo(Point(x: 10, y: 10))
        let second = ClassNode()
        second.setName("B")
        second.moveTo(Point(x: 10, y: 200))
        document.session.diagram.addRootNode(first)
        document.session.diagram.addRootNode(second)
        let edge = DependencyEdge()
        edge.connect(first, second)
        document.session.diagram.addEdge(edge)
        document.session.canvasController.setSelection(edge)
        let sheet = try XCTUnwrap(PropertySheetWindow(
            controller: document.session.canvasController, onChange: {}))

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("label from the clipboard", forType: .string)

        let field = try XCTUnwrap(sheet.textField(for: .middleLabel))
        sheet.window?.makeFirstResponder(field)
        field.currentEditor()?.paste(nil)
        sheet.commitPendingChanges()

        XCTAssertEqual("label from the clipboard", (edge as? DependencyEdge)?.middleLabel)
    }
}
