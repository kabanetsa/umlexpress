//
//  NodeRenderers.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.nodes.NodeRenderer, AbstractNodeRenderer,
//  NodeStorage, TypeNodeRenderer and InterfaceNodeRenderer
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import CoreGraphics
import UMLGeometry
import UMLModel

/// A renderer that can draw and compute geometric properties of a diagram element.
public protocol DiagramElementRenderer: AnyObject {
    /// The smallest rectangle that bounds the element, including labels.
    func bounds(_ element: any DiagramElement) -> Rectangle
    /// True if the element contains the point.
    func contains(_ element: any DiagramElement, _ point: Point) -> Bool
    /// Draws the element.
    func draw(_ element: any DiagramElement, _ context: any RenderingContext)
    /// A tool-palette icon of the element, scaled to fit a 25×25 button.
    func createIcon(_ element: any DiagramElement) -> CGImage?
}

/// A renderer for nodes.
public protocol NodeRenderer: DiagramElementRenderer {
    /// The best connection point to link this node with another one.
    func connectionPoint(_ node: any Node, _ direction: Direction) -> Point
    /// Activates the bounds cache.
    func activateNodeStorage()
    /// Deactivates and clears the bounds cache.
    func deactivateAndClearNodeStorage()
    /// The line to which edges can attach on the given side of the node.
    func face(of node: any Node, _ side: Side) -> Line
    /// The default size of a node of this type.
    func defaultDimension(_ node: any Node) -> Dimension
}

/// Caches the bounds of nodes by identity, as long as it is activated.
public final class NodeStorage {

    private var nodeBounds: [ObjectIdentifier: Rectangle] = [:]
    private var isActivated = false

    public init() {}

    /// The bounds of `node`, either from the cache or computed by `calculator`.
    public func bounds(of node: any Node, _ calculator: (any Node) -> Rectangle) -> Rectangle {
        guard isActivated else {
            return calculator(node)
        }
        let key = ObjectIdentifier(node)
        if let cached = nodeBounds[key] {
            return cached
        }
        let computed = calculator(node)
        nodeBounds[key] = computed
        return computed
    }

    public func activate() {
        isActivated = true
    }

    public func deactivateAndClear() {
        isActivated = false
        nodeBounds.removeAll()
    }
}

/// Basic services for drawing nodes.
open class AbstractNodeRenderer: NodeRenderer {

    public static let buttonSize = 25
    public static let offset = 3

    private let nodeStorage = NodeStorage()
    private let parentRenderer: any RenderingContextOwner

    public init(_ parent: any RenderingContextOwner) {
        self.parentRenderer = parent
    }

    /// The renderer of the diagram that contains these nodes.
    public var parent: any RenderingContextOwner { parentRenderer }

    open func contains(_ element: any DiagramElement, _ point: Point) -> Bool {
        bounds(element).contains(point)
    }

    open func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        GeomUtils.intersectRectangle(bounds(node), direction)
    }

    public final func bounds(_ element: any DiagramElement) -> Rectangle {
        guard let node = element as? any Node else {
            preconditionFailure("not a node: \(element)")
        }
        return nodeStorage.bounds(of: node) { self.internalBounds($0) }
    }

    public final func activateNodeStorage() {
        nodeStorage.activate()
    }

    public final func deactivateAndClearNodeStorage() {
        nodeStorage.deactivateAndClear()
    }

    /// The smallest rectangle that bounds the node, including all labels.
    open func internalBounds(_ node: any Node) -> Rectangle {
        preconditionFailure("\(type(of: self)) must override internalBounds")
    }

    /// By default the face is the side of the node's bounds.
    open func face(of node: any Node, _ side: Side) -> Line {
        side.line(in: bounds(node))
    }

    open func defaultDimension(_ node: any Node) -> Dimension {
        Dimension(width: 100, height: 60)
    }

    open func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        preconditionFailure("\(type(of: self)) must override draw")
    }

    /// Draws the element scaled into the icon context, as `createIcon` does in the original.
    ///
    /// The element is drawn through a `ScaledContext`, so that the element's own
    /// coordinates are mapped into the 25×25 icon area. Renderers that need to decorate
    /// the icon (the package description, for example) call this and then keep drawing
    /// in icon coordinates.
    @discardableResult
    func drawIntoIcon(_ element: any DiagramElement, _ context: any RenderingContext) -> ScaledContext {
        let elementBounds = bounds(element)
        let scale = IconRendering.fitScale(width: elementBounds.width, height: elementBounds.height)
        // Exactly the original: `graphics.scale(scale)` followed by
        // `graphics.translate(max((h - w) / 2, 0), max((w - h) / 2, 0))`. JavaFX
        // post-multiplies, so the translation is in the scaled space, which is why the
        // offsets below are multiplied by the scale; only the shorter side is centred.
        let translateX = max((elementBounds.height - elementBounds.width) / 2, 0)
        let translateY = max((elementBounds.width - elementBounds.height) / 2, 0)
        let transform = ScaledContext(context, scale: scale,
                                      offsetX: CGFloat(translateX - elementBounds.x) * scale,
                                      offsetY: CGFloat(translateY - elementBounds.y) * scale)
        draw(element, transform)
        return transform
    }

    /// Draws the element scaled into a 25×25 icon, as `createIcon` does in the original.
    open func createIcon(_ element: any DiagramElement) -> CGImage? {
        IconRendering.icon { context in
            self.drawIntoIcon(element, context)
        }
    }
}

