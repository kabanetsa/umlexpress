//
//  RenderingTypes.swift
//  UMLExpress
//
//  Framework-independent replacements for the JavaFX types used by the rendering
//  pipeline (Color, DropShadow, Font, Path/PathElement) plus ports of
//  org.jetuml.rendering.LineStyle and org.jetuml.rendering.FontDimension
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry

/// An RGB colour, independent of the graphics framework.
///
/// Replaces `javafx.scene.paint.Color`. The rendering code compares colours against
/// white/black/note-yellow, so equality with those constants is part of the contract.
public struct RGBAColor: Hashable, Sendable {

    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// A colour from 8-bit components.
    public init(_ red: Int, _ green: Int, _ blue: Int, alpha: Double = 1.0) {
        self.init(red: Double(red) / 255.0, green: Double(green) / 255.0,
                  blue: Double(blue) / 255.0, alpha: alpha)
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
    public static let lightGray = RGBAColor(red: 0.827, green: 0.827, blue: 0.827)
    public static let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
}

/// Line styles and their properties.
public enum LineStyle: Sendable {
    case solid
    case dotted

    /// The dash pattern of this style, in pixels. Empty for a solid line.
    public var lineDashes: [Double] {
        switch self {
        case .solid: []
        case .dotted: [3, 3]
        }
    }
}

/// Metrics on the size of a font.
///
/// - `lineHeight`: the height in pixels of a line of text, including ascender,
///   descender and baseline offset.
/// - `baselineOffset`: the number of pixels between the baseline and the lowest part
///   of the ascender (the original computes `lineHeight - baseline`).
public struct FontDimension: Equatable, Sendable {
    public let lineHeight: Int
    public let baselineOffset: Int

    public init(lineHeight: Int, baselineOffset: Int) {
        self.lineHeight = lineHeight
        self.baselineOffset = baselineOffset
    }
}

/// A font specification, independent of the graphics framework.
public struct TextStyle: Equatable, Sendable {

    public var family: String
    public var size: Int
    public var bold: Bool
    public var italic: Bool

    public init(family: String, size: Int, bold: Bool = false, italic: Bool = false) {
        self.family = family
        self.size = size
        self.bold = bold
        self.italic = italic
    }

    /// The default font, matching the JetUML preference defaults.
    public static let `default` = TextStyle(family: "System", size: 12)
}

/// One command of a path, replacing `javafx.scene.shape.Path` elements.
public enum PathCommand: Equatable, Sendable {
    case move(to: Point)
    case line(to: Point)
    case quadCurve(control: Point, to: Point)
}

/// A target for all drawing operations.
///
/// Two kinds of operations exist (as in the original): stroking a line, and drawing a
/// figure, which is equivalent to filling and stroking.
public protocol RenderingContext: AnyObject {

    /// Strokes a line with a colour and line style.
    func strokeLine(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ color: RGBAColor, _ style: LineStyle)

    /// Draws a rectangle, optionally with a drop shadow.
    func drawRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool)

    /// Draws an oval, optionally with a drop shadow.
    func drawOval(_ x: Int, _ y: Int, width: Int, height: Int,
                  fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool)

    /// Strokes an open arc. Angle 0 is at the bottom middle of the circle; the arc
    /// moves counter-clockwise from the start angle.
    func strokeArc(centerX: Int, centerY: Int, radius: Int, startAngle: Int, length: Int, color: RGBAColor)

    /// Strokes a path.
    func strokePath(_ path: [PathCommand], color: RGBAColor, style: LineStyle)

    /// Strokes and fills a path assumed to be closed.
    func drawClosedPath(_ path: [PathCommand], fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool)

    /// Draws a rounded rectangle, optionally with a drop shadow.
    func drawRoundedRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool)

    /// Draws text centred vertically in `bounds` and aligned horizontally according to
    /// `alignment`.
    func drawText(_ text: String, bounds: Rectangle, alignment: Alignment, color: RGBAColor,
                  style: TextStyle, fontDimension: FontDimension)
}
