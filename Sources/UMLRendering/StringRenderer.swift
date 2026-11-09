//
//  StringRenderer.swift
//  UMLExpress
//
//  Port of org.jetuml.rendering.StringRenderer (JetUML 3.10, GPL-3, (C) McGill University).
//
//  JavaFX text metrics are replaced by CoreText (see `TextMeasurer`); the original
//  used a shared `javafx.scene.text.Text` node to obtain layout bounds and the
//  baseline offset.
//

import CoreText
import Foundation
import UMLGeometry

/// Measures text for a given style.
public protocol TextMeasurer: Sendable {
    /// The width and height required to show the string.
    func dimension(of text: String, style: TextStyle) -> UMLGeometry.Dimension
    /// The distance between the top and the baseline of a single line of text.
    func baselineOffset(of style: TextStyle) -> Int
}

/// A `TextMeasurer` backed by CoreText.
public struct CoreTextMeasurer: TextMeasurer {

    public init() {}

    public func dimension(of text: String, style: TextStyle) -> UMLGeometry.Dimension {
        guard !text.isEmpty else {
            return UMLGeometry.Dimension.null
        }
        let font = Self.font(for: style)
        let attributes: [CFString: Any] = [kCTFontAttributeName: font]

        // Multi-line strings are laid out by `StringRenderer.draw` as one box per line, so the
        // measured size must be the widest line by the number of lines. Measuring the whole
        // string as a single CTLine reports one line height and the *sum* of the line widths,
        // which leaves edited nodes too small and shifts everything drawn around them.
        let lines = text.components(separatedBy: "\n")
        var widest = 0.0
        for line in lines where !line.isEmpty {
            let attributed = CFAttributedStringCreate(
                nil, line as CFString, attributes as CFDictionary)!
            let ctLine = CTLineCreateWithAttributedString(attributed)
            widest = max(widest, CTLineGetTypographicBounds(ctLine, nil, nil, nil))
        }
        let lineHeight = Self.lineHeight(of: font)
        return UMLGeometry.Dimension(width: GeomUtils.round(widest),
                                      height: lineHeight * max(lines.count, 1))
    }

    /// The height of one line of text for a font, in whole pixels.
    private static func lineHeight(of font: CTFont) -> Int {
        let attributes: [CFString: Any] = [kCTFontAttributeName: font]
        let attributed = CFAttributedStringCreate(
            nil, "|" as CFString, attributes as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attributed)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        return max(GeomUtils.round(Double(ascent + descent + leading)), 1)
    }

    public func baselineOffset(of style: TextStyle) -> Int {
        GeomUtils.round(Double(CTFontGetAscent(Self.font(for: style))))
    }

    private static func font(for style: TextStyle) -> CTFont {
        TextFonts.font(for: style)
    }
}

/// Renders strings with decorations and alignment.
public struct StringRenderer: Sendable {

    /// Various text decorations.
    public enum Decoration: Sendable {
        case bold
        case italic
        case underlined
    }

    /// The font configuration used by every string renderer.
    ///
    /// The original reads the font from the user preferences; the preference store is
    /// ported in M7, so this static value stands in for it.
    public nonisolated(unsafe) static var baseFont = TextStyle.default

    /// The measurer used for text metrics.
    public nonisolated(unsafe) static var measurer: any TextMeasurer = CoreTextMeasurer()

    private let alignment: Alignment
    private let decorations: Set<Decoration>

    public init(_ alignment: Alignment, _ decorations: Decoration...) {
        self.alignment = alignment
        self.decorations = Set(decorations)
    }

    /// Draws the string inside the bounding box, splitting lines automatically.
    public func draw(_ string: String, in boundingBox: Rectangle, with context: any RenderingContext) {
        var currentY = boundingBox.y
        for line in Self.lines(of: string) {
            drawSingleLine(line, in: Rectangle(x: boundingBox.x, y: currentY,
                                               width: boundingBox.width, height: lineHeight),
                           with: context)
            currentY += lineHeight
        }
    }

    private func drawSingleLine(_ string: String, in boundingBox: Rectangle, with context: any RenderingContext) {
        if string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        context.drawText(string, bounds: boundingBox, alignment: alignment,
                         color: ColorScheme.current.strokeColor, style: font, fontDimension: fontDimension)

        if decorations.contains(.underlined), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let textWidth = dimension(of: string).width
            var x1 = boundingBox.x
            if alignment == .center {
                x1 += (boundingBox.width - textWidth) / 2
            }
            // The underline is positioned in the middle of the baseline offset.
            let y = boundingBox.maxY - fontDimension.baselineOffset / 2
            context.strokeLine(x1, y, x1 + textWidth, y, ColorScheme.current.strokeColor, .solid)
        }
    }

    /// The width and height required to show the string.
    public func dimension(of string: String) -> UMLGeometry.Dimension {
        if string.isEmpty {
            return UMLGeometry.Dimension.null
        }
        return Self.measurer.dimension(of: string, style: font)
    }

    /// The height of one line of text, including skip.
    public var lineHeight: Int {
        dimension(of: "|").height
    }

    /// The dimensions of the current font.
    public var fontDimension: FontDimension {
        let lineHeight = self.lineHeight
        return FontDimension(
            lineHeight: lineHeight,
            baselineOffset: lineHeight - Self.measurer.baselineOffset(of: font))
    }

    /// The font described by the base font plus the decorations of this renderer.
    private var font: TextStyle {
        var font = Self.baseFont
        if decorations.contains(.bold) {
            font.bold = true
        }
        if decorations.contains(.italic) {
            font.italic = true
        }
        return font
    }

    /// The lines of the string, as `String.split("\n")` in Java (no trailing empty line).
    private static func lines(of string: String) -> [String] {
        var lines = string.components(separatedBy: "\n")
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines.isEmpty ? [""] : lines
    }
}
