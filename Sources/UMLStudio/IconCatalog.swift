//
//  IconCatalog.swift
//  UMLExpress
//
//  The action icons of org.jetuml.gui (JetUML 3.10, GPL-3, (C) McGill University).
//
//  JetUML ships its UI icons as 16×16 PNG files in `icons/16x16` and loads them through
//  `ImageLoader`/`IconLoader`. They are copied verbatim into this target's resources, so
//  the menu and toolbar icons are the original ones. The tool palette, in contrast, is
//  drawn by the element renderers (see `DiagramElementRenderer.createIcon`), exactly as
//  in the original.
//

import AppKit
import Foundation

/// The icons shipped with the application, addressed by their file name.
public enum IconCatalog {

    /// The nominal size of the action icons, in points.
    public static let iconSize = 16.0

    /// The name of the directory that holds the 16×16 action icons.
    public static let iconDirectoryName = "Icons16"

    /// The directories searched for the icons, in order of preference.
    ///
    /// In the application bundle the icons are copied into `Contents/Resources/Icons16`;
    /// under `swift test` they come from the SwiftPM resource bundle. Both are checked
    /// before the bundle SwiftPM generates, whose fallback path only exists on the machine
    /// that built the package.
    private static var installedDirectories: [URL] {
        var directories: [URL] = []
        if let resources = Bundle.main.resourceURL {
            directories.append(resources.appendingPathComponent(iconDirectoryName))
            directories.append(resources
                .appendingPathComponent("UMLExpress_UMLStudio.bundle")
                .appendingPathComponent(iconDirectoryName))
        }
        directories.append(Bundle.main.bundleURL
            .appendingPathComponent("UMLExpress_UMLStudio.bundle")
            .appendingPathComponent(iconDirectoryName))
        return directories
    }

    /// The icons of the SwiftPM resource bundle, which only exists next to the build
    /// products; touched last, because the generated accessor fails when it is missing.
    private static var swiftPackageDirectory: URL? {
        Bundle.module.resourceURL?.appendingPathComponent(iconDirectoryName)
    }

    /// The file of an icon, or nil when no copy is installed.
    public static func url(named name: String) -> URL? {
        let fileName = "\(name).png"
        for directory in installedDirectories {
            let candidate = directory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        guard let packageDirectory = swiftPackageDirectory else {
            return nil
        }
        let candidate = packageDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    /// An icon, or nil when the application does not ship it.
    ///
    /// - Parameter name: the file name without the extension, for example `document-new`.
    public static func image(named name: String) -> NSImage? {
        guard let url = url(named: name), let image = NSImage(contentsOf: url) else {
            return nil
        }
        // The originals carry a non-72 dpi resolution, which AppKit would otherwise use to
        // compute a logical size; toolbar icons must be drawn at 16 points.
        image.size = NSSize(width: iconSize, height: iconSize)
        return image
    }

    /// An icon, falling back to an SF Symbol when the resource is missing.
    ///
    /// The fallback keeps the UI usable when the application is built without the icons
    /// (they are a presentation detail, never a feature).
    public static func image(named name: String, fallback symbolName: String) -> NSImage? {
        image(named: name) ?? NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }
}
