//
//  StateObjectUseCaseRenderers.swift
//  UMLExpress
//
//  Port of the node and edge renderers of the state, object and use case diagrams
//  (JetUML 3.10, GPL-3, (C) McGill University):
//  CircularStateNodeRenderer, StateNodeRenderer, ObjectNodeRenderer, FieldNodeRenderer,
//  ActorNodeRenderer, UseCaseNodeRenderer, LabeledStraightEdgeRenderer,
//  StateTransitionEdgeRenderer, ObjectReferenceEdgeRenderer and the use case edge
//  renderers.
//

import CoreGraphics
import Foundation
import UMLGeometry
import UMLModel

// MARK: - State diagram nodes

/// Renders an initial or final state node.
public final class CircularStateNodeRenderer: AbstractNodeRenderer {

    private static let diameter = 20
    private let isFinalState: Bool

    public init(_ parent: any RenderingContextOwner, final: Bool) {
        self.isFinalState = final
        super.init(parent)
    }

    public override func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        Dimension(width: Self.diameter, height: Self.diameter)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        let bounds = self.bounds(element)
        if isFinalState {
            context.drawOval(bounds.x, bounds.y, width: Self.diameter, height: Self.diameter,
                             fill: RGBAColor.white, stroke: ColorScheme.current.strokeColor,
                             hasShadow: ColorScheme.current.hasShadows)
            let innerDiameter = Self.diameter / 2
            context.drawOval(bounds.x + innerDiameter / 2, bounds.y + innerDiameter / 2,
                             width: innerDiameter, height: innerDiameter,
                             fill: RGBAColor.black, stroke: RGBAColor.black, hasShadow: false)
        } else {
            context.drawOval(bounds.x, bounds.y, width: Self.diameter, height: Self.diameter,
                             fill: RGBAColor.black, stroke: ColorScheme.current.strokeColor,
                             hasShadow: ColorScheme.current.hasShadows)
        }
    }

    public override func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        GeomUtils.intersectCircle(bounds(node), direction)
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        Rectangle(x: node.position.x, y: node.position.y, width: Self.diameter, height: Self.diameter)
    }
}

/// Renders a state node as a rounded rectangle with a centred name.
public final class StateNodeRenderer: AbstractNodeRenderer {

    private static let defaultWidth = 80
    private static let defaultHeight = 60
    private static let padding = 15
    private static let labelRenderer = StringRenderer(.center)

    public override func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        Dimension(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        let bounds = self.bounds(element)
        context.drawRoundedRectangle(bounds, fill: ColorScheme.current.fill,
                                     stroke: ColorScheme.current.strokeColor,
                                     hasShadow: ColorScheme.current.hasShadows)
        let name = (element as? StateNode)?.name ?? ""
        Self.labelRenderer.draw(name,
                                in: bounds.centerSlice(Self.labelRenderer.dimension(of: name).height),
                                with: context)
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        let name = (node as? StateNode)?.name ?? ""
        let text = Self.labelRenderer.dimension(of: name)
        return Rectangle(x: node.position.x, y: node.position.y,
                         width: max(text.width + Self.padding, Self.defaultWidth),
                         height: max(text.height + Self.padding, Self.defaultHeight))
    }

    public override func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        GeomUtils.intersectRoundedRectangle(bounds(node), direction)
    }
}

// MARK: - Object diagram nodes

/// Renders an object node: a rectangle with an underlined name and its fields.
public final class ObjectNodeRenderer: AbstractNodeRenderer {

    static let defaultWidth = 80
    static let defaultHeight = 60
    private static let textHorizontalMargin = 10
    static let xGap = 5
    static let yGap = 5
    private static let labelRenderer = StringRenderer(.center, .bold, .underlined)