/// A rendering context that scales (and optionally shifts) coordinates before delegating.
///
/// Used to draw a diagram element into a small icon; the original does the same with the
/// JavaFX `scale` and `translate` transformations. The transformation is
/// `canvas = point * scale + offset`, with the offset in icon points, so callers can centre
/// content without knowing the scale.
final class ScaledContext: RenderingContext {

    private let base: any RenderingContext
    private let scale: CGFloat
    private let offsetX: CGFloat
    private let offsetY: CGFloat

    init(_ base: any RenderingContext, scale: CGFloat, offsetX: CGFloat = 0, offsetY: CGFloat = 0) {
        self.base = base
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    private func scaled(_ value: Int, _ offset: CGFloat) -> Int {
        Int((CGFloat(value) * scale + offset).rounded())
    }

    private func length(_ value: Int) -> Int {
        max(Int((CGFloat(value) * scale).rounded()), 0)
    }

    private func point(_ p: Point) -> Point {
        Point(x: scaled(p.x, offsetX), y: scaled(p.y, offsetY))
    }

    private func rect(_ r: Rectangle) -> Rectangle {
        Rectangle(x: scaled(r.x, offsetX), y: scaled(r.y, offsetY),
                  width: length(r.width), height: length(r.height))
    }

    func strokeLine(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ color: RGBAColor, _ style: LineStyle) {
        base.strokeLine(scaled(x1, offsetX), scaled(y1, offsetY),
                        scaled(x2, offsetX), scaled(y2, offsetY), color, style)
    }

    func drawRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        base.drawRectangle(rect(rectangle), fill: fill, stroke: stroke, hasShadow: false)
    }

    func drawOval(_ x: Int, _ y: Int, width: Int, height: Int, fill: RGBAColor, stroke: RGBAColor,
                  hasShadow: Bool) {
        base.drawOval(scaled(x, offsetX), scaled(y, offsetY), width: length(width),
                      height: length(height), fill: fill, stroke: stroke, hasShadow: false)
    }

    func strokeArc(centerX: Int, centerY: Int, radius: Int, startAngle: Int, length arcLength: Int,
                   color: RGBAColor) {
        base.strokeArc(centerX: scaled(centerX, offsetX), centerY: scaled(centerY, offsetY),
                       radius: self.length(radius), startAngle: startAngle, length: arcLength,
                       color: color)
    }

    func strokePath(_ path: [PathCommand], color: RGBAColor, style: LineStyle) {
        base.strokePath(path.map(transform), color: color, style: style)
    }

    func drawClosedPath(_ path: [PathCommand], fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        base.drawClosedPath(path.map(transform), fill: fill, stroke: stroke, hasShadow: false)
    }

