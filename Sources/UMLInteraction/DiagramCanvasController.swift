//
//  DiagramCanvasController.swift
//  UMLExpress
//
//  Port of the interaction logic of org.jetuml.gui.DiagramCanvas (JetUML 3.10, GPL-3,
//  (C) McGill University).
//
//  The original is a JavaFX `Canvas` subclass that mixes event handling with drawing.
//  This port keeps only the interaction logic, driven by synthetic input events, so it
//  can be tested without a UI and later wrapped by an AppKit view (M7).
//

import UMLGeometry
import UMLModel
import UMLOperations
import UMLRendering
import UMLValidation

/// What a drag gesture currently does.
public enum DragMode {
    case none
    case move
    case lasso
    case rubberband
}

/// The state of the modifier keys of an input event.
public struct InputModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// The platform's "add to selection" modifier (Ctrl in JetUML).
    public static let control = InputModifiers(rawValue: 1 << 0)
    /// The secondary mouse button.
    public static let secondary = InputModifiers(rawValue: 1 << 1)
}

/// Drives the interaction with a diagram: tool selection, selection, dragging, lasso,
/// rubber-band edge creation, deletion, undo/redo and clipboard operations.
public final class DiagramCanvasController {

    /// The distance below which a rubber band does not create an edge.
    static let connectThreshold = 3.0

    /// The grid increment used when aligning a move.
    static let gridSize = 10

    private let builder: DiagramBuilder
    private let validator: any DiagramValidator
    let processor = DiagramOperationProcessor()

    private var selected: [any DiagramElement] = []
    private var dragMode: DragMode = .none
    private var lastMousePoint = Point(x: 0, y: 0)
    private var mouseDownPoint = Point(x: 0, y: 0)
    private var rubberband: Line?
    private var lasso: Rectangle?
    private let moveTracker: MoveTracker

    private var canvasWidth: Int
    private var canvasHeight: Int

    /// The prototype of the tool currently selected in the tool palette, if any.
    public private(set) var creationPrototype: (any DiagramElement)?

    /// Called when the controller wants to report a problem to the user.
    public var notificationHandler: ((String) -> Void)?

    /// Called whenever the diagram or the selection changed, so the view can repaint.
    public var changeHandler: (() -> Void)?

    public init(builder: DiagramBuilder, validator: any DiagramValidator,
                width: Int = 1000, height: Int = 1000) {
        self.builder = builder
        self.validator = validator
        self.canvasWidth = width
        self.canvasHeight = height
        self.moveTracker = MoveTracker { builder.renderer.boundsOf($0) }
        builder.setCanvasDimension(Dimension(width: width, height: height))
    }

    // MARK: - State

    /// The size of the drawing area, in canvas points.
    ///
    /// Elements are kept inside it (the original JetUML canvas has a fixed size too), so
    /// the view must keep it in sync with the area it actually shows.
    public var canvasDimension: Dimension { Dimension(width: canvasWidth, height: canvasHeight) }

    /// Sets the size of the drawing area; the view calls this when its visible area
    /// changes, otherwise shapes could not be dragged into the right or bottom part of a
    /// large window.
    public func setCanvasDimension(_ dimension: Dimension) {
        guard dimension.width != canvasWidth || dimension.height != canvasHeight else {
            return
        }
        canvasWidth = dimension.width
        canvasHeight = dimension.height
        builder.setCanvasDimension(dimension)
    }

    /// The diagram being edited.
    public var diagram: Diagram { builder.diagram }

    /// The renderer of the diagram.
    public var renderer: any DiagramViewRendererBridge { builder.renderer }

    /// The elements currently selected, most recently selected last.
    public var selection: [any DiagramElement] { selected }

    /// The element selected last, if any.
    public var lastSelected: (any DiagramElement)? { selected.last }

    /// The current drag mode, for the view to draw the rubber band or lasso.
    public var currentDragMode: DragMode { dragMode }

    /// The rubber band line while an edge is being drawn.
    public var rubberbandLine: Line? { rubberband }

    /// The lasso rectangle while elements are being selected.
    public var lassoRectangle: Rectangle? { lasso }

    /// The tool to use for the next interaction; `nil` means the selection tool.
    public func selectTool(_ prototype: (any DiagramElement)?) {
        creationPrototype = prototype
        changed()
    }

    /// True if the diagram has unsaved changes.
    public var hasUnsavedChanges: Bool { processor.hasUnsavedOperations() }

