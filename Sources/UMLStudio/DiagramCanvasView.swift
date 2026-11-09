//
//  DiagramCanvasView.swift
//  UMLExpress
//
//  Port of org.jetuml.gui.DiagramCanvas (the view part) on top of AppKit
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  The drawing and interaction logic live in `ClassDiagramRenderer` and
//  `DiagramCanvasController`; this view only translates AppKit events and blits the
//  context into the window.
//

import AppKit
import UMLGeometry
import UMLInteraction
import UMLModel
import UMLRendering

/// The view that shows a diagram and forwards input to the canvas controller.
@MainActor
public final class DiagramCanvasView: NSView {

    /// The controller that owns the diagram state.
    public let controller: DiagramCanvasController

    /// The empty space kept around the diagram, so that shapes can be dragged outwards.
    static let canvasMargin = 400

    /// The controller is created by the caller; the view never mutates the diagram
    /// directly.
    public init(controller: DiagramCanvasController) {
        self.controller = controller
        super.init(frame: NSRect(x: 0, y: 0,
                                 width: CGFloat(controller.canvasDimension.width),
                                 height: CGFloat(controller.canvasDimension.height)))
        controller.changeHandler = { [weak self] in
            self?.updateCanvasExtent()
            self?.needsDisplay = true
        }
        controller.notificationHandler = { [weak self] message in
            self?.presentNotification(message)
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("DiagramCanvasView is created in code")
    }

    /// Coordinates grow downwards, as in the JavaFX canvas.
    public override var isFlipped: Bool { true }

    // MARK: - Extent

    /// Grows the drawing area to the visible area of the window and to the diagram with a
    /// margin, and tells the controller about it.
    ///
    /// The controller keeps elements inside the canvas (`canvasWidth`/`canvasHeight`), and
    /// AppKit does not resize the document view of a scroll view, so a maximised window
    /// would leave the right half of the screen outside the drawing area: shapes could not
    /// be dragged past the middle of the view.
    public func updateCanvasExtent() {
        let visible = enclosingScrollView?.contentView.bounds.size ?? bounds.size
        let content = controller.renderer.diagramBounds()
        let contentWidth = CGFloat(content.maxX) + CGFloat(Self.canvasMargin)
        let contentHeight = CGFloat(content.maxY) + CGFloat(Self.canvasMargin)
        let width = Int(max(visible.width, contentWidth * zoom).rounded())
        let height = Int(max(visible.height, contentHeight * zoom).rounded())
        if abs(Int(frame.width) - width) >= 1 || abs(Int(frame.height) - height) >= 1 {
            setFrameSize(NSSize(width: width, height: height))
            needsDisplay = true
        }
        // The controller works in canvas coordinates, which the zoom does not change.
        controller.setCanvasDimension(
            Dimension(width: Int((CGFloat(width) / zoom).rounded()),
                      height: Int((CGFloat(height) / zoom).rounded())))
    }

    public override var acceptsFirstResponder: Bool { true }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let cgContext = NSGraphicsContext.current?.cgContext else {
            return
        }
        // Background of the canvas area.
        cgContext.saveGState()
        cgContext.setFillColor(ColorScheme.current.background.cgColor)
        cgContext.fill(bounds)
        cgContext.restoreGState()

        // Everything is drawn in canvas coordinates and magnified by the zoom factor.
        cgContext.saveGState()
        cgContext.scaleBy(x: zoom, y: zoom)
        let canvasSize = CGSize(width: bounds.width / zoom, height: bounds.height / zoom)

        // The background grid, as in the original canvas.
        cgContext.saveGState()
        cgContext.setStrokeColor(ColorScheme.current.grid.cgColor)
        cgContext.setLineWidth(1 / zoom)
        let gridSize: CGFloat = 10
        var x: CGFloat = 0
        while x <= canvasSize.width {
            cgContext.move(to: CGPoint(x: x, y: 0))
            cgContext.addLine(to: CGPoint(x: x, y: canvasSize.height))
            x += gridSize
        }
        var y: CGFloat = 0
        while y <= canvasSize.height {
            cgContext.move(to: CGPoint(x: 0, y: y))
            cgContext.addLine(to: CGPoint(x: canvasSize.width, y: y))
            y += gridSize
        }
        cgContext.strokePath()
        cgContext.restoreGState()

        let context = CGRenderingContext(cgContext)
        controller.renderer.drawDiagram(context)

        drawSelection(in: cgContext)
        drawTransientOverlays(in: cgContext)
        cgContext.restoreGState()
    }