    func drawRoundedRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor,
                              hasShadow: Bool) {
        base.drawRoundedRectangle(rect(rectangle), fill: fill, stroke: stroke, hasShadow: false)
    }

    func drawText(_ text: String, bounds: Rectangle, alignment: Alignment, color: RGBAColor,
                  style: TextStyle, fontDimension: FontDimension) {
        // The text is scaled with the element, as on the original canvas: an icon shows the
        // same strings as the diagram, only tiny.
        let scaledSize = max(Int((Double(style.size) * Double(scale)).rounded()), 2)
        let scaledLineHeight = max(length(fontDimension.lineHeight), 2)
        let scaledBaseline = max(Int((Double(fontDimension.baselineOffset) * Double(scale)).rounded()), 1)
        var scaledStyle = style
        scaledStyle.size = scaledSize
        base.drawText(text, bounds: rect(bounds), alignment: alignment, color: color,
                      style: scaledStyle,
                      fontDimension: FontDimension(lineHeight: scaledLineHeight,
                                                   baselineOffset: scaledBaseline))
    }

    private func transform(_ command: PathCommand) -> PathCommand {
        switch command {
        case let .move(p): .move(to: point(p))
        case let .line(p): .line(to: point(p))
        case let .quadCurve(control, p): .quadCurve(control: point(control), to: point(p))
        }
    }
}

/// Renders a class or an interface in a class diagram.
///
/// The top box, which shows the title, has a minimum height of 20 pixels, minus 20 if
/// attributes are present, minus another 20 if methods are present.
open class TypeNodeRenderer: AbstractNodeRenderer {

    public static let defaultWidth = 100
    public static let defaultHeight = 60
    public static let topIncrement = 20
    static let topMargin = 5
    static let horizontalPadding = 7
    static let verticalPadding = 6
    static let italicMarkup = "/"
    static let underlineMarkup = "_"

    private static let typeNameRenderer = StringRenderer(.center, .bold)
    private static let italicNameRenderer = StringRenderer(.center, .bold, .italic)
    private static let stringRenderer = StringRenderer(.left)
    private static let underliningStringRenderer = StringRenderer(.left, .underlined)
    private static let italicStringRenderer = StringRenderer(.left, .italic)

    private static var lineHeightValue: Int { stringRenderer.lineHeight }