    public override func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        Dimension(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let node = element as? ObjectNode else {
            preconditionFailure("not an object node")
        }
        let bounds = self.bounds(element)
        let topRectangle = Self.topRectangle(node)
        context.drawRectangle(bounds, fill: ColorScheme.current.fill,
                              stroke: ColorScheme.current.strokeColor,
                              hasShadow: ColorScheme.current.hasShadows)
        if !node.children.isEmpty {
            context.strokeLine(bounds.x, topRectangle.maxY, bounds.maxX, topRectangle.maxY,
                               ColorScheme.current.strokeColor, .solid)
        }
        let top = Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: topRectangle.height)
        Self.labelRenderer.draw(node.name, in: top.centerSlice(Self.labelRenderer.lineHeight), with: context)
    }

    static func topRectangle(_ node: any Node) -> Rectangle {
        let name = (node as? ObjectNode)?.name ?? ""
        let text = labelRenderer.dimension(of: name)
        return Rectangle(x: node.position.x, y: node.position.y,
                         width: max(defaultWidth, text.width + textHorizontalMargin),
                         height: max(defaultHeight, text.height))
    }

    /// The x position of the "name = value" split.
    public static func splitPosition(_ node: ObjectNode) -> Int {
        var leftWidth = 0
        for field in node.children {
            leftWidth = max(leftWidth, FieldNodeRenderer.leftWidth(field))
        }
        return node.position.x + leftWidth + xGap
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        guard let node = node as? ObjectNode else {
            preconditionFailure("not an object node")
        }
        let top = Self.topRectangle(node)
        var leftWidth = 0
        var rightWidth = 0
        var height = node.children.isEmpty ? 0 : Self.yGap
        for field in node.children {
            height += FieldNodeRenderer.height(field) + Self.yGap
            leftWidth = max(leftWidth, FieldNodeRenderer.leftWidth(field))
            rightWidth = max(rightWidth, FieldNodeRenderer.rightWidth(field))
        }
        var width = max(top.width, leftWidth + rightWidth + 2 * Self.xGap)
        width = GridUtils.toMultiple(width)
        return Rectangle(x: top.x, y: top.y, width: width,
                         height: GridUtils.toMultiple(top.height + height))
    }

    /// The y position of a child field.
    public static func yPosition(_ node: any Node, _ field: any Node) -> Int {
        guard let object = node as? ObjectNode else {
            return 0
        }
        let top = topRectangle(object)
        var yPosition = top.maxY + yGap
        for child in object.children {
            yPosition += yGap
            if child === field {
                return yPosition
            }
            yPosition += FieldNodeRenderer.height(child)
        }
        return yPosition
    }
}

/// Renders a field node: a "name = value" line inside its object.
public final class FieldNodeRenderer: AbstractNodeRenderer {

    private static let equals = " = "
    /// The sample field shown in the tool palette (`ICON_LABEL` in the original).
    private static let iconLabel = "x = y"
    private static let defaultWidth = 60
    static let defaultHeight = 20
    private static let xGap = 5
    private static let valueViewer = StringRenderer(.left)
    private static let nameViewer = StringRenderer(.left)
    private static let equalsViewer = StringRenderer(.center)

    public override func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        Dimension(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    /// A field cannot be drawn without its parent object, so the icon shows a sample
    /// field instead, as the original does.
    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        let text = Self.iconLabel
        let dimension = Self.equalsViewer.dimension(of: text)
        let scale = IconRendering.fitScale(width: dimension.width, height: dimension.height)
        let drawnWidth = CGFloat(dimension.width) * scale
        let offsetX = (CGFloat(IconRendering.buttonSize) - drawnWidth) / 2
        let y = IconRendering.buttonSize / 2 - dimension.height / 2
        return IconRendering.icon { context in
            let scaled = ScaledContext(context, scale: scale, offsetX: offsetX)
            Self.equalsViewer.draw(text,
                                   in: Rectangle(x: 0, y: y, width: dimension.width,
                                                 height: dimension.height),
                                   with: scaled)
        }
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let node = element as? FieldNode else {
            preconditionFailure("not a field node")
        }
        let bounds = self.bounds(element)
        let split = Self.splitPosition(node)
        let left = Self.leftWidth(node)
        let midOffset = Self.equalsViewer.dimension(of: Self.equals).width / 2
        Self.nameViewer.draw(node.name,
                             in: Rectangle(x: split - left, y: bounds.y, width: left, height: bounds.height),
                             with: context)
        Self.equalsViewer.draw(Self.equals,
                               in: Rectangle(x: split - midOffset, y: bounds.y,
                                             width: midOffset * 2, height: bounds.height),
                               with: context)
        Self.valueViewer.draw(node.value,
                              in: Rectangle(x: split + midOffset, y: bounds.y,
                                            width: Self.rightWidth(node), height: bounds.height),
                              with: context)
    }