    /// True if there is an operation to undo.
    public var canUndo: Bool { processor.canUndo }

    /// True if there is an operation to redo.
    public var canRedo: Bool { processor.canRedo }

    /// Notifies the controller that the diagram was saved.
    public func diagramSaved() {
        processor.diagramSaved()
        changed()
    }

    /// Drops selected elements that are no longer in the diagram.
    public func synchronizeSelectionModel() {
        selected.removeAll { !diagram.contains($0) }
        changed()
    }

    // MARK: - Input

    /// Handles a mouse press.
    public func mousePressed(at point: Point, modifiers: InputModifiers = []) {
        if modifiers.contains(.secondary) {
            // The tool palette popup is a UI concern; the controller only records it.
            return
        }
        handleSingleClick(at: point, modifiers: modifiers)
        lastMousePoint = point
        mouseDownPoint = point
        changed()
    }

    /// Handles a double click.
    public func mouseDoubleClicked(at point: Point) {
        handleSelection(at: point, modifiers: [])
    }

    /// Handles a mouse drag.
    public func mouseDragged(to point: Point, modifiers: InputModifiers = []) {
        switch dragMode {
        case .move where !selected.isEmpty:
            moveSelection(to: point)
        case .lasso:
            lastMousePoint = point
            if !modifiers.contains(.control) {
                clearSelection()
            }
            lasso = Self.rectangle(from: mouseDownPoint, to: point)
            selectInLasso()
        case .rubberband:
            lastMousePoint = point
            rubberband = Line(point1: mouseDownPoint, point2: point)
        case .move, .none:
            break
        }
        changed()
    }

    /// Handles a mouse release.
    public func mouseReleased(at point: Point) {
        switch dragMode {
        case .rubberband:
            releaseRubberband(at: point)
        case .move:
            alignMoveToGrid()
            releaseMove()
        case .lasso:
            lasso = nil
        case .none:
            break
        }
        dragMode = .none
        changed()
    }

    // MARK: - Commands

    /// Removes the selected elements.
    public func removeSelected() {
        guard !selected.isEmpty else {
            return
        }
        let operation = builder.createRemoveElementsOperation(selected)
        processor.executeNewOperation(operation)
        clearSelection()
        changed()
    }

    /// Undoes the last operation.
    public func undo() {
        guard processor.canUndo else {
            return
        }
        processor.undoLastExecutedOperation()
        synchronizeSelectionModel()
        changed()
    }

    /// Redoes the last undone operation.
    public func redo() {
        guard processor.canRedo else {
            return
        }
        processor.redoLastUndoneOperation()
        synchronizeSelectionModel()
        changed()
    }

    /// Selects every element of the diagram.
    public func selectAll() {
        selected = diagram.allNodes.map { $0 as any DiagramElement } + diagram.edges
        changed()
    }

    /// Clears the selection.
    public func clearSelection() {
        selected.removeAll()
        changed()
    }

    /// Selects the given elements.
    public func setSelection(_ elements: [any DiagramElement]) {
        selected.removeAll()
        for element in elements {
            addToSelection(element)
        }
        changed()
    }

    /// Selects a single element.
    public func setSelection(_ element: any DiagramElement) {
        selected.removeAll()
        addToSelection(element)
        changed()
    }

    // MARK: - Mouse handlers

    private func handleSingleClick(at point: Point, modifiers: InputModifiers) {
        let element = elementAt(point)
        guard let tool = creationPrototype else {
            handleSelection(at: point, modifiers: modifiers)
            return
        }
        if tool is any Node {
            if Self.creationEnabled(element, tool) {
                handleNodeCreation(at: point, tool: tool)
            } else {
                handleSelection(at: point, modifiers: modifiers)
            }
        } else if tool is any Edge {
            handleEdgeStart(at: point)
        }
    }

    /// Node creation is not allowed on top of an element, except on a package node or for
    /// field nodes.
    static func creationEnabled(_ element: (any DiagramElement)?, _ tool: any DiagramElement) -> Bool {
        guard let element else {
            return true
        }
        if element is PackageNode || tool is FieldNode {
            return true
        }
        return false
    }

    private func handleNodeCreation(at point: Point, tool: any DiagramElement) {
        guard let prototype = tool as? any Node else {
            return
        }
        let newNode = prototype.copy()
        let snapped = GridUtils.snapped(point)
        processor.executeNewOperation(
            builder.createAddNodeOperation(newNode, Point(x: snapped.x, y: snapped.y)))

        if let violation = validator.validate() {
            processor.undoLastExecutedOperation()
            notificationHandler?(violation.description)
            handleSelection(at: point, modifiers: [])
        } else {
            setSelection(newNode)
            diagram.placeOnTop(newNode)
        }
    }

