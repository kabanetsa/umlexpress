//
//  RecentFilesQueue.swift
//  UMLExpress
//
//  Port of org.jetuml.application.RecentFilesQueue
//  (JetUML 3.10, GPL-3, (C) McGill University).
//

import Foundation

/// A fixed-size queue of the files most recently used by the application.
public final class RecentFilesQueue {

    /// The number of files kept in the queue.
    public static let capacity = 5

    private static let defaultsKey = "recentFiles"

    private var files: [URL] = []
    private let defaults: UserDefaults

    /// Creates a queue backed by the given defaults (the standard domain by default).
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.array(forKey: Self.defaultsKey) as? [String] {
            // Drop entries whose file is gone, and entries that are the same file written
            // differently: a stale name in the welcome window looks like a stray file.
            var seen: Set<String> = []
            for candidate in stored.map({ URL(fileURLWithPath: $0) }) where Self.isUsable(candidate) {
                let key = Self.key(for: candidate)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                files.append(candidate.standardizedFileURL)
            }
        }
    }

    /// The recent files, most recent first.
    public var recentFiles: [URL] { files }

    /// The parent directory of the most recent file, or the current directory.
    public var mostRecentDirectory: URL {
        files.first?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    /// Adds a file as the most recent one; the oldest entry is dropped at capacity.
    /// Empty names and files that do not exist are ignored.
    public func add(_ file: URL) {
        let url = file.standardizedFileURL
        let key = Self.key(for: url)
        files.removeAll { Self.key(for: $0) == key }
        guard Self.isUsable(url) else {
            persist()
            return
        }
        files.insert(url, at: 0)
        if files.count > Self.capacity {
            files.removeLast(files.count - Self.capacity)
        }
        persist()
    }

    /// Removes a file from the queue.
    public func remove(_ file: URL) {
        let key = Self.key(for: file)
        files.removeAll { Self.key(for: $0) == key }
        persist()
    }

    /// Empties the queue.
    public func clear() {
        files.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(files.map(\.path), forKey: Self.defaultsKey)
    }

    /// A key that identifies the file regardless of how its path is spelled.
    ///
    /// APFS is case-insensitive by default on macOS, so `Diagram.jet` and `diagram.jet` are
    /// the same file; the key folds the case to keep a single entry for it.
    private static func key(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
    }

    private static func isUsable(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }
}
