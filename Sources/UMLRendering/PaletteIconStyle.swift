//
//  PaletteIconStyle.swift
//  UMLExpress
//
//  The visual styles the tool palette can be drawn in.
//
//  JetUML draws every tool icon by rendering the element itself, which is faithful but
//  makes the palette look like a set of tiny diagrams. Other styles keep the same shapes
//  and change only how they are painted, or replace them with a single glyph, so that the
//  palette can be compared without touching the renderers.
//

import CoreGraphics
import UMLModel

/// How the tool-palette icons are painted.
public enum PaletteIconStyle: String, CaseIterable, Sendable {

    /// Faithful miniature of the element: filled shapes with thin strokes and muted
    /// placeholders instead of unreadable text. This is the default.
    case drafting

    /// Outline only: no fills at all, so every tool reads as a line drawing.
    case wireframe

    /// Filled shapes with the strokes and decorations in the system accent colour.
    case accented

    /// A single capital letter on a rounded tile, one letter per element type.
    case monogram

    /// The title of the menu item that selects this style.
    public var menuTitle: String {
        switch self {
        case .drafting: "Portrait of the Element"
        case .wireframe: "Outlines Only"
        case .accented: "Accent Colour"
        case .monogram: "Monogram"
        }
    }

    /// A short description, for the palette sheet and for the plan.
    public var summary: String {
        switch self {
        case .drafting: "Portrait of the element (fills, thin strokes, muted text bars)"
        case .wireframe: "Outline only, no fills"
        case .accented: "Filled shapes with accent-coloured strokes"
        case .monogram: "One capital letter on a rounded tile"
        }
    }
}

/// The settings the icon renderers read while they paint a palette icon.
///
/// A single global switch keeps the change small: every renderer already asks
/// `IconRendering`/`ScaledContext` for its paint, so the style can change the palette
/// without touching the dozens of `createIcon` implementations.
public enum IconStyleSettings {

    /// The style used to draw the palette icons.
    nonisolated(unsafe) public static var current: PaletteIconStyle = .drafting

    /// The colour used for an icon that has no fill.
    public static let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)

    /// The colour of the strokes and decorations of an accent-coloured icon.
    ///
    /// The rendering layer cannot ask AppKit for the system accent colour, so this is a
    /// neutral, well-known blue; the palette view may replace it from the application.
    nonisolated(unsafe) public static var accentColor = RGBAColor(red: 0.0, green: 0.48,
                                                                 blue: 1.0, alpha: 1.0)

    /// The stroke colour an icon uses.
    public static var strokeColor: RGBAColor {
        switch current {
        case .accented: accentColor
        case .drafting, .wireframe, .monogram: ColorScheme.current.strokeColor
        }
    }

    /// The fill of a shape, given the fill the renderer asked for.
    public static func fill(_ requested: RGBAColor) -> RGBAColor {
        switch current {
        case .wireframe: clear
        case .drafting, .accented: requested
        case .monogram: requested
        }
    }

    /// The letter shown by the monogram style for an element type.
    public static func monogram(for element: any DiagramElement) -> String {
        switch element {
        case is ClassNode: "C"
        case is InterfaceNode: "I"
        case is PackageNode: "P"
        case is PackageDescriptionNode: "p"
        case is NoteNode: "N"
        case is ActorNode: "A"
        case is UseCaseNode: "U"
        case is StateNode: "S"
        case is InitialStateNode: "\u{2022}"
        case is FinalStateNode: "\u{25C9}"
        case is ObjectNode: "O"
        case is FieldNode: "F"
        case is ImplicitParameterNode: "L"
        case is PointNode: "\u{00B7}"
        case is GeneralizationEdge: "\u{25B3}"
        case is AggregationEdge: "\u{25C7}"
        case is AssociationEdge: "\u{2014}"
        case is DependencyEdge: "\u{22EF}"
        case is NoteEdge: "\u{2010}"
        case is StateTransitionEdge: "\u{219D}"
        case is CallEdge: "\u{2192}"
        case is ReturnEdge: "\u{2190}"
        case is ObjectReferenceEdge: "\u{21E2}"
        case is ObjectCollaborationEdge: "\u{21E0}"
        case is UseCaseAssociationEdge: "\u{2013}"
        case is UseCaseDependencyEdge: "\u{22EE}"
        case is UseCaseGeneralizationEdge: "\u{25B4}"
        default: "?"
        }
    }
}
