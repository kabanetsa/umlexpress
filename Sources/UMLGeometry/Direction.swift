//
//  Direction.swift
//  UMLExpress
//
//  Port of org.jetuml.geom.Direction (JetUML 3.10, GPL-3, (C) McGill University).
//  Immutable direction in the 2D plane, represented as an angle in degrees in
//  [0, 359], where 0 is "north" and angles increase clockwise.
//

import Foundation

/// A direction in the 2D plane, expressed as a whole number of degrees from north,
/// increasing clockwise.
///
/// Implemented as an immutable reference type with a flyweight cache, mirroring the
/// original `@Immutable @Flyweight` Java class: `Direction.fromAngle(_:)` always
/// returns the same instance for the same angle.
public final class Direction: Hashable, Sendable, CustomStringConvertible {

    private static let degreesInCircle = 360
    private static let degreesInHalfCircle = degreesInCircle / 2

    /// Flyweight instances, keyed by angle. Port of `Direction.DIRECTIONS`.
    ///
    /// Built eagerly and immutable afterwards, so the cache is safe to share across
    /// threads (Swift 6 strict concurrency) while preserving the flyweight contract.
    private static let cache: [Direction] = (0..<degreesInCircle).map { Direction(angle: $0) }

    public static let north = Direction.fromAngle(0)
    public static let east = Direction.fromAngle(90)
    public static let south = Direction.fromAngle(180)
    public static let west = Direction.fromAngle(270)

    private let angleInDegrees: Int

    private init(angle: Int) {
        precondition(angle >= 0 && angle < Direction.degreesInCircle)
        self.angleInDegrees = angle
    }

    /// The direction for the given angle.
    /// - Precondition: `angle` is in `[0, 359]`.
    public static func fromAngle(_ angle: Int) -> Direction {
        precondition(angle >= 0 && angle < degreesInCircle)
        return cache[angle]
    }

    /// The direction of the line between `start` and `end`.
    /// - Precondition: `start != end`.
    public static func fromLine(_ start: Point, _ end: Point) -> Direction {
        precondition(start != end)
        return fromAngle(asAngle(width: end.x - start.x, height: end.y - start.y))
    }

    /// True iff this direction is one of the four cardinal directions.
    public var isCardinal: Bool {
        self == Direction.north || self == Direction.east
            || self == Direction.south || self == Direction.west
    }

    /// This direction turned clockwise by `degrees`.
    ///
    /// The original computes `(angle + degrees) % 360` and constructs a direction
    /// directly; for negative input that would violate its own precondition, so the
    /// result is normalized into `[0, 359]` here.
    public func rotatedBy(_ degrees: Int) -> Direction {
        let sum = angleInDegrees + degrees
        return Direction.fromAngle(((sum % Direction.degreesInCircle) + Direction.degreesInCircle)
            % Direction.degreesInCircle)
    }

    /// This direction turned by 180 degrees.
    public func mirrored() -> Direction {
        Direction.fromAngle((angleInDegrees + Direction.degreesInHalfCircle) % Direction.degreesInCircle)
    }

    /// True iff this direction is strictly between `start` and `end` (both exclusive).
    ///
    /// If `start` and `end` are 180 degrees apart this returns false.
    public func isBetween(_ start: Direction, _ end: Direction) -> Bool {
        precondition(start != end)
        // Adapted from a solution by iforce2d, as in the original.
        let startAngle = Direction.normalize(start.angleInDegrees - angleInDegrees)
        let endAngle = Direction.normalize(end.angleInDegrees - angleInDegrees)
        if startAngle * endAngle >= 0 {
            return false
        }
        return abs(startAngle - endAngle) < Direction.degreesInHalfCircle
    }

    /// True iff this direction has any value in the west cardinal direction.
    public var isWesterly: Bool {
        angleInDegrees > Direction.degreesInHalfCircle && angleInDegrees < Direction.degreesInCircle
    }

    /// True iff this direction has any value in the east cardinal direction.
    public var isEasterly: Bool {
        angleInDegrees > 0 && angleInDegrees < Direction.degreesInHalfCircle
    }

    /// True iff this direction has any value in the north cardinal direction.
    public var isNortherly: Bool {
        angleInDegrees > Direction.degreesInCircle * 3 / 4
            || angleInDegrees < Direction.degreesInHalfCircle / 2
    }

    /// True iff this direction has any value in the south cardinal direction.
    public var isSoutherly: Bool {
        angleInDegrees > Direction.degreesInHalfCircle / 2
            && angleInDegrees < Direction.degreesInCircle * 3 / 4
    }

    /// The angle of this direction, in `[0, 359]`.
    public var asAngle: Int { angleInDegrees }

    /// Shifts the angle into the `]-180, 180]` range.
    private static func normalize(_ angle: Int) -> Int {
        if angle > degreesInHalfCircle {
            return angle - degreesInCircle
        }
        if angle <= -degreesInHalfCircle {
            return angle + degreesInCircle
        }
        return angle
    }

    /// Computes an angle from a width and height so that angle 0 corresponds to
    /// `width == 0, height > 0`, i.e. a vector pointing north.
    private static func asAngle(width: Int, height: Int) -> Int {
        // The sign of the height is reversed because the y-coordinate grows downwards
        // in graphics systems.
        let hypothenuse = (Double(width * width + height * height)).squareRoot()
        let normalizedHeight = -Double(height) / hypothenuse

        // arccos is used (instead of arcsin) so that the 90-degree shift needed to
        // align 0 with north is already accounted for.
        var degrees = GeomUtils.round(toDegrees(acos(normalizedHeight)))

        // The angle is negated for the left half-plane.
        if width <= 0 {
            degrees = -degrees
        }

        return (degrees + degreesInCircle) % degreesInCircle
    }

    public static func == (lhs: Direction, rhs: Direction) -> Bool {
        lhs.angleInDegrees == rhs.angleInDegrees
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(angleInDegrees)
    }

    public var description: String {
        "[Direction: \(angleInDegrees) degrees]"
    }
}

/// Radians to degrees, as `Math.toDegrees`.
private func toDegrees(_ radians: Double) -> Double {
    radians * 180.0 / Double.pi
}
