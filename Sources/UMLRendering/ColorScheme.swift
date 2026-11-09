//
//  ColorScheme.swift
//  UMLExpress
//
//  Port of org.jetuml.gui.ColorScheme (JetUML 3.10, GPL-3, (C) McGill University).
//

import UMLGeometry

/// The colour schemes that can be applied to the diagram.
public enum ColorScheme: Sendable {
    case light
    case dark

    /// The canvas colour.
    public var background: RGBAColor {
        switch self {
        case .light: RGBAColor.white
        case .dark: RGBAColor(7, 7, 7)
        }
    }

    /// The grid colour.
    public var grid: RGBAColor {
        switch self {
        case .light: RGBAColor(220, 220, 220)
        case .dark: RGBAColor(40, 40, 40)
        }
    }

    /// The fill colour.
    public var fill: RGBAColor {
        switch self {
        case .light: RGBAColor.white
        case .dark: RGBAColor(31, 31, 31)
        }
    }

    /// The stroke colour.
    public var strokeColor: RGBAColor {
        switch self {
        case .light: RGBAColor.black
        case .dark: RGBAColor.white
        }
    }

    /// The note colour.
    public var noteColor: RGBAColor {
        switch self {
        case .light: RGBAColor(red: 0.9, green: 0.9, blue: 0.6)
        case .dark: RGBAColor(30, 63, 102)
        }
    }

    /// True if this scheme draws drop shadows (the dark scheme uses transparency).
    public var hasShadows: Bool {
        self == .light
    }

    /// The colour of the drop shadow.
    public var shadowColor: RGBAColor {
        switch self {
        case .light: RGBAColor.lightGray
        case .dark: RGBAColor.clear
        }
    }

    /// The scheme currently selected in the user interface.
    ///
    /// The original reads the `darkMode` user preference; the preference store is
    /// ported in M7, so the default is the light scheme for now.
    public nonisolated(unsafe) static var current: ColorScheme = .light
}