    private static func splitPosition(_ node: FieldNode) -> Int {
        node.hasParent ? ObjectNodeRenderer.splitPosition(node.getParent() as! ObjectNode)
            : defaultWidth / 2
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        guard let node = node as? FieldNode else {
            preconditionFailure("not a field node")
        }
        let left = Self.leftWidth(node)
        let height = Self.height(node)
        if node.hasParent {
            let yPosition = ObjectNodeRenderer.yPosition(node.getParent(), node)
            // Ask the diagram renderer for the parent's bounds: the object renderer owns
            // them, not this one.
            let parentBounds = parent.bounds(of: node.getParent())
            return Rectangle(x: parentBounds.x + Self.xGap, y: yPosition,
                             width: parentBounds.width - 2 * Self.xGap, height: height)
        }
        return Rectangle(x: Self.defaultWidth / 2 - left, y: 0,
                         width: left + Self.rightWidth(node), height: height)
    }

    /// The width of the left (name) part of the node.
    public static func leftWidth(_ node: any Node) -> Int {
        let name = (node as? FieldNode)?.name ?? ""
        let midOffset = equalsViewer.dimension(of: equals).width / 2
        return nameViewer.dimension(of: name).width + midOffset
    }

    /// The width of the right (value) part of the node.
    public static func rightWidth(_ node: any Node) -> Int {
        let value = (node as? FieldNode)?.value ?? ""
        let midOffset = equalsViewer.dimension(of: equals).width / 2
        var right = valueViewer.dimension(of: value).width
        if right == 0 {
            right = defaultWidth / 2
        }
        return right + midOffset
    }

    /// The height of a field node.
    public static func height(_ node: any Node) -> Int {
        let field = node as? FieldNode
        let nameHeight = nameViewer.dimension(of: field?.name ?? "").height
        let valueHeight = valueViewer.dimension(of: field?.value ?? "").height
        let equalsHeight = equalsViewer.dimension(of: equals).height
        return max(defaultHeight, max(nameHeight, max(valueHeight, equalsHeight)))
    }

    public override func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        let bounds = self.bounds(node)
        return Point(x: bounds.maxX - Self.xGap, y: bounds.center().y)
    }
}

// MARK: - Use case diagram nodes

/// Renders an actor as a stick figure with the name below it.
public final class ActorNodeRenderer: AbstractNodeRenderer {

    private static let labelRenderer = StringRenderer(.center)
    private static let headSize = 16
    private static let bodySize = 20
    private static let legSize = 20
    private static let armsSize = 24
    static let width = GeomUtils.round(Double(legSize) / 2.0.squareRoot()) * 2
    static let height = headSize + bodySize
        + GeomUtils.round(Double(legSize) / 2.0.squareRoot())

