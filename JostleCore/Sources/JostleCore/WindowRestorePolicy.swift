public enum WindowRestorePolicy {
    public static func restoredFrame(
        savedFrame: Frame,
        currentFrame: Frame,
        grabbedAt point: Point
    ) -> Frame {
        let horizontalFraction = fraction(
            value: point.x - currentFrame.origin.x,
            length: currentFrame.size.width
        )
        let verticalFraction = fraction(
            value: point.y - currentFrame.origin.y,
            length: currentFrame.size.height
        )
        return Frame(
            x: point.x - savedFrame.size.width * horizontalFraction,
            y: point.y - savedFrame.size.height * verticalFraction,
            width: savedFrame.size.width,
            height: savedFrame.size.height
        )
    }

    private static func fraction(value: Double, length: Double) -> Double {
        guard length > 0 else { return 0.5 }
        return min(1, max(0, value / length))
    }
}
