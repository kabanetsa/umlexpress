//
//  CGRenderingContext.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.GraphicsRenderingContext (JetUML 3.10, GPL-3, (C) McGill
//  University) for Core Graphics.
//
//  As in the original, integer coordinates are shifted by 0.5 so that strokes land on
//  pixel centres; the caller must supply a y-down context (an `NSView` with
//  `isFlipped == true`, or a bitmap context set up the same way).
//

import CoreGraphics
import CoreText
import Foundation
import UMLGeometry

/// A rendering context that draws on a Core Graphics context.
public final class CGRenderingContext: RenderingContext {

    private static let fullCircle = 360
    private static let lineWidth = 0.6
    private static let roundedRectangleArc = 20

    private let context: CGContext

    /// Creates a context that draws on `context`.
    public init(_ context: CGContext) {
        self.context = context
        context.setLineWidth(Self.lineWidth)
        // Aligns integer coordinates with the pixel grid, as in the original.
        context.translateBy(x: 0.5, y: 0.5)
    }

    // MARK: - Lines and shapes

    public func strokeLine(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int,
                           _ color: RGBAColor, _ style: LineStyle) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineDash(phase: 0, lengths: style.lineDashes.map { CGFloat($0) })
        context.beginPath()
        context.move(to: CGPoint(x: x1, y: y1))
        context.addLine(to: CGPoint(x: x2, y: y2))
        context.strokePath()
        context.restoreGState()
    }

    public func drawRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        let path = CGPath(rect: rectangle.cgRect, transform: nil)
        fillAndStroke(path, fill: fill, stroke: stroke, closed: true, hasShadow: hasShadow)
    }

    public func drawOval(_ x: Int, _ y: Int, width: Int, height: Int,
                         fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        let path = CGPath(ellipseIn: CGRect(x: x, y: y, width: width, height: height), transform: nil)
        fillAndStroke(path, fill: fill, stroke: stroke, closed: true, hasShadow: hasShadow)
    }

    public func drawRoundedRectangle(_ rectangle: Rectangle, fill: RGBAColor, stroke: RGBAColor,
                                     hasShadow: Bool) {
        let path = CGPath(
            roundedRect: rectangle.cgRect,
            cornerWidth: CGFloat(Self.roundedRectangleArc) / 2,
            cornerHeight: CGFloat(Self.roundedRectangleArc) / 2,
            transform: nil)
        fillAndStroke(path, fill: fill, stroke: stroke, closed: true, hasShadow: hasShadow)
    }

    public func strokeArc(centerX: Int, centerY: Int, radius: Int, startAngle: Int, length: Int,
                          color: RGBAColor) {
        precondition(startAngle >= 0 && startAngle < Self.fullCircle)
        precondition(length > 0 && length <= Self.fullCircle)
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        // The original angles start at the bottom middle and move counter-clockwise, which
        // matches Core Graphics' angle convention for a y-down context.
        let start = Double(startAngle) * Double.pi / 180
        let end = Double(startAngle + length) * Double.pi / 180
        context.beginPath()
        context.addArc(center: CGPoint(x: centerX, y: centerY), radius: CGFloat(radius),
                       startAngle: CGFloat(start), endAngle: CGFloat(end), clockwise: false)
        context.strokePath()
        context.restoreGState()
    }

    public func strokePath(_ path: [PathCommand], color: RGBAColor, style: LineStyle) {
        let cgPath = Self.path(path, closed: false)
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineDash(phase: 0, lengths: style.lineDashes.map { CGFloat($0) })
        context.addPath(cgPath)
        context.strokePath()
        context.restoreGState()
    }

    public func drawClosedPath(_ path: [PathCommand], fill: RGBAColor, stroke: RGBAColor, hasShadow: Bool) {
        let cgPath = Self.path(path, closed: true)
        fillAndStroke(cgPath, fill: fill, stroke: stroke, closed: true, hasShadow: hasShadow)
    }

    // MARK: - Text

    public func drawText(_ text: String, bounds: Rectangle, alignment: Alignment, color: RGBAColor,
                         style: TextStyle, fontDimension: FontDimension) {
        let font = TextFonts.font(for: style)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)

        // The baseline sits `baselineOffset` above the bottom of the box, as in the SVG
        // context of the original.
        let baselineY = bounds.maxY - fontDimension.baselineOffset
        let originX: Int
        switch alignment {
        case .left:
            originX = bounds.x
        case .center:
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            originX = bounds.center().x - GeomUtils.round(Double(width) / 2)
        }

        context.saveGState()
        // The caller draws in a y-down (flipped) context, while CoreText lays glyphs out in a
        // y-up space: without mirroring the text matrix the glyphs come out upside down and
        // appear one line too low (i.e. in the wrong compartment of a node).
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: originX, y: baselineY)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    // MARK: - Helpers

    private func fillAndStroke(_ path: CGPath, fill: RGBAColor, stroke: RGBAColor,
                               closed: Bool, hasShadow: Bool) {
        context.saveGState()
        if hasShadow {
            context.setShadow(offset: CGSize(width: 3, height: 3), blur: 3,
                              color: RGBAColor.lightGray.cgColor)
        }
        context.addPath(path)
        context.setFillColor(fill.cgColor)
        if closed {
            context.fillPath()
        }
        if hasShadow {
            context.setShadow(offset: .zero, blur: 0, color: nil)
        }
        context.addPath(path)
        context.setStrokeColor(stroke.cgColor)
        context.strokePath()
        context.restoreGState()
    }

    private static func path(_ commands: [PathCommand], closed: Bool) -> CGPath {
        let path = CGMutablePath()
        for command in commands {
            switch command {
            case let .move(point):
                path.move(to: CGPoint(x: point.x, y: point.y))
            case let .line(point):
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            case let .quadCurve(control, point):
                path.addQuadCurve(to: CGPoint(x: point.x, y: point.y),
                                  control: CGPoint(x: control.x, y: control.y))
            }
        }
        if closed {
            path.closeSubpath()
        }
        return path
    }
}

/// Creates the CoreText font for a style; shared with `StringRenderer`.
public enum TextFonts {

    /// The CoreText font for a style.
    public static func font(for style: TextStyle) -> CTFont {
        let base = CTFontCreateWithName(style.family as CFString, CGFloat(style.size), nil)
        var traits: CTFontSymbolicTraits = []
        if style.bold {
            traits.insert(.traitBold)
        }
        if style.italic {
            traits.insert(.traitItalic)
        }
        guard !traits.isEmpty else {
            return base
        }
        return CTFontCreateCopyWithSymbolicTraits(base, CGFloat(style.size), nil, traits, traits) ?? base
    }
}

public extension RGBAColor {
    /// The Core Graphics colour of this colour.
    var cgColor: CGColor {
        CGColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}

public extension Rectangle {
    /// The Core Graphics rectangle of this rectangle.
    var cgRect: CGRect {
        CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
}