    // MARK: - Selection

    /// The side of a selection handle, in points.
    static let handleSize: CGFloat = 7

    // MARK: - Zoom

    /// The zoom factor applied when drawing, 1.0 by default (as in the original).
    public private(set) var zoom: CGFloat = 1.0

    /// The factor by which zoom in and zoom out change the zoom.
    static let zoomMultiplier: CGFloat = 1.25

    /// The smallest and largest zoom factors (two steps in each direction, as in the
    /// original).
    static let zoomMinimum: CGFloat = 1.0 / (zoomMultiplier * zoomMultiplier)
    static let zoomMaximum: CGFloat = zoomMultiplier * zoomMultiplier

    /// Zooms in by one step.
    public func zoomIn() {
        setZoom(min(zoom * Self.zoomMultiplier, Self.zoomMaximum))
    }

    /// Zooms out by one step.
    public func zoomOut() {
        setZoom(max(zoom / Self.zoomMultiplier, Self.zoomMinimum))
    }

    /// Restores the default zoom.
    public func resetZoom() {
        setZoom(1.0)
    }

    /// Applies a zoom factor, clamped to the supported range.
    public func setZoom(_ newValue: CGFloat) {
        let clamped = min(max(newValue, Self.zoomMinimum), Self.zoomMaximum)
        guard abs(clamped - zoom) > 0.0001 else {
            return
        }
        zoom = clamped
        updateCanvasExtent()
        needsDisplay = true
    }

    /// Draws the selection: an outline with corner handles for shapes, end handles for
    /// connecting lines.
    ///
    /// Without this the canvas gives no feedback at all: the diagram is painted the same
    /// way whether an element is selected or not.
    private func drawSelection(in context: CGContext) {
        let selection = controller.selection
        guard !selection.isEmpty else {
            return
        }
        let shapes = selection.compactMap { $0 as? any Node }
        let connections = selection.compactMap { $0 as? any Edge }

        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        for node in shapes {
            let bounds = controller.renderer.boundsOf(node)
            context.stroke(CGRect(x: CGFloat(bounds.x) - 1.5, y: CGFloat(bounds.y) - 1.5,
                                  width: CGFloat(bounds.width) + 3,
                                  height: CGFloat(bounds.height) + 3))
        }
        context.restoreGState()

        // A line has no meaningful corners: it gets a handle at each end instead, and no
        // outline at all.
        var handles: [CGPoint] = []
        for node in shapes {
            let bounds = controller.renderer.boundsOf(node)
            handles.append(CGPoint(x: CGFloat(bounds.x), y: CGFloat(bounds.y)))
            handles.append(CGPoint(x: CGFloat(bounds.maxX), y: CGFloat(bounds.y)))
            handles.append(CGPoint(x: CGFloat(bounds.x), y: CGFloat(bounds.maxY)))
            handles.append(CGPoint(x: CGFloat(bounds.maxX), y: CGFloat(bounds.maxY)))
        }
        for edge in connections {
            if let ends = controller.renderer.edgeEndPoints(edge) {
                handles.append(CGPoint(x: CGFloat(ends.0.x), y: CGFloat(ends.0.y)))
                handles.append(CGPoint(x: CGFloat(ends.1.x), y: CGFloat(ends.1.y)))
            } else {
                let bounds = controller.renderer.boundsOf(edge)
                handles.append(CGPoint(x: CGFloat(bounds.x), y: CGFloat(bounds.y)))
                handles.append(CGPoint(x: CGFloat(bounds.maxX), y: CGFloat(bounds.maxY)))
            }
        }
        drawHandles(handles, in: context)
    }