    private func handleEdgeStart(at point: Point) {
        if let element = elementAt(point), element is any Node {
            dragMode = .rubberband
        }
    }

    private func handleSelection(at point: Point, modifiers: InputModifiers) {
        guard let element = elementAt(point) else {
            if !modifiers.contains(.control) {
                clearSelection()
            }
            dragMode = .lasso
            return
        }
        if modifiers.contains(.control) {
            if contains(element) {
                removeFromSelection(element)
            } else {
                addToSelection(element)
            }
        } else if !contains(element) {
            setSelection(element)
        }
        // Reorder the selected nodes so that they appear on top.
        for node in selectedNodes() {
            diagram.placeOnTop(node)
        }
        dragMode = .move
        moveTracker.start(selected)
    }

    /// The edge or node at a point.
    func elementAt(_ point: Point) -> (any DiagramElement)? {
        if let edge = renderer.edgeAt(point) {
            return edge
        }
        return renderer.selectableNodeAt(point)
    }

    // MARK: - Rubber band, movement, lasso

    private func releaseRubberband(at point: Point) {
        guard let prototype = creationPrototype as? any Edge else {
            dragMode = .none
            return
        }
        let newEdge = prototype.copy()
        if point.distance(to: mouseDownPoint) > Self.connectThreshold {
            processor.executeNewOperation(
                builder.createAddEdgeOperation(newEdge, mouseDownPoint, point))
            if let violation = validator.validate() {
                processor.undoLastExecutedOperation()
                notificationHandler?(violation.description)
            } else {
                setSelection(newEdge)
            }
        }
        rubberband = nil
    }

    private func releaseMove() {
        let operation = moveTracker.stop()
        if !operation.isEmpty {
            processor.storeAlreadyExecutedOperation(operation)
        }
    }

    /// Moves the selection by the delta of the drag, keeping it inside the canvas.
    private func moveSelection(to point: Point) {
        precondition(!selected.isEmpty)
        let dx = point.x - lastMousePoint.x
        let dy = point.y - lastMousePoint.y
        for node in selectedNodes() {
            node.translate(dx, dy)
        }
        let bounds = renderer.boundsIncludingParents(selected)
        let dxCorrection = max(-bounds.x, 0) + min(canvasWidth - bounds.maxX, 0)
        let dyCorrection = max(-bounds.y, 0) + min(canvasHeight - bounds.maxY, 0)
        if dxCorrection != 0 || dyCorrection != 0 {
            for node in selectedNodes() {
                node.translate(dxCorrection, dyCorrection)
            }
        }
        lastMousePoint = point
    }

    /// Aligns the moved selection with the grid.
    private func alignMoveToGrid() {
        guard let firstSelected = selectedNodes().first else {
            return
        }
        let entireBounds = renderer.boundsIncludingParents(selected)
        let bounds = renderer.boundsOf(firstSelected)
        let snappedPosition = GridUtils.snapped(bounds)
        var dx = snappedPosition.x - bounds.x
        var dy = snappedPosition.y - bounds.y

        if entireBounds.maxX + dx > canvasWidth {
            dx -= Self.gridSize
        } else if entireBounds.x + dx <= 0 {
            dx += Self.gridSize
        }
        if entireBounds.maxY + dy > canvasHeight {
            dy -= Self.gridSize
        } else if entireBounds.y + dy <= 0 {
            dy += Self.gridSize
        }
        for node in selectedNodes() {
            node.translate(dx, dy)
        }
    }

    /// Selects the elements that intersect the lasso.
    private func selectInLasso() {
        guard let lasso else {
            return
        }
        for node in diagram.allNodes {
            if renderer.boundsOf(node).contains(lasso.center()) || lasso.contains(renderer.boundsOf(node)) {
                addToSelectionInternally(node)
            }
        }
        for edge in diagram.edges {
            if lasso.contains(renderer.boundsOf(edge)) {
                addToSelectionInternally(edge)
            }
        }
    }

    // MARK: - Selection helpers

    private static func rectangle(from start: Point, to end: Point) -> Rectangle {
        Rectangle(x: min(start.x, end.x), y: min(start.y, end.y),
                  width: abs(start.x - end.x), height: abs(start.y - end.y))
    }

