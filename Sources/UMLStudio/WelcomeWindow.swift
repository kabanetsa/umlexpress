//
//  WelcomeWindow.swift
//  UMLExpress
//
//  Port of org.jetuml.gui.WelcomeTab (JetUML 3.10, GPL-3, (C) McGill University).
//
//  In JetUML the welcome page is a tab of the editor frame; the port shows it as its own
//  window, which opens at launch when no diagram is loaded.
//

import AppKit
import UMLModel
import UMLRendering

/// Actions requested from the welcome window.
@MainActor
public protocol WelcomeWindowDelegate: AnyObject {
    /// Creates a new diagram of the given kind.
    func newDiagram(_ kind: DiagramKind)
    /// Opens a recent file.
    func openRecent(_ url: URL)
}

/// The window shown at startup with the diagram type shortcuts and recent files.
public final class WelcomeWindowController: NSWindowController {

    /// The object informed about the user's choices.
    public weak var delegate: (any WelcomeWindowDelegate)?

    /// The recent files shown in the window.
    public var recentFiles: [URL] = [] {
        didSet {
            shownRecentFiles = Self.existingFiles(recentFiles)
            rebuildContent()
        }
    }

    /// The recent files actually listed: those that still exist, each of them once.
    private(set) var shownRecentFiles: [URL] = []

    /// Keeps the files that are there and removes duplicates of the same file.
    ///
    /// A file that was deleted or renamed outside the application would otherwise keep
    /// showing up in the welcome window, where it looks like a stray entry.
    static func existingFiles(_ files: [URL]) -> [URL] {
        var seen: Set<String> = []
        return files.filter { url in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            guard exists, !isDirectory.boolValue else {
                return false
            }
            let key = url.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
            return seen.insert(key).inserted
        }
    }

    /// The width of a row of the welcome window.
    private static let rowWidth: CGFloat = 240

    /// The margin around the content, in points.
    private static let margin: CGFloat = 24

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.rowWidth + 2 * Self.margin,
                                height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = "UMLExpress"
        super.init(window: window)
        rebuildContent()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("WelcomeWindowController is created in code")
    }

    /// Shows the window in front of the other windows.
    public func present() {
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Content

    private func rebuildContent() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        let title = NSTextField(labelWithString: "UMLExpress")
        title.font = NSFont.systemFont(ofSize: 26, weight: .semibold)
        stack.addArrangedSubview(title)

        let subtitle = NSTextField(labelWithString: "Create New Diagram")
        subtitle.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        subtitle.textColor = .secondaryLabelColor
        stack.addArrangedSubview(subtitle)

        let kinds: [(String, DiagramKind)] = [
            ("Class Diagram", .class),
            ("Sequence Diagram", .sequence),
            ("State Diagram", .state),
            ("Object Diagram", .object),
            ("Use Case Diagram", .useCase),
        ]
        for (index, entry) in kinds.enumerated() {
            let button = NSButton(title: entry.0, target: self, action: #selector(newDiagram(_:)))
            button.tag = index
            button.bezelStyle = .rounded
            button.widthAnchor.constraint(equalToConstant: Self.rowWidth).isActive = true
            stack.addArrangedSubview(button)
        }

        if !shownRecentFiles.isEmpty {
            let recentLabel = NSTextField(labelWithString: "Recent Files")
            recentLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            recentLabel.textColor = .secondaryLabelColor
            stack.addArrangedSubview(recentLabel)
            for (index, file) in shownRecentFiles.enumerated() {
                let button = NSButton(title: file.lastPathComponent,
                                      target: self, action: #selector(openRecent(_:)))
                button.bezelStyle = .inline
                button.alignment = .left
                button.lineBreakMode = .byTruncatingMiddle
                button.tag = index
                // Two files can share a name in different folders; the full path tells
                // them apart, and a long name no longer stretches the whole window.
                button.toolTip = file.path
                button.widthAnchor.constraint(equalToConstant: Self.rowWidth).isActive = true
                stack.addArrangedSubview(button)
            }
        }

        window?.contentView = stack
        // `NSStackView.fittingSize` counts the insets only on one side, which left the
        // content flush against the right edge of the window; the size is computed here.
        let size = Self.contentSize(of: stack)
        window?.contentMinSize = NSSize(width: size.width, height: 200)
        window?.setContentSize(size)
    }

    /// The size the window needs for all arranged subviews, including the insets.
    static func contentSize(of stack: NSStackView) -> NSSize {
        let insets = stack.edgeInsets
        var width: CGFloat = 0
        var height: CGFloat = 0
        for (index, view) in stack.arrangedSubviews.enumerated() {
            let size = view.fittingSize
            width = max(width, size.width)
            height += size.height
            if index > 0 {
                height += stack.spacing
            }
        }
        return NSSize(width: width + insets.left + insets.right,
                      height: height + insets.top + insets.bottom)
    }

    // MARK: - Actions

    private static let kinds: [DiagramKind] = [.class, .sequence, .state, .object, .useCase]

    @objc private func newDiagram(_ sender: NSButton) {
        guard sender.tag < Self.kinds.count else { return }
        delegate?.newDiagram(Self.kinds[sender.tag])
    }

    @objc private func openRecent(_ sender: NSButton) {
        guard sender.tag < shownRecentFiles.count else { return }
        delegate?.openRecent(shownRecentFiles[sender.tag])
    }
}
