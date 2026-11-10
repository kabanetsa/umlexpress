//
//  IconRendering.swift
//  UMLExpress
//
//  Port of the `createIcon` methods of the element renderers
//  (JetUML 3.10, GPL-3, (C) McGill University).
//
//  JetUML renders the palette icons by drawing the element itself into a 25×25 JavaFX canvas;
//  this port draws into an off-screen Core Graphics bitmap and returns a `CGImage`, so the
//  rendering layer stays free of AppKit.
//

import CoreGraphics
import Foundation
import UMLGeometry
import UMLModel

/// Renders tool-palette icons of diagram elements.
public enum IconRendering {

    /// The side of an icon, in points (the original `BUTTON_SIZE`).
    public static let buttonSize = 25

    /// The margin around the element inside the icon (`OFFSET` in the original).
    public static let offset = 3

    /// The number of pixels per point of the generated icons.
    ///
    /// Three pixels per point keeps the thin strokes of the small shapes crisp both on
    /// retina displays and when the image is scaled to the button size.
    public static let scaleFactor = 3

    /// Creates a bitmap context for an icon, already flipped to a y-down system.
    ///
    /// The background stays **transparent**: the original JavaFX canvas is transparent too,
    /// and an opaque square behind the drawing shows up as a border inside the highlighted
    /// bezel of the selected tool.
    public static func makeContext() -> CGContext? {
        let pixels = buttonSize * scaleFactor
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
            bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.scaleBy(x: CGFloat(scaleFactor), y: CGFloat(scaleFactor))
        // The drawing code works in a y-down system, as on the canvas.
        context.translateBy(x: 0, y: CGFloat(buttonSize))
        context.scaleBy(x: 1, y: -1)
        context.clear(CGRect(x: 0, y: 0, width: CGFloat(buttonSize), height: CGFloat(buttonSize)))
        return context
    }

    /// Draws an element scaled to fit an icon and returns the resulting image.
    ///
    /// `draw` draws the element into a context whose user space is the icon area.
    public static func icon(drawing draw: (any RenderingContext) -> Void) -> CGImage? {
        guard let context = makeContext() else {
            return nil
        }
        draw(CGRenderingContext(context))
        return context.makeImage()
    }

    /// The scale that fits `width × height` into an icon (`BUTTON_SIZE - OFFSET` in the
    /// original).
    public static func fitScale(width: Int, height: Int) -> CGFloat {
        let available = CGFloat(buttonSize - offset)
        let scaleX = available / CGFloat(max(width, 1))
        let scaleY = available / CGFloat(max(height, 1))
        return min(scaleX, scaleY)
    }
}