    open override func defaultDimension(_ node: any Node) -> Dimension {
        Dimension(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    open override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let node = element as? TypeNode else {
            preconditionFailure("not a type node")
        }
        let bounds = self.bounds(element)
        let attributeBoxHeight = Self.attributeBoxHeight(node)
        let methodBoxHeight = Self.methodBoxHeight(node)
        let nameBoxHeight = self.nameBoxHeight(node, attributeBoxHeight, methodBoxHeight)

        context.drawRectangle(bounds, fill: ColorScheme.current.fill,
                              stroke: ColorScheme.current.strokeColor,
                              hasShadow: ColorScheme.current.hasShadows)
        Self.drawName(nameText(node),
                      in: Rectangle(x: bounds.x, y: bounds.y, width: bounds.width, height: nameBoxHeight),
                      with: context)

        if attributeBoxHeight > 0 {
            let splitY = bounds.y + nameBoxHeight
            context.strokeLine(bounds.x, splitY, bounds.maxX, splitY,
                               ColorScheme.current.strokeColor, .solid)
            Self.drawAttribute(node.attributes,
                               in: Rectangle(x: bounds.x, y: splitY, width: bounds.width, height: attributeBoxHeight),
                               with: context)
            if methodBoxHeight > 0 {
                let splitY2 = splitY + attributeBoxHeight
                context.strokeLine(bounds.x, splitY2, bounds.maxX, splitY2,
                                   ColorScheme.current.strokeColor, .solid)
                Self.drawMethod(node.methods,
                                in: Rectangle(x: bounds.x, y: splitY2, width: bounds.width, height: methodBoxHeight),
                                with: context)
            }
        } else if methodBoxHeight > 0 {
            let splitY = bounds.y + nameBoxHeight
            context.strokeLine(bounds.x, splitY, bounds.maxX, splitY,
                               ColorScheme.current.strokeColor, .solid)
            Self.drawMethod(node.methods,
                            in: Rectangle(x: bounds.x, y: splitY, width: bounds.width, height: methodBoxHeight),
                            with: context)
        }
    }

    /// The text to show as the name of the node.
    open func nameText(_ node: TypeNode) -> String {
        node.name
    }

    open override func internalBounds(_ node: any Node) -> Rectangle {
        guard let node = node as? TypeNode else {
            preconditionFailure("not a type node")
        }
        let attributeHeight = Self.attributeBoxHeight(node)
        let methodHeight = Self.methodBoxHeight(node)
        let nameHeight = nameBoxHeight(node, attributeHeight, methodHeight)
        let nameDimension = Self.textDimensionsBold(nameText(node))
        let attributeDimension = Self.textDimensions(node.attributes)
        let methodDimension = Self.textDimensions(node.methods)
        let width = GeomUtils.max(Self.defaultWidth, nameDimension.width,
                                  attributeDimension.width, methodDimension.width)
        let height = attributeHeight + methodHeight + nameHeight
        return Rectangle(x: node.position.x, y: node.position.y, width: width, height: height)
    }

    // MARK: - Drawing helpers

    static func drawName(_ name: String, in bounds: Rectangle, with context: any RenderingContext) {
        let nameByLine = Self.splitLines(name.trimmingCharacters(in: .whitespacesAndNewlines))
        var startY = bounds.center().y - lineHeightValue * nameByLine.count / 2
        for line in nameByLine {
            let lineBounds = Rectangle(x: bounds.x, y: startY, width: bounds.width, height: lineHeightValue)
            if Self.containsMarkup(line, italicMarkup) {
                italicNameRenderer.draw(Self.removeMarkup(line), in: lineBounds, with: context)
            } else {
                typeNameRenderer.draw(line, in: lineBounds, with: context)
            }
            startY += lineHeightValue
        }
    }

    static func drawAttribute(_ text: String, in bounds: Rectangle, with context: any RenderingContext) {
        let attributesByLine = Self.splitLines(text.trimmingCharacters(in: .whitespacesAndNewlines))
        var lineSpacing = topMargin
        for attribute in attributesByLine {
            let lineBounds = Rectangle(x: bounds.x + horizontalPadding, y: bounds.y + lineSpacing,
                                       width: bounds.width, height: lineHeightValue)
            if Self.containsMarkup(attribute, underlineMarkup) {
                underliningStringRenderer.draw(Self.removeMarkup(attribute), in: lineBounds, with: context)
            } else {
                stringRenderer.draw(attribute, in: lineBounds, with: context)
            }
            lineSpacing += lineHeightValue
        }
    }

    static func drawMethod(_ text: String, in bounds: Rectangle, with context: any RenderingContext) {
        let methodsByLine = Self.splitLines(text.trimmingCharacters(in: .whitespacesAndNewlines))
        var lineSpacing = topMargin
        for method in methodsByLine {
            let lineBounds = Rectangle(x: bounds.x + horizontalPadding, y: bounds.y + lineSpacing,
                                       width: bounds.width, height: lineHeightValue)
            if Self.containsMarkup(method, underlineMarkup) {
                underliningStringRenderer.draw(Self.removeMarkup(method), in: lineBounds, with: context)
            } else if Self.containsMarkup(method, italicMarkup) {
                italicStringRenderer.draw(Self.removeMarkup(method), in: lineBounds, with: context)
            } else {
                stringRenderer.draw(method, in: lineBounds, with: context)
            }
            lineSpacing += lineHeightValue
        }
    }

    // MARK: - Metrics

    static func attributeBoxHeight(_ node: TypeNode) -> Int {
        textDimensions(node.attributes).height
    }

    static func methodBoxHeight(_ node: TypeNode) -> Int {
        textDimensions(node.methods).height
    }

    func nameBoxHeight(_ node: TypeNode, _ attributeBoxHeight: Int, _ methodBoxHeight: Int) -> Int {
        let textHeight = GeomUtils.max(Self.textDimensions(nameText(node)).height, Self.topIncrement)
        let freeSpaceInTopBox = Self.defaultHeight - textHeight
        if freeSpaceInTopBox < 0 {
            return textHeight
        }
        if attributeBoxHeight + methodBoxHeight > freeSpaceInTopBox {
            return textHeight
        }
        return textHeight + freeSpaceInTopBox - (attributeBoxHeight + methodBoxHeight)
    }

    static func textDimensions(_ string: String) -> Dimension {
        guard !string.isEmpty else {
            return Dimension.null
        }
        let dimension = stringRenderer.dimension(of: string)
        return Dimension(width: dimension.width + 2 * horizontalPadding,
                         height: dimension.height + 2 * verticalPadding)
    }

    static func textDimensionsBold(_ string: String) -> Dimension {
        guard !string.isEmpty else {
            return Dimension.null
        }
        let dimension = typeNameRenderer.dimension(of: string)
        return Dimension(width: dimension.width + 2 * horizontalPadding, height: dimension.height)
    }

    // MARK: - Markup

    static func containsMarkup(_ text: String, _ markup: String) -> Bool {
        text.count > 2 && text.hasPrefix(markup) && text.hasSuffix(markup)
    }

    static func removeMarkup(_ string: String) -> String {
        var characters = Array(string)
        characters.removeFirst()
        characters.removeLast()
        return String(characters)
    }

    /// Splits like `String.split("\n")`: no trailing empty elements.
    static func splitLines(_ string: String) -> [String] {
        var lines = string.components(separatedBy: "\n")
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines.isEmpty ? [""] : lines
    }
}

/// Renders an interface in a class diagram: the name is prefixed with the stereotype.
public final class InterfaceNodeRenderer: TypeNodeRenderer {