    private func selectedNodes() -> [any Node] {
        selected.compactMap { $0 as? any Node }
    }

    private func contains(_ element: any DiagramElement) -> Bool {
        selected.contains { $0 === element }
    }

    private func addToSelection(_ element: any DiagramElement) {
        addToSelectionInternally(element)
        changed()
    }

    /// Adds the element, unless one of its ancestors is already selected; also drops
    /// descendants when a parent is added.
    private func addToSelectionInternally(_ element: any DiagramElement) {
        guard !containsParent(element) else {
            return
        }
        selected.removeAll { $0 === element }
        selected.append(element)
        let toRemove = selected.filter { containsParent($0) }
        selected.removeAll { candidate in toRemove.contains { $0 === candidate } }
    }

    /// True if any ancestor of the element is selected.
    private func containsParent(_ element: any DiagramElement) -> Bool {
        guard let node = element as? any Node else {
            return false
        }
        guard node.hasParent else {
            return false
        }
        let parent = node.getParent()
        if contains(parent) {
            return true
        }
        return containsParent(parent)
    }

    private func removeFromSelection(_ element: any DiagramElement) {
        selected.removeAll { $0 === element }
        changed()
    }

    func changed() {
        changeHandler?()
    }

    // MARK: - Clipboard

    /// The clipboard used for copy/paste between diagrams.
    ///
    /// All the documents share one clipboard, so elements can be copied in one window and
    /// pasted into another window that shows a diagram of the same type.
    public var clipboard: CanvasClipboard { CanvasClipboard.shared }

    /// Copies the selection to the clipboard.
    public func copy() {
        guard !selected.isEmpty else {
            return
        }
        clipboard.copy(selected, from: diagram.diagramKind)
    }

    /// Cuts the selection: copies it and removes it from the diagram.
    public func cut() {
        guard !selected.isEmpty else {
            return
        }
        clipboard.copy(selected, from: diagram.diagramKind)
        removeSelected()
    }

    /// True if the clipboard holds content that this diagram can take.
    public var canPaste: Bool {
        clipboard.canPaste(into: diagram.diagramKind)
    }

    /// Paste the clipboard content into the diagram.
    ///
    /// Elements copied from a diagram of another type are refused: the two diagram kinds do
    /// not share their elements, so the user is told instead of silently getting nothing.
    public func paste() {
        if clipboard.isEmpty {
            return
        }
        guard clipboard.canPaste(into: diagram.diagramKind) else {
            let source = clipboard.sourceKind?.name ?? "another type of"
            notificationHandler?(
                "The clipboard holds elements of a \(source) diagram. They can only be "
                + "pasted into a diagram of the same type.")
            return
        }
        guard clipboard.validPaste(diagram) else {
            return
        }
        let elements = clipboard.elements()
        if clipboard.overlapsWithElementOf(diagram, renderer: renderer) {
            for element in elements {
                if let node = element as? any Node {
                    node.translate(Self.gridSize, Self.gridSize)
                }
            }
        }
        processor.executeNewOperation(builder.createAddElementsOperation(elements))
        setSelection(elements)
        // Keep the pasted elements on the clipboard, so the next paste copies those.
        clipboard.copy(elements, from: diagram.diagramKind)
    }
}

/// Computes the result of a move gesture (port of `org.jetuml.gui.MoveTracker`).
public final class MoveTracker {

    private var trackedNodes: [any Node] = []
    private var originalBounds: [Rectangle] = []
    private let boundsCalculator: (any Node) -> Rectangle

    public init(_ boundsCalculator: @escaping (any Node) -> Rectangle) {
        self.boundsCalculator = boundsCalculator
    }

    /// Records the nodes and their current bounds.
    public func start(_ elements: [any DiagramElement]) {
        trackedNodes.removeAll()
        originalBounds.removeAll()
        for element in elements {
            guard let node = element as? any Node else { continue }
            trackedNodes.append(node)
            originalBounds.append(boundsCalculator(node))
        }
    }

    /// The compound move operation between `start` and `stop`, empty if nothing moved.
    public func stop() -> CompoundOperation {
        let operation = CompoundOperation()
        for (index, node) in trackedNodes.enumerated() {
            let current = boundsCalculator(node)
            let dy = current.y - originalBounds[index].y
            let dx = current.x - originalBounds[index].x
            if dx != 0 || dy != 0 {
                operation.add(DiagramBuilder.createMoveNodeOperation(node, dx, dy))
            }
        }
        return operation
    }
}
