//
//  Dimension.swift
//  UMLExpress
//
//  Port of org.jetuml.geom.Dimension (JetUML 3.10, GPL-3, (C) McGill University).
//  Represents a pair of width and height.
//

/// A pair of width and height, both non-negative.
public struct Dimension: Hashable, Sendable, CustomStringConvertible {

    /// A dimension of zero width and height.
    ///
    /// Port of `Dimension.NULL`; named `null` to keep the correspondence with the original.
    public static let null = Dimension(width: 0, height: 0)

    /// The width. >= 0
    public let width: Int

    /// The height. >= 0
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// A dimension that is the maximum of this dimension and the given extents
    /// for both width and height.
    public func include(_ pWidth: Int, _ pHeight: Int) -> Dimension {
        precondition(pWidth >= 0 && pHeight >= 0)
        return Dimension(width: max(width, pWidth), height: max(height, pHeight))
    }

    public var description: String {
        "Dimension[width=\(width), height=\(height)]"
    }
}