    public override func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        let bounds = internalBounds(node)
        return Dimension(width: bounds.width, height: bounds.height)
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        let name = (node as? ActorNode)?.name ?? ""
        let text = Self.labelRenderer.dimension(of: name)
        return Rectangle(x: node.position.x + min(0, (Self.width - text.width) / 2),
                         y: node.position.y,
                         width: max(Self.width, text.width),
                         height: Self.height + text.height)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let node = element as? ActorNode else {
            preconditionFailure("not an actor node")
        }
        let bounds = self.bounds(element)
        let text = Self.labelRenderer.dimension(of: node.name)
        let nameBox = Rectangle(x: node.position.x + (Self.width - text.width) / 2,
                                y: bounds.y + Self.height, width: text.width, height: text.height)
        Self.labelRenderer.draw(node.name, in: nameBox, with: context)
        context.strokePath(Self.stickManPath(node), color: ColorScheme.current.strokeColor, style: .solid)
    }

    static func stickManPath(_ node: any Node) -> [PathCommand] {
        let neckX = node.position.x + Self.width / 2
        let neckY = node.position.y + Self.headSize
        let hipX = neckX
        let hipY = neckY + Self.bodySize
        let dx = Double(Self.legSize) / 2.0.squareRoot()
        let feetX1 = Int(Double(hipX) - dx)
        let feetX2 = Int(Double(hipX) + dx + 1)
        let feetY = Int(Double(hipY) + dx + 1)
        let halfHead = Self.headSize / 2
        let halfArms = Self.armsSize / 2
        return [
            .move(to: Point(x: neckX, y: neckY)),
            .quadCurve(control: Point(x: neckX + halfHead, y: neckY),
                       to: Point(x: neckX + halfHead, y: neckY - halfHead)),
            .quadCurve(control: Point(x: neckX + halfHead, y: neckY - Self.headSize),
                       to: Point(x: neckX, y: neckY - Self.headSize)),
            .quadCurve(control: Point(x: neckX - halfHead, y: neckY - Self.headSize),
                       to: Point(x: neckX - halfHead, y: neckY - halfHead)),
            .quadCurve(control: Point(x: neckX - halfHead, y: neckY), to: Point(x: neckX, y: neckY)),
            .line(to: Point(x: hipX, y: hipY)),
            .move(to: Point(x: neckX - halfArms, y: neckY + Self.bodySize / 3)),
            .line(to: Point(x: neckX + halfArms, y: neckY + Self.bodySize / 3)),
            .move(to: Point(x: feetX1, y: feetY)),
            .line(to: Point(x: hipX, y: hipY)),
            .line(to: Point(x: feetX2, y: feetY)),
        ]
    }
}

/// Renders a use case as an ellipse with a centred name.
public final class UseCaseNodeRenderer: AbstractNodeRenderer {

    private static let defaultWidth = 110
    private static let defaultHeight = 40
    private static let horizontalNamePadding = 30
    private static let labelRenderer = StringRenderer(.center)

    public override func defaultDimension(_ node: any Node) -> UMLGeometry.Dimension {
        Dimension(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        let bounds = self.bounds(element)
        context.drawOval(bounds.x, bounds.y, width: bounds.width, height: bounds.height,
                         fill: ColorScheme.current.fill, stroke: ColorScheme.current.strokeColor,
                         hasShadow: ColorScheme.current.hasShadows)
        let name = (element as? UseCaseNode)?.name ?? ""
        Self.labelRenderer.draw(name,
                                in: bounds.centerSlice(Self.labelRenderer.dimension(of: name).height),
                                with: context)
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        let name = (node as? UseCaseNode)?.name ?? ""
        let text = Self.labelRenderer.dimension(of: name)
        return Rectangle(x: node.position.x, y: node.position.y,
                         width: max(Self.defaultWidth, text.width + Self.horizontalNamePadding),
                         height: max(Self.defaultHeight, text.height))
    }

    public override func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        GeomUtils.intersectEllipse(bounds(node), direction)
    }
}

// MARK: - State diagram edges

/// Renders a state transition as a quadratic curve, or as an arc when it is a self-edge.
public final class StateTransitionEdgeRenderer: AbstractEdgeRenderer {

    private static let selfEdgeOffset = 20
    private static let degrees270 = 270
    private static let degrees20 = 20
    private static let degrees10 = 10
    private static let degrees5 = 5
    private static let radiansToPixels = 7
    private static let verticalTolerance = 20
    private static let stringViewer = StringRenderer(.center)

    /// The number of edges with the same start and end nodes up to and including this one.
    private func position(_ edge: any Edge) -> Int {
        var count = 0
        guard let start = edge.start() else {
            return 1
        }
        for other in diagram().edgesConnectedTo(start) {
            if let otherStart = other.start(), let otherEnd = other.end(),
               let edgeStart = edge.start(), let edgeEnd = edge.end(),
               otherStart === edgeStart && otherEnd === edgeEnd {
                count += 1
            }
            if other === edge {
                return count
            }
        }
        return max(count, 1)
    }

    private func diagram() -> Diagram {
        parent.diagramModel
    }

