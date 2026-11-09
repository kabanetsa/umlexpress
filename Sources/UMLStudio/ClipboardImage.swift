//
//  ClipboardImage.swift
//  UMLExpress
//
//  Port of the image part of org.jetuml.application.Clipboard
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import AppKit
import UMLModel

/// Copies a rendered diagram to the system clipboard.
@MainActor
public enum ClipboardImage {

    /// The pasteboard types written for a diagram image.
    public static let types: [NSPasteboard.PasteboardType] = [.tiff, .png]

    /// Renders the diagram and writes it to the clipboard, without the background grid
    /// and cropped to the diagram bounds.
    @discardableResult
    public static func copy(_ diagram: Diagram, to pasteboard: NSPasteboard = .general) -> Bool {
        guard let image = DiagramExporter.image(diagram),
              let tiff = image.tiffRepresentation else {
            return false
        }
        pasteboard.clearContents()
        var written = pasteboard.setData(tiff, forType: .tiff)
        if let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            written = pasteboard.setData(png, forType: .png) || written
        }
        return written
    }
}
