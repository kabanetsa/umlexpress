//
//  SVGRenderingContext.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.SvgRenderingContext
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  Ported verbatim (including the hard-coded black/white colours of the light theme)
//  so that the output can be compared with the Java reference renderings.
//

import Foundation
import UMLGeometry

/// Builds an SVG image.
public final class SVGRenderingContext: RenderingContext {

    /// Margin of white space around the diagram, in pixels.
    private static let marginPixels = 7

    /// Amount of pixels to subtract from the font size, to make sure it fits.
    private static let fontAdjustment = 0.25

    private var svg: [String] = []

    /// Creates an SVG image using `viewport` as the viewport area.
    public init(viewport: Rectangle) {
        let rootStart = "<svg viewBox=\"\(viewport.x - Self.marginPixels) \(viewport.y - Self.marginPixels) "
            + "\(viewport.width + Self.marginPixels * 2) \(viewport.height + Self.marginPixels * 2)\" "
            + "xmlns=\"http://www.w3.org/2000/svg\">\n"
            + "<defs><filter id=\"shadow\" x=\"-10%\" y=\"-10%\">\n"
            + "  <feGaussianBlur in=\"SourceGraphic\" stdDeviation=\"1\" />\n"
            + "</filter></defs>"
            + "<g transform=\"translate(0.5,0.5)\" stroke-width=\"0.75\">"
        svg.append(rootStart)
    }

    // MARK: - RenderingContext

    public func strokeLine(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ color: RGBAColor, _ style: LineStyle) {
        svg.append("<line x1=\"\(x1)\" y1=\"\(y1)\" x2=\"\(x2)\" y2=\"\(y2)\" stroke=\"black\""
            + Self.lineStyle(style) + "/>")
    }