    private static func isSelfEdge(_ edge: any Edge) -> Bool {
        guard let start = edge.start(), let end = edge.end() else { return false }
        return start === end
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let edge = element as? any Edge else { return }
        if Self.isSelfEdge(edge) {
            let arc = selfEdgeShape(edge)
            context.strokeArc(centerX: arc.centerX, centerY: arc.centerY, radius: arc.radiusX,
                              startAngle: arc.startAngle, length: Self.degrees270,
                              color: ColorScheme.current.strokeColor)
        } else {
            context.strokePath(normalEdgeShape(edge), color: ColorScheme.current.strokeColor, style: .solid)
        }
        drawLabel(edge, context)
        drawArrowHead(edge, context)
    }

    private func drawArrowHead(_ edge: any Edge, _ context: any RenderingContext) {
        if Self.isSelfEdge(edge) {
            let connection2 = selfEdgeConnectionPoints(edge).point2
            if position(edge) == 1 {
                ArrowHeadRenderer.draw(context, .v,
                                       Point(x: connection2.x + Self.selfEdgeOffset,
                                             y: connection2.y - Self.selfEdgeOffset / 4),
                                       connectionPoints(of: edge).point2)
            } else {
                ArrowHeadRenderer.draw(context, .v,
                                       Point(x: connection2.x - Self.selfEdgeOffset / 4,
                                             y: connection2.y - Self.selfEdgeOffset),
                                       connectionPoints(of: edge).point2)
            }
        } else {
            ArrowHeadRenderer.draw(context, .v, controlPoint(edge), connectionPoints(of: edge).point2)
        }
    }

    private func drawLabel(_ edge: any Edge, _ context: any RenderingContext) {
        let label = wrappedLabel(edge)
        if label.isEmpty {
            return
        }
        Self.stringViewer.draw(label, in: labelBounds(edge, label), with: context)
    }

    private func wrappedLabel(_ edge: any Edge) -> String {
        guard let start = edge.start(), let end = edge.end() else { return "" }
        let distanceInX = abs(parent.bounds(of: start).center().x - parent.bounds(of: end).center().x)
        let distanceInY = abs(parent.bounds(of: start).center().y - parent.bounds(of: end).center().y)
        let label = (edge as? SingleLabelEdge)?.middleLabel ?? ""
        return AbstractEdgeRenderer.wrapLabel(label, distanceInX, distanceInY)
    }

    private func labelBounds(_ edge: any Edge, _ label: String) -> Rectangle {
        let textDimensions = Self.stringViewer.dimension(of: label)
        if Self.isSelfEdge(edge) {
            let line = connectionPoints(of: edge)
            if position(edge) == 1 {
                return Rectangle(x: line.x1 + Self.selfEdgeOffset - textDimensions.width / 2,
                                 y: line.y1 - Self.selfEdgeOffset - textDimensions.height,
                                 width: textDimensions.width, height: textDimensions.height)
            }
            return Rectangle(x: line.x1 - textDimensions.width / 2,
                             y: line.y1 - 2 * Self.selfEdgeOffset - textDimensions.height,
                             width: textDimensions.width, height: textDimensions.height)
        }

        let line = connectionPoints(of: edge)
        let control = controlPoint(edge)
        var x = control.x / 2 + line.x1 / 4 + line.x2 / 4
        var y = control.y / 2 + line.y1 / 4 + line.y2 / 4
        let gap = 3
        if line.y1 >= line.y2 - Self.verticalTolerance && line.y1 <= line.y2 + Self.verticalTolerance {
            x -= textDimensions.width / 2
        } else if line.y1 <= line.y2 {
            x += gap
        } else {
            x -= textDimensions.width + gap
        }
        if line.x1 <= line.x2 {
            y -= textDimensions.height + gap
        } else {
            y += gap
        }
        if position(edge) > 1 {
            let angleLowerBound = atan2(1.0, 1.0)
            let angleUpperBound = 3 * angleLowerBound
            let angle = abs(atan2(Double(line.x2 - line.x1), Double(line.y2 - line.y1)))
            var delta = Double(textDimensions.height)
            if angleLowerBound <= angle && angle <= angleUpperBound {
                delta -= angle * Double(Self.radiansToPixels)
            }
            if line.x1 <= line.x2 {
                y -= Int(delta)
            } else {
                y += Int(delta)
            }
        }
        return Rectangle(x: x, y: y, width: textDimensions.width, height: textDimensions.height)
    }