    public override func nameText(_ node: TypeNode) -> String {
        "\u{00AB}interface\u{00BB}\n" + node.name
    }
}

/// The part of a diagram renderer that node renderers need: the bounds of a node and
/// the connection points and faces it exposes.
public protocol RenderingContextOwner: AnyObject {
    /// The diagram being rendered.
    var diagramModel: Diagram { get }
    func bounds(of node: any Node) -> Rectangle
    func connectionPoint(of node: any Node, _ direction: Direction) -> Point
}

/// Renders a note node.
public final class NoteNodeRenderer: AbstractNodeRenderer {

    public static let defaultWidth = 60
    public static let defaultHeight = 40
    static let foldLength = 8
    static let padding = 3

    private static let noteViewer = StringRenderer(.left)

    public override func defaultDimension(_ node: any Node) -> Dimension {
        Dimension(width: Self.defaultWidth, height: Self.defaultHeight)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let node = element as? NoteNode else {
            preconditionFailure("not a note node")
        }
        context.drawClosedPath(notePath(node), fill: ColorScheme.current.noteColor,
                               stroke: ColorScheme.current.strokeColor,
                               hasShadow: ColorScheme.current.hasShadows)
        context.drawClosedPath(foldPath(node), fill: RGBAColor.white,
                               stroke: ColorScheme.current.strokeColor, hasShadow: false)
        Self.noteViewer.draw(node.name,
                             in: Rectangle(x: node.position.x + Self.padding,
                                           y: node.position.y + Self.padding,
                                           width: Self.defaultWidth - Self.foldLength - Self.padding * 2,
                                           height: Self.defaultHeight - Self.foldLength - Self.padding - 2),
                             with: context)
    }

    private func notePath(_ node: NoteNode) -> [PathCommand] {
        let bounds = self.bounds(node)
        return [
            .move(to: Point(x: bounds.x, y: bounds.y)),
            .line(to: Point(x: bounds.maxX - Self.foldLength, y: bounds.y)),
            .line(to: Point(x: bounds.maxX, y: bounds.y + Self.foldLength)),
            .line(to: Point(x: bounds.maxX, y: bounds.maxY)),
            .line(to: Point(x: bounds.x, y: bounds.maxY)),
            .line(to: Point(x: bounds.x, y: bounds.y)),
        ]
    }

    private func foldPath(_ node: NoteNode) -> [PathCommand] {
        let bounds = self.bounds(node)
        return [
            .move(to: Point(x: bounds.maxX - Self.foldLength, y: bounds.y)),
            .line(to: Point(x: bounds.maxX - Self.foldLength, y: bounds.y + Self.foldLength)),
            .line(to: Point(x: bounds.maxX, y: bounds.y + Self.foldLength)),
            .line(to: Point(x: bounds.maxX - Self.foldLength, y: bounds.y)),
        ]
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        guard let node = node as? NoteNode else {
            preconditionFailure("not a note node")
        }
        let textDimension = Self.noteViewer.dimension(of: node.name)
        return Rectangle(x: node.position.x, y: node.position.y,
                         width: max(textDimension.width + Self.foldLength + Self.padding * 2,
                                    Self.defaultWidth),
                         height: max(textDimension.height + Self.padding * 2, Self.defaultHeight))
    }
}

/// Renders an invisible point node.
public final class PointNodeRenderer: AbstractNodeRenderer {

    private static let selectionDistance = 5.0

    public override func defaultDimension(_ node: any Node) -> Dimension {
        Dimension(width: 0, height: 0)
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        Rectangle(x: node.position.x, y: node.position.y, width: 0, height: 0)
    }

    public override func contains(_ element: any DiagramElement, _ point: Point) -> Bool {
        guard let node = element as? any Node else { return false }
        return node.position.distance(to: point) < Self.selectionDistance
    }

    public override func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        node.position
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        // Do nothing, a point is invisible.
    }
}

