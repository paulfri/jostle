public enum SnapTarget: String, Codable, Equatable, Sendable {
    case leftHalf
    case rightHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case maximize
}

public enum SnapPolicy {
    public static func target(
        for pointer: Point,
        in screenFrame: Frame,
        activationDistance: Double
    ) -> SnapTarget? {
        let distance = max(0, activationDistance)
        let minimumX = screenFrame.origin.x
        let maximumX = minimumX + screenFrame.size.width
        let minimumY = screenFrame.origin.y
        let maximumY = minimumY + screenFrame.size.height

        guard pointer.x >= minimumX - distance,
              pointer.x <= maximumX + distance,
              pointer.y >= minimumY - distance,
              pointer.y <= maximumY + distance else {
            return nil
        }

        let atLeft = pointer.x <= minimumX + distance
        let atRight = pointer.x >= maximumX - distance
        let atTop = pointer.y <= minimumY + distance
        let atBottom = pointer.y >= maximumY - distance

        switch (atLeft, atRight, atTop, atBottom) {
        case (true, false, true, false):
            return .topLeftQuarter
        case (false, true, true, false):
            return .topRightQuarter
        case (true, false, false, true):
            return .bottomLeftQuarter
        case (false, true, false, true):
            return .bottomRightQuarter
        case (_, _, true, false):
            return .maximize
        case (true, false, false, false):
            return .leftHalf
        case (false, true, false, false):
            return .rightHalf
        default:
            return nil
        }
    }

    public static func frame(
        for target: SnapTarget,
        in visibleFrame: Frame,
        gap: Double,
        screenMargin: Double
    ) -> Frame {
        let maximumMargin = max(0, min(visibleFrame.size.width, visibleFrame.size.height) / 2)
        let margin = min(max(0, screenMargin), maximumMargin)
        let usableFrame = Frame(
            x: visibleFrame.origin.x + margin,
            y: visibleFrame.origin.y + margin,
            width: max(0, visibleFrame.size.width - 2 * margin),
            height: max(0, visibleFrame.size.height - 2 * margin)
        )
        let horizontalGap = min(max(0, gap), usableFrame.size.width)
        let verticalGap = min(max(0, gap), usableFrame.size.height)
        let halfWidth = max(0, (usableFrame.size.width - horizontalGap) / 2)
        let halfHeight = max(0, (usableFrame.size.height - verticalGap) / 2)
        let rightX = usableFrame.origin.x + halfWidth + horizontalGap
        let bottomY = usableFrame.origin.y + halfHeight + verticalGap

        switch target {
        case .leftHalf:
            return Frame(
                x: usableFrame.origin.x,
                y: usableFrame.origin.y,
                width: halfWidth,
                height: usableFrame.size.height
            )
        case .rightHalf:
            return Frame(
                x: rightX,
                y: usableFrame.origin.y,
                width: halfWidth,
                height: usableFrame.size.height
            )
        case .topLeftQuarter:
            return Frame(
                x: usableFrame.origin.x,
                y: usableFrame.origin.y,
                width: halfWidth,
                height: halfHeight
            )
        case .topRightQuarter:
            return Frame(
                x: rightX,
                y: usableFrame.origin.y,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomLeftQuarter:
            return Frame(
                x: usableFrame.origin.x,
                y: bottomY,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomRightQuarter:
            return Frame(
                x: rightX,
                y: bottomY,
                width: halfWidth,
                height: halfHeight
            )
        case .maximize:
            return usableFrame
        }
    }
}
