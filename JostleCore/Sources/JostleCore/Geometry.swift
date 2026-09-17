public struct Point: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Size: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct Frame: Codable, Equatable, Sendable {
    public var origin: Point
    public var size: Size

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: Point(x: x, y: y), size: Size(width: width, height: height))
    }
}

public enum HorizontalResizeEdge: String, Codable, Equatable, Sendable {
    case none
    case left
    case right
}

public enum VerticalResizeEdge: String, Codable, Equatable, Sendable {
    case none
    case top
    case bottom
}

public struct ResizeSection: Codable, Equatable, Sendable {
    public var horizontalEdge: HorizontalResizeEdge
    public var verticalEdge: VerticalResizeEdge

    public init(horizontalEdge: HorizontalResizeEdge, verticalEdge: VerticalResizeEdge) {
        self.horizontalEdge = horizontalEdge
        self.verticalEdge = verticalEdge
    }

    public static let none = ResizeSection(horizontalEdge: .none, verticalEdge: .none)

    public var changesOrigin: Bool {
        horizontalEdge == .left || verticalEdge == .top
    }
}

public enum GeometryPolicy {
    public static func resizeSection(for point: Point, in frame: Frame) -> ResizeSection {
        let relativeX = point.x - frame.origin.x
        let relativeY = point.y - frame.origin.y

        let horizontalEdge: HorizontalResizeEdge
        if relativeX < frame.size.width / 3 {
            horizontalEdge = .left
        } else if relativeX > 2 * frame.size.width / 3 {
            horizontalEdge = .right
        } else {
            horizontalEdge = .none
        }

        let verticalEdge: VerticalResizeEdge
        if relativeY < frame.size.height / 3 {
            verticalEdge = .top
        } else if relativeY > 2 * frame.size.height / 3 {
            verticalEdge = .bottom
        } else {
            verticalEdge = .none
        }

        return ResizeSection(horizontalEdge: horizontalEdge, verticalEdge: verticalEdge)
    }

    public static func move(_ origin: Point, deltaX: Double, deltaY: Double) -> Point {
        Point(x: origin.x + deltaX, y: origin.y + deltaY)
    }

    public static func resize(
        _ frame: Frame,
        section: ResizeSection,
        deltaX: Double,
        deltaY: Double
    ) -> Frame {
        var result = frame
        let truncatedX = deltaX.rounded(.towardZero)
        let truncatedY = deltaY.rounded(.towardZero)

        switch section.horizontalEdge {
        case .right:
            result.size.width += truncatedX
        case .left:
            result.size.width -= truncatedX
            result.origin.x += truncatedX
        case .none:
            break
        }

        switch section.verticalEdge {
        case .bottom:
            result.size.height += truncatedY
        case .top:
            result.size.height -= truncatedY
            result.origin.y += truncatedY
        case .none:
            break
        }

        return result
    }
}