/// Common functionality for the different kinds of package nodes.
open class AbstractPackageNodeRenderer: AbstractNodeRenderer {

    public static let padding = 10
    public static let topHeight = 20
    public static let defaultWidth = 100
    public static let defaultBottomHeight = 60
    public static let defaultTopWidth = 60
    public static let horizontalPadding = 3

    private static let labelRenderer = StringRenderer(.left)

    public override func defaultDimension(_ node: any Node) -> Dimension {
        Dimension(width: Self.defaultWidth, height: Self.topHeight + Self.defaultBottomHeight)
    }

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        guard let node = element as? AbstractPackageNode else {
            preconditionFailure("not a package node")
        }
        let topBounds = self.topBounds(node)
        let bottomBounds = self.bottomBounds(node)
        context.drawRectangle(topBounds, fill: ColorScheme.current.fill,
                              stroke: ColorScheme.current.strokeColor,
                              hasShadow: ColorScheme.current.hasShadows)
        context.drawRectangle(bottomBounds, fill: ColorScheme.current.fill,
                              stroke: ColorScheme.current.strokeColor,
                              hasShadow: ColorScheme.current.hasShadows)
        // The label is centred in the tab. The original draws it from the top edge of the
        // tab, which leaves the name hugging the top border and looks unbalanced.
        let labelHeight = Self.labelRenderer.dimension(of: node.name).height
        let labelY = topBounds.y + GeomUtils.max((topBounds.height - labelHeight) / 2, 0)
        Self.labelRenderer.draw(node.name,
                                in: Rectangle(x: topBounds.x + Self.horizontalPadding, y: labelY,
                                              width: topBounds.width, height: topBounds.height),
                                with: context)
    }

    public override func connectionPoint(_ node: any Node, _ direction: Direction) -> Point {
        guard let node = node as? AbstractPackageNode else {
            preconditionFailure("not a package node")
        }
        let topBounds = self.topBounds(node)
        let bottomBounds = self.bottomBounds(node)
        let bounds = topBounds.add(bottomBounds)
        let connectionPoint = super.connectionPoint(node, direction)
        if connectionPoint.y < bottomBounds.y && topBounds.maxX < connectionPoint.x {
            // The connection point falls in the empty top-right corner: recompute it so
            // that it intersects the top of the bottom rectangle (triangle proportions).
            let delta = topBounds.height * (connectionPoint.x - bounds.center().x) * 2 / bounds.height
            var newX = connectionPoint.x - delta
            if newX < topBounds.maxX {
                newX = topBounds.maxX + 1
            }
            return Point(x: newX, y: bottomBounds.y)
        }
        return connectionPoint
    }

    /// The top face of a package node is only the side of the bottom (main) rectangle.
    public override func face(of node: any Node, _ side: Side) -> Line {
        guard let node = node as? AbstractPackageNode else {
            preconditionFailure("not a package node")
        }
        if side == .top {
            let topBounds = self.topBounds(node)
            let bottomBounds = self.bottomBounds(node)
            return Line(point1: Point(x: topBounds.maxX, y: bottomBounds.y),
                        point2: Point(x: bottomBounds.maxX, y: bottomBounds.y))
        } else if side == .right {
            return side.line(in: self.bottomBounds(node))
        } else {
            return super.face(of: node, side)
        }
    }

    public override func internalBounds(_ node: any Node) -> Rectangle {
        guard let node = node as? AbstractPackageNode else {
            preconditionFailure("not a package node")
        }
        return topBounds(node).add(bottomBounds(node))
    }

    /// The point that corresponds to the actual top-right corner of the figure (as
    /// opposed to the bounds).
    public func topRightCorner(_ node: AbstractPackageNode) -> Point {
        let bottomBounds = self.bottomBounds(node)
        return Point(x: bottomBounds.maxX, y: bottomBounds.y)
    }

    open func topDimension(_ node: AbstractPackageNode) -> Dimension {
        let textDimensions = Self.labelRenderer.dimension(of: node.name)
        let topWidth = GeomUtils.max(textDimensions.width + 2 * Self.horizontalPadding, Self.defaultTopWidth)
        let topHeight = GeomUtils.max(textDimensions.height, Self.topHeight)
        return Dimension(width: topWidth, height: topHeight)
    }

    /// By default the top bounds is based on the node's position.
    open func topBounds(_ node: AbstractPackageNode) -> Rectangle {
        let position = node.position
        let dimension = topDimension(node)
        return Rectangle(x: position.x, y: position.y, width: dimension.width, height: dimension.height)
    }

    open func bottomBounds(_ node: AbstractPackageNode) -> Rectangle {
        preconditionFailure("\(type(of: self)) must override bottomBounds")
    }
}