    public override func bounds(_ element: any DiagramElement) -> Rectangle {
        guard let edge = element as? any Edge else {
            return super.bounds(element)
        }
        var result = super.bounds(element)
        let label = wrappedLabel(edge)
        if !label.isEmpty {
            result = result.add(labelBounds(edge, label))
        }
        return result
    }

    public override func shape(of edge: any Edge) -> [PathCommand] {
        if Self.isSelfEdge(edge) {
            return []
        }
        let line = connectionPoints(of: edge)
        let control = controlPoint(edge)
        return [.move(to: line.point1), .quadCurve(control: control, to: line.point2)]
    }

    public override func connectionPoints(of edge: any Edge) -> Line {
        if Self.isSelfEdge(edge) {
            return selfEdgeConnectionPoints(edge)
        }
        guard let start = edge.start(), let end = edge.end() else {
            preconditionFailure("edge is not connected")
        }
        let startBounds = parent.bounds(of: start)
        let endBounds = parent.bounds(of: end)
        let startCenter = startBounds.center()
        let endCenter = endBounds.center()
        let turn = position(edge) > 1 ? Self.degrees20 : Self.degrees5
        let d1 = Direction.fromLine(startCenter, endCenter).rotatedBy(-turn)
        let d2 = Direction.fromLine(endCenter, startCenter).rotatedBy(turn)
        return Line(point1: parent.connectionPoint(of: start, d1),
                    point2: parent.connectionPoint(of: end, d2))
    }

    private func selfEdgeConnectionPoints(_ edge: any Edge) -> Line {
        guard let start = edge.start() else {
            preconditionFailure("edge is not connected")
        }
        let bounds = parent.bounds(of: start)
        if position(edge) == 1 {
            return Line(point1: Point(x: bounds.maxX - Self.selfEdgeOffset, y: bounds.y),
                        point2: Point(x: bounds.maxX, y: bounds.y + Self.selfEdgeOffset))
        }
        return Line(point1: Point(x: bounds.x, y: bounds.y + Self.selfEdgeOffset),
                    point2: Point(x: bounds.x + Self.selfEdgeOffset, y: bounds.y))
    }

    /// The arc describing a self-edge.
    func selfEdgeShape(_ edge: any Edge) -> (centerX: Int, centerY: Int, radiusX: Int, startAngle: Int) {
        let line = selfEdgeConnectionPoints(edge)
        if position(edge) == 1 {
            return (line.x1 + Self.selfEdgeOffset, line.y1, Self.selfEdgeOffset, Self.degrees270)
        }
        return (line.x1, line.y1 - Self.selfEdgeOffset, Self.selfEdgeOffset, 0)
    }

    /// A curved arrow, drawn across the icon; only the head is drawn smaller.
    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        let start = Point(x: IconRendering.offset, y: IconRendering.offset)
        let end = Point(x: IconRendering.buttonSize - IconRendering.offset,
                        y: IconRendering.buttonSize - IconRendering.offset)
        let tangent = tan(Double(Self.degrees10) * Double.pi / 180)
        let dx = Double(end.x - start.x) / 2
        let dy = Double(end.y - start.y) / 2
        let control = Point(x: GeomUtils.round(Double(start.x + end.x) / 2 + tangent * dy),
                            y: GeomUtils.round(Double(start.y + end.y) / 2 - tangent * dx))
        return IconRendering.icon { context in
            context.strokePath([.move(to: start), .quadCurve(control: control, to: end)],
                               color: ColorScheme.current.strokeColor, style: .solid)
            ArrowHeadRenderer.draw(IconRendering.scaling(context,
                                                         by: IconRendering.decorationScale,
                                                         around: end),
                                   .v, control, end)
        }
    }

    private func normalEdgeShape(_ edge: any Edge) -> [PathCommand] {
        let line = connectionPoints(of: edge)
        return [.move(to: line.point1), .quadCurve(control: controlPoint(edge), to: line.point2)]
    }

    /// The control point of the quadratic spline.
    func controlPoint(_ edge: any Edge) -> Point {
        let line = connectionPoints(of: edge)
        var tangent = tan(Double(Self.degrees10) * Double.pi / 180)
        if position(edge) > 1 {
            tangent = tan(Double(Self.degrees20) * Double.pi / 180)
        }
        let dx = Double(line.x2 - line.x1) / 2
        let dy = Double(line.y2 - line.y1) / 2
        return Point(x: GeomUtils.round(Double(line.x1 + line.x2) / 2 + tangent * dy),
                     y: GeomUtils.round(Double(line.y1 + line.y2) / 2 - tangent * dx))
    }
}