    public func drawRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        if hasShadow {
            svg.append("<rect width=\"\(rectangle.width)\" height=\"\(rectangle.height)\" "
                + "x=\"\(rectangle.x + 2)\" y=\"\(rectangle.y + 2)\""
                + " stroke=\"none\" fill=\"lightgray\" style=\"filter:url(#shadow);\"/>")
        }
        svg.append("<rect width=\"\(rectangle.width)\" height=\"\(rectangle.height)\" "
            + "x=\"\(rectangle.x)\" y=\"\(rectangle.y)\""
            + " stroke=\"black\" fill=\"white\"/>")
    }

    public func drawOval(_ x: Int, _ y: Int, width: Int, height: Int,
                         fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        let color = fill == RGBAColor.white ? "white" : "black"
        if hasShadow {
            svg.append("<ellipse rx=\"\(width / 2)\" ry=\"\(height / 2)\" "
                + "cx=\"\(x + width / 2 + 2)\" cy=\"\(y + height / 2 + 2)\""
                + " stroke=\"none\" fill=\"lightgray\" style=\"filter:url(#shadow);\"/>")
        }
        svg.append("<ellipse rx=\"\(width / 2)\" ry=\"\(height / 2)\" "
            + "cx=\"\(x + width / 2)\" cy=\"\(y + height / 2)\""
            + " stroke=\"black\" fill=\"\(color)\"/>")
    }

    public func strokeArc(centerX: Int, centerY: Int, radius: Int, startAngle: Int, length: Int, color: RGBAColor) {
        let fullCircle = 360
        let start = Double(startAngle) * Double.pi / 180.0
        let end = Double((startAngle - length) % fullCircle) * Double.pi / 180.0
        let x1 = Int(Double(centerX) + (sin(start) * Double(radius)).rounded())
        let y1 = Int(Double(centerY) + (cos(start) * Double(radius)).rounded())
        let x2 = Int(Double(centerX) + (sin(end) * Double(radius)).rounded())
        let y2 = Int(Double(centerY) + (cos(end) * Double(radius)).rounded())
        svg.append("<path d=\"M \(x1) \(y1) A \(radius) \(radius) 0 1 1 \(x2) \(y2)\" "
            + "stroke=\"black\" fill=\"none\"/>")
    }

    public func strokePath(_ path: [PathCommand], color: RGBAColor, style: LineStyle) {
        emitPath(path, style: style, fill: "none", shadow: false)
    }

    public func drawClosedPath(_ path: [PathCommand], fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        let color: String
        if fill == RGBAColor.white {
            color = "white"
        } else if fill == RGBAColor.black {
            color = "black"
        } else {
            color = "rgb(90%, 90%, 60%)" // The only other colour is for notes.
        }
        if hasShadow {
            emitPath(path, style: .solid, fill: color, shadow: true)
        }
        emitPath(path, style: .solid, fill: color, shadow: false)
    }

    public func drawRoundedRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        if hasShadow {
            svg.append("<rect width=\"\(rectangle.width)\" height=\"\(rectangle.height)\" "
                + "x=\"\(rectangle.x + 2)\" y=\"\(rectangle.y + 2)\" rx=\"10\" ry=\"10\""
                + " stroke=\"none\" fill=\"lightGray\" style=\"filter:url(#shadow);\"/>")
        }
        svg.append("<rect width=\"\(rectangle.width)\" height=\"\(rectangle.height)\" "
            + "x=\"\(rectangle.x)\" y=\"\(rectangle.y)\" rx=\"10\" ry=\"10\""
            + " stroke=\"black\" fill=\"white\"/>")
    }

    public func drawText(_ text: String, bounds: Rectangle, alignment: Alignment, color: RGBAColor,
                         style: TextStyle, fontDimension: FontDimension) {
        // SVG positions the text from the baseline.
        var anchorX = bounds.x
        let anchorY = bounds.maxY - fontDimension.baselineOffset
        var anchor = "start"
        if alignment == .center {
            anchorX = bounds.center().x
            anchor = "middle"
        }
        let weight = style.bold ? "bold" : "normal"
        let fontStyle = style.italic ? "italic" : "normal"
        let fontSize = Double(style.size) - Self.fontAdjustment
        svg.append("<text x=\"\(anchorX)\" y=\"\(anchorY)\" "
            + "font-size=\"\(Self.format(fontSize))px\" "
            + "font-family=\"Arial, Helvetica, sans-serif\" "
            + "font-weight=\"\(weight)\" "
            + "font-style=\"\(fontStyle)\" "
            + "text-anchor=\"\(anchor)\">\(Self.escape(text))</text>")
    }

    // MARK: - Output

    /// The completed SVG document. Should only be called once.
    public func create() -> String {
        (svg + ["</g></svg>"]).joined(separator: "\n")
    }

    /// The lines emitted so far, for testing.
    public var lines: [String] { svg }

    // MARK: - Private

    private func emitPath(_ path: [PathCommand], style: LineStyle, fill: String, shadow: Bool) {
        if shadow {
            let shadowCommands = path.map(Self.describe).joined(separator: " ")
            svg.append("<path d=\"\(shadowCommands)\" stroke=\"none\" fill=\"lightGray\"  "
                + "transform=\"translate(2 2)\" style=\"filter:url(#shadow);\"/>")
            return
        }
        let commands = path.map(Self.describe).joined(separator: " ")
        svg.append("<path d=\"\(commands)\" stroke=\"black\" fill=\"\(fill)\"\(Self.lineStyle(style))/>")
    }

    private static func describe(_ command: PathCommand) -> String {
        switch command {
        case let .move(point):
            "M \(point.x) \(point.y)"
        case let .line(point):
            "L \(point.x) \(point.y)"
        case let .quadCurve(control, point):
            "Q \(control.x) \(control.y) \(point.x) \(point.y)"
        }
    }

    private static func lineStyle(_ style: LineStyle) -> String {
        guard style == .dotted else {
            return ""
        }
        let dashes = style.lineDashes.map { String(format: "%g", $0) }.joined(separator: " ")
        return " stroke-dasharray=\"\(dashes)\""
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Formats a font size with two decimals, as `String.format("%.2f")` in Java.
    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