/// Renders a package in a class diagram.
public final class PackageNodeRenderer: AbstractPackageNodeRenderer {

    private func childrenBounds(_ node: PackageNode) -> Rectangle? {
        guard !node.children.isEmpty else {
            return nil
        }
        var childBounds: Rectangle?
        for child in node.children {
            let bounds = parent.bounds(of: child)
            childBounds = childBounds.map { $0.add(bounds) } ?? bounds
        }
        return childBounds
    }

    /// The node's position may have to be adjusted if a child is to the left or above it.
    private func position(_ node: PackageNode, _ childrenBounds: Rectangle?) -> Point {
        guard let childrenBounds else {
            return node.position
        }
        return Point(x: childrenBounds.x - Self.padding,
                     y: childrenBounds.y - Self.padding - topDimension(node).height)
    }

    public override func topBounds(_ node: AbstractPackageNode) -> Rectangle {
        guard let node = node as? PackageNode else {
            preconditionFailure("not a package node")
        }
        let childrenBounds = self.childrenBounds(node)
        let position = position(node, childrenBounds)
        let dimension = topDimension(node)
        return Rectangle(x: position.x, y: position.y, width: dimension.width, height: dimension.height)
    }

    public override func bottomBounds(_ node: AbstractPackageNode) -> Rectangle {
        guard let node = node as? PackageNode else {
            preconditionFailure("not a package node")
        }
        var width = Self.defaultWidth
        var height = Self.defaultBottomHeight
        let childrenBounds = self.childrenBounds(node)
        let position = position(node, childrenBounds)
        let topDimension = topDimension(node)

        if let childrenBounds {
            width = GeomUtils.max(width, childrenBounds.maxX + Self.padding - position.x)
            height = GeomUtils.max(height,
                                   childrenBounds.maxY + Self.padding - position.y - topDimension.height)
        }
        width = GeomUtils.max(width, topDimension.width + (Self.defaultWidth - Self.defaultTopWidth))
        return Rectangle(x: position.x, y: position.y + topDimension.height, width: width, height: height)
    }
}

/// Renders a package description in a class diagram.
public final class PackageDescriptionNodeRenderer: AbstractPackageNodeRenderer {

    private static let contentRenderer = StringRenderer(.center)

    public override func draw(_ element: any DiagramElement, _ context: any RenderingContext) {
        super.draw(element, context)
        guard let node = element as? PackageDescriptionNode else {
            preconditionFailure("not a package description node")
        }
        let bottomBounds = self.bottomBounds(node)
        let content = node.contents
        Self.contentRenderer.draw(content,
                                  in: bottomBounds.centerSlice(Self.contentRenderer.dimension(of: content).height),
                                  with: context)
    }

    /// The package icon with the word "description" in its bottom box, as in the original.
    public override func createIcon(_ element: any DiagramElement) -> CGImage? {
        IconRendering.icon { context in
            // The label is drawn in the element's coordinate system, which still carries
            // the icon transformation (the original draws into the scaled graphics context).
            let scaled = self.drawIntoIcon(element, context)
            guard let node = element as? AbstractPackageNode else { return }
            let bottomBounds = self.bottomBounds(node)
            let text = "description"
            Self.contentRenderer.draw(text,
                                      in: bottomBounds.centerSlice(
                                        Self.contentRenderer.dimension(of: text).height),
                                      with: scaled)
        }
    }

    public override func bottomBounds(_ node: AbstractPackageNode) -> Rectangle {
        guard let node = node as? PackageDescriptionNode else {
            preconditionFailure("not a package description node")
        }
        let contentsBounds = Self.contentRenderer.dimension(of: node.contents)
        var width = GeomUtils.max(contentsBounds.width + 2 * Self.padding, Self.defaultWidth)
        let height = GeomUtils.max(contentsBounds.height + 2 * Self.padding, Self.defaultBottomHeight)
        let topDimension = topDimension(node)
        width = GeomUtils.max(width, topDimension.width + (Self.defaultWidth - Self.defaultTopWidth))
        return Rectangle(x: node.position.x, y: node.position.y + topDimension.height,
                         width: width, height: height)
    }
}