// MARK: - Object diagram edges

/// Renders an S- or C-shaped reference edge with a filled arrow head.
public final class ObjectReferenceEdgeRenderer: AbstractEdgeRenderer {

    private static let endSize = 10

    public override func shape(of edge: any Edge) -> [PathCommand] {
        isSShaped(edge) ? Self.sShape(connectionPoints(of: edge)) : Self.cShape(connectionPoints(of: edge))
    }

    static func sShape(_ points: Line) -> [PathCommand] {
        let x1 = points.x1 + endSize
        let y1 = points.y1
        let x2 = points.x2 - endSize
        let y2 = points.y2
        let xmid = (points.x1 + points.x2) / 2
        let ymid = (points.y1 + points.y2) / 2
        return [
            .move(to: Point(x: points.x1, y: y1)),
            .line(to: Point(x: x1, y: y1)),
            .quadCurve(control: Point(x: (x1 + xmid) / 2, y: y1), to: Point(x: xmid, y: ymid)),
            .quadCurve(control: Point(x: (x2 + xmid) / 2, y: y2), to: Point(x: x2, y: y2)),
            .line(to: Point(x: points.x2, y: y2)),
        ]
    }

    static func cShape(_ points: Line) -> [PathCommand] {
        let x1 = max(points.x1, points.x2) + endSize
        let y1 = points.y1
        let x2 = x1 + endSize
        let y2 = points.y2
        let ymid = (points.y1 + points.y2) / 2
        return [
            .move(to: Point(x: points.x1, y: y1)),
            .line(to: Point(x: x1, y: y1)),
            .quadCurve(control: Point(x: x2, y: y1), to: Point(x: x2, y: ymid)),
            .quadCurve(control: Point(x: x2, y: y2), to: Point(x: x1, y: y2)),
            .line(to: Point(x: points.x2, y: y2)),
        ]
    }

    /// A C-shaped arrow, drawn in a 0.6-scaled space as in the original.
    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        let scale: CGFloat = 0.6
        let start = Point(x: 5, y: 5)
        let end = Point(x: 15, y: 25)
        let path = Self.cShape(Line(point1: start, point2: end))
        return IconRendering.icon { context in
            let scaled = ScaledContext(context, scale: scale)
            scaled.strokePath(path, color: IconStyleSettings.strokeColor, style: .solid)
            ArrowHeadRenderer.draw(scaled, .blackTriangle, Point(x: 20, y: 25), end)
        }
    }

    func isSShaped(_ edge: any Edge) -> Bool {
        guard let start = edge.start(), let end = edge.end() else { return false }
        let bounds = parent.bounds(of: end)
        let point = parent.connectionPoint(of: start, Direction.east)
        return bounds.x >= point.x + 2 * Self.endSize
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let edge = element as? any Edge else { return }
        context.strokePath(shape(of: edge), color: ColorScheme.current.strokeColor, style: .solid)
        let points = connectionPoints(of: edge)
        if isSShaped(edge) {
            ArrowHeadRenderer.draw(context, .blackTriangle,
                                   Point(x: points.x2 - Self.endSize, y: points.y2),
                                   Point(x: points.x2, y: points.y2))
        } else {
            ArrowHeadRenderer.draw(context, .blackTriangle,
                                   Point(x: points.x2 + Self.endSize, y: points.y2),
                                   Point(x: points.x2, y: points.y2))
        }
    }

    public override func connectionPoints(of edge: any Edge) -> Line {
        guard let start = edge.start(), let end = edge.end() else {
            preconditionFailure("edge is not connected")
        }
        let point = parent.connectionPoint(of: start, Direction.east)
        if isSShaped(edge) {
            return Line(point1: point, point2: parent.connectionPoint(of: end, Direction.west))
        }
        return Line(point1: point, point2: parent.connectionPoint(of: end, Direction.east))
    }
}