    /// Draws a square handle at each of the given points.
    private func drawHandles(_ points: [CGPoint], in context: CGContext) {
        guard !points.isEmpty else {
            return
        }
        let size = Self.handleSize
        context.saveGState()
        for point in points {
            let rect = CGRect(x: point.x - size / 2, y: point.y - size / 2,
                              width: size, height: size)
            context.setFillColor(NSColor.controlAccentColor.cgColor)
            context.fill(rect)
            context.setStrokeColor(ColorScheme.current.background.cgColor)
            context.setLineWidth(1)
            context.stroke(rect)
        }
        context.restoreGState()
    }

    /// Draws the rubber band or the lasso while they are being dragged.
    private func drawTransientOverlays(in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [4, 3])
        if let rubberband = controller.rubberbandLine {
            context.move(to: CGPoint(x: rubberband.x1, y: rubberband.y1))
            context.addLine(to: CGPoint(x: rubberband.x2, y: rubberband.y2))
            context.strokePath()
        }
        if let lasso = controller.lassoRectangle {
            context.stroke(CGRect(x: lasso.x, y: lasso.y, width: lasso.width, height: lasso.height))
        }
        context.restoreGState()
    }

    // MARK: - Mouse input

    public override func mouseDragged(with event: NSEvent) {
        controller.mouseDragged(to: point(of: event), modifiers: Self.modifiers(of: event))
    }

    public override func mouseUp(with event: NSEvent) {
        controller.mouseReleased(at: point(of: event))
    }

    public override func rightMouseDown(with event: NSEvent) {
        // The tool palette popup is presented by the window controller.
        nextResponder?.rightMouseDown(with: event)
    }

    /// A single click is forwarded to the controller (tool use, selection, dragging); a
    /// double click opens the property sheet.
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount > 1 {
            onDoubleClick?()
            return
        }
        controller.mousePressed(at: point(of: event), modifiers: Self.modifiers(of: event))
    }

    /// Called on a double click; the window controller presents the property sheet.
    public var onDoubleClick: (() -> Void)?

    // MARK: - Keyboard input

    public override func keyDown(with event: NSEvent) {
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 51, 117: // delete, forward delete
            controller.removeSelected()
        case 0 where command: // Cmd-A
            controller.selectAll()
        default:
            switch event.charactersIgnoringModifiers {
            case "z" where command:
                if event.modifierFlags.contains(.shift) {
                    controller.redo()
                } else {
                    controller.undo()
                }
            case "c" where command:
                controller.copy()
            case "x" where command:
                controller.cut()
            case "v" where command:
                controller.paste()
            default:
                super.keyDown(with: event)
            }
        }
    }

    // MARK: - Messages

    /// Shows a transient error message for a rejected operation.
    private func presentNotification(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Invalid operation"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    // MARK: - Helpers

    private func point(of event: NSEvent) -> Point {
        let location = canvasLocation(of: event.locationInWindow)
        return Point(x: Int(location.x.rounded()), y: Int(location.y.rounded()))
    }

    /// Converts a window coordinate into the canvas coordinate system.
    ///
    /// The view is flipped, so the y axis is mirrored relative to the window. When the view
    /// is not installed in a window (as in unit tests) the coordinates are taken as canvas
    /// coordinates, which keeps the event logic testable without a window server.
    func canvasLocation(of locationInWindow: NSPoint) -> NSPoint {
        guard window != nil else {
            return locationInWindow
        }
        let point = convert(locationInWindow, from: nil)
        // The view is magnified by the zoom factor; the controller works in canvas points.
        return zoom == 1 ? point : NSPoint(x: point.x / zoom, y: point.y / zoom)
    }

    private static func modifiers(of event: NSEvent) -> InputModifiers {
        // JetUML uses Ctrl to extend the selection; on macOS the command key is the
        // conventional choice.
        event.modifierFlags.contains(.command) ? .control : []
    }
}

/// A scroll view that keeps its document (the canvas) as large as the visible area.
@MainActor
final class CanvasScrollView: NSScrollView {

    override func layout() {
        super.layout()
        (documentView as? DiagramCanvasView)?.updateCanvasExtent()
    }
}

extension DiagramCanvasController {
    /// The renderer, typed for the view.
    var viewRenderer: any DiagramViewRendererBridge { renderer }

    /// Draws the diagram into the given context.
    public func drawDiagram(in context: any RenderingContext) {
        renderer.drawDiagram(context)
    }
}