// MARK: - Use case diagram edges

/// A straight solid line without decorations.
public final class UseCaseAssociationEdgeRenderer: StraightEdgeRenderer {
    public init(_ parent: any RenderingContextOwner & EdgePathProviding) {
        super.init(parent, .solid, .none)
    }
}

/// A straight solid line with a triangle end decoration.
public final class UseCaseGeneralizationEdgeRenderer: StraightEdgeRenderer {
    public init(_ parent: any RenderingContextOwner & EdgePathProviding) {
        super.init(parent, .solid, .triangle)
    }
}

/// A straight edge with a label extracted from the edge.
public class LabeledStraightEdgeRenderer: StraightEdgeRenderer {

    private static let labelRenderer = StringRenderer(.center)
    private let labelExtractor: (any Edge) -> String

    public init(_ parent: any RenderingContextOwner & EdgePathProviding,
                _ lineStyle: LineStyle, _ arrowHead: ArrowHead,
                _ labelExtractor: @escaping (any Edge) -> String) {
        self.labelExtractor = labelExtractor
        super.init(parent, lineStyle, arrowHead)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        super.draw(element, context)
        guard let edge = element as? any Edge else { return }
        let label = wrappedLabel(edge)
        if !label.isEmpty {
            let bounds = connectionPoints(of: edge).spanning()
                .translated(0, -Self.labelRenderer.dimension(of: label).height)
            Self.labelRenderer.draw(label, in: bounds, with: context)
        }
    }

    private func wrappedLabel(_ edge: any Edge) -> String {
        guard let start = edge.start(), let end = edge.end() else { return "" }
        let distanceInX = abs(parent.bounds(of: start).center().x - parent.bounds(of: end).center().x)
        let distanceInY = abs(parent.bounds(of: start).center().y - parent.bounds(of: end).center().y)
        return AbstractEdgeRenderer.wrapLabel(labelExtractor(edge), distanceInX, distanceInY)
    }
}

/// A straight dotted line with a V end decoration and a type label.
public final class UseCaseDependencyEdgeRenderer: LabeledStraightEdgeRenderer {

    private static let tagRenderer = StringRenderer(.center)

    public init(_ parent: any RenderingContextOwner & EdgePathProviding) {
        super.init(parent, .dotted, .v, { edge in
            (edge as? UseCaseDependencyEdge)?.type.label ?? ""
        })
    }

    /// The base dashed arrow plus the initial of the dependency type ("I" or "E").
    ///
    /// The original draws the letter in a 0.75-scaled space at `(1, BUTTON_SIZE)`, which
    /// leaves it half outside the icon; here it is drawn small in the bottom right corner,
    /// where it distinguishes the two tools without being clipped.
    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        IconRendering.icon { context in
            super.drawIconDiagonal(element, context)
            guard let tag = Self.tag(for: element) else { return }
            // The diagonal leaves the bottom-left corner free: draw the letter there, at
            // half size so that it stays small next to the arrow.
            Self.tagRenderer.draw(tag,
                                  in: Rectangle(x: 7, y: 33, width: 18, height: 13),
                                  with: ScaledContext(context, scale: 0.5))
        }
    }

    /// The first letter of the dependency type label ("≪include≫" -> "I").
    static func tag(for element: any DiagramElement) -> String? {
        guard let label = (element as? UseCaseDependencyEdge)?.type.label,
              let character = label.dropFirst().first else {
            return nil
        }
        return String(character).uppercased()
    }
}

/// A straight solid line with an optional middle label.
public final class ObjectCollaborationEdgeRenderer: LabeledStraightEdgeRenderer {

    public init(_ parent: any RenderingContextOwner & EdgePathProviding) {
        super.init(parent, .solid, .none, { edge in
            (edge as? ObjectCollaborationEdge)?.middleLabel ?? ""
        })
    }
}
