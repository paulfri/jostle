// Scroll transformation and synthetic-delivery behavior is adapted from
// LinearMouse under the MIT License.
// Copyright (c) 2021-2026 LinearMouse
// See THIRD_PARTY_NOTICES.md for source and license details.

import CoreGraphics
import Foundation
import JostleCore

final class ScrollCustomizationController {
    private static let timerInterval: TimeInterval = 1.0 / 120.0

    private var engine: ScrollSmoothingEngine?
    private var engineSettings: EffectiveScrollSettings?
    private var timer: Timer?
    private var lastFlags: CGEventFlags = []
    private var touchSeriesActive = false
    private var momentumSeriesActive = false
    private var horizontalRemainder = 0.0
    private var verticalRemainder = 0.0
    private let eventSink: (CGEvent) -> Void

    init(eventSink: @escaping (CGEvent) -> Void = { $0.post(tap: .cgSessionEventTap) }) {
        self.eventSink = eventSink
    }

    /// Mutates the supplied event in place. Returns true only when the original
    /// event should be suppressed because every active axis is emitted later.
    func handle(_ event: CGEvent, settings: EffectiveScrollSettings) -> Bool {
        guard event.type == .scrollWheel else { return false }

        applyLinearTransform(to: event, settings: settings)

        let smoothsHorizontal = settings.horizontal.smoothing != nil
        let smoothsVertical = settings.vertical.smoothing != nil
        guard smoothsHorizontal || smoothsVertical else {
            cancel()
            return false
        }

        if engineSettings != settings || engine == nil {
            cancel()
            engineSettings = settings
            engine = ScrollSmoothingEngine(
                horizontal: settings.horizontal.smoothing,
                vertical: settings.vertical.smoothing
            )
        }

        let deltaX = pixelDelta(axis: 2, event: event)
        let deltaY = pixelDelta(axis: 1, event: event)
        let handlesHorizontal = smoothsHorizontal && deltaX != 0
        let handlesVertical = smoothsVertical && deltaY != 0
        guard handlesHorizontal || handlesVertical else { return false }

        lastFlags = event.flags
        engine?.feed(
            deltaX: handlesHorizontal ? deltaX : 0,
            deltaY: handlesVertical ? deltaY : 0,
            timestamp: ProcessInfo.processInfo.systemUptime,
            inputKind: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
                ? .continuousGesture
                : .wheel
        )
        startTimerIfNeeded()

        if handlesHorizontal { zero(axis: 2, event: event) }
        if handlesVertical { zero(axis: 1, event: event) }
        return !hasDelta(event)
    }

    func cancel() {
        postSeriesEndingsIfNeeded()
        timer?.invalidate()
        timer = nil
        engine = nil
        engineSettings = nil
        touchSeriesActive = false
        momentumSeriesActive = false
        horizontalRemainder = 0
        verticalRemainder = 0
    }

    private func applyLinearTransform(
        to event: CGEvent,
        settings: EffectiveScrollSettings
    ) {
        applyLinearAxis(settings.horizontal, axis: 2, event: event)
        applyLinearAxis(settings.vertical, axis: 1, event: event)
    }

    private func applyLinearAxis(
        _ settings: EffectiveScrollAxisSettings,
        axis: Int,
        event: CGEvent
    ) {
        var integer = event.getIntegerValueField(integerField(axis))
        var fixed = event.getDoubleValueField(fixedField(axis))
        var point = event.getDoubleValueField(pointField(axis))
        let signSource = point != 0 ? point : (fixed != 0 ? fixed : Double(integer))
        guard signSource != 0 else { return }
        let sign = signSource < 0 ? -1.0 : 1.0

        if settings.reverse {
            integer = -integer
            fixed = -fixed
            point = -point
        }

        switch settings.distance {
        case .automatic:
            break
        case let .lines(lines):
            let direction: Int64 = (settings.reverse ? -sign : sign) < 0 ? -1 : 1
            integer = direction * Int64(lines)
            fixed = Double(integer)
            point = Double(integer)
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 0)
        case let .pixels(pixels):
            let direction = (settings.reverse ? -sign : sign) < 0 ? -1.0 : 1.0
            point = direction * pixels
            fixed = point
            integer = Int64((point / 10).rounded(.towardZero))
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        }

        if settings.acceleration != 1 {
            integer = Int64((Double(integer) * settings.acceleration).rounded(.towardZero))
            fixed *= settings.acceleration
            point *= settings.acceleration
        }
        if settings.speed != 0 {
            let direction = point != 0 ? (point < 0 ? -1.0 : 1.0) : (fixed < 0 ? -1.0 : 1.0)
            point += direction * settings.speed
            fixed += direction * settings.speed / 10
            integer = Int64(direction) * max(1, Int64(abs(point) / 10))
        }

        // Core Graphics couples these representations, so use values captured
        // before any write and finish with point delta, the representation most
        // continuous-scroll clients consume.
        event.setIntegerValueField(integerField(axis), value: integer)
        event.setDoubleValueField(fixedField(axis), value: fixed)
        event.setDoubleValueField(pointField(axis), value: point)
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.timerInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func tick() {
        guard let engine else {
            cancel()
            return
        }
        guard let emission = engine.advance(to: ProcessInfo.processInfo.systemUptime) else {
            if !engine.isRunning { cancel() }
            return
        }
        post(emission)
        if !engine.isRunning {
            timer?.invalidate()
            timer = nil
            self.engine = nil
            engineSettings = nil
            horizontalRemainder = 0
            verticalRemainder = 0
        }
    }

    private func post(_ emission: ScrollSmoothingEngine.Emission) {
        let hasMovement = abs(emission.deltaX) >= 0.01 || abs(emission.deltaY) >= 0.01
        if !hasMovement,
           emission.phase != .touchEnded,
           emission.phase != .momentumEnded {
            return
        }

        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: 0,
            wheel3: 0
        ) else {
            return
        }
        // Keep the event factory's current pointer location. Reusing the source
        // scroll location throughout a momentum tail can repeatedly pull the
        // cursor toward an obsolete screen position.
        event.flags = lastFlags
        event.setIntegerValueField(.eventSourceUserData, value: EventTapController.syntheticEventMarker)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)

        setSynthetic(axis: 2, value: emission.deltaX, event: event)
        setSynthetic(axis: 1, value: emission.deltaY, event: event)
        applyPhase(emission.phase, event: event)

        let hasPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
            || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
        guard hasMovement || hasPhase else { return }
        eventSink(event)
    }

    private func applyPhase(_ phase: ScrollSmoothingEngine.Phase, event: CGEvent) {
        let allowsBouncing = engineSettings.map {
            ($0.horizontal.smoothing?.bouncing ?? true)
                && ($0.vertical.smoothing?.bouncing ?? true)
        } ?? false
        guard allowsBouncing else { return }

        switch phase {
        case .touchBegan:
            touchSeriesActive = true
            event.setIntegerValueField(
                .scrollWheelEventScrollPhase,
                value: Int64(CGScrollPhase.began.rawValue)
            )
        case .touchChanged:
            let phase: CGScrollPhase = touchSeriesActive ? .changed : .began
            touchSeriesActive = true
            event.setIntegerValueField(
                .scrollWheelEventScrollPhase,
                value: Int64(phase.rawValue)
            )
        case .touchEnded:
            guard touchSeriesActive else { return }
            touchSeriesActive = false
            event.setIntegerValueField(
                .scrollWheelEventScrollPhase,
                value: Int64(CGScrollPhase.ended.rawValue)
            )
        case .momentumBegan:
            momentumSeriesActive = true
            event.setIntegerValueField(
                .scrollWheelEventMomentumPhase,
                value: Int64(CGMomentumScrollPhase.begin.rawValue)
            )
        case .momentumChanged:
            let phase: CGMomentumScrollPhase = momentumSeriesActive ? .continuous : .begin
            momentumSeriesActive = true
            event.setIntegerValueField(
                .scrollWheelEventMomentumPhase,
                value: Int64(phase.rawValue)
            )
        case .momentumEnded:
            guard momentumSeriesActive else { return }
            momentumSeriesActive = false
            event.setIntegerValueField(
                .scrollWheelEventMomentumPhase,
                value: Int64(CGMomentumScrollPhase.end.rawValue)
            )
        }
    }

    private func postSeriesEndingsIfNeeded() {
        guard touchSeriesActive || momentumSeriesActive,
              let event = CGEvent(
                  scrollWheelEvent2Source: nil,
                  units: .pixel,
                  wheelCount: 2,
                  wheel1: 0,
                  wheel2: 0,
                  wheel3: 0
              ) else {
            return
        }
        event.flags = lastFlags
        event.setIntegerValueField(.eventSourceUserData, value: EventTapController.syntheticEventMarker)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        if touchSeriesActive {
            event.setIntegerValueField(
                .scrollWheelEventScrollPhase,
                value: Int64(CGScrollPhase.ended.rawValue)
            )
        }
        if momentumSeriesActive {
            event.setIntegerValueField(
                .scrollWheelEventMomentumPhase,
                value: Int64(CGMomentumScrollPhase.end.rawValue)
            )
        }
        eventSink(event)
    }

    private func setSynthetic(axis: Int, value: Double, event: CGEvent) {
        let pointValue: Double
        if axis == 1 {
            let combined = value + verticalRemainder
            pointValue = Double(Int64(combined.rounded(.towardZero)))
            verticalRemainder = combined - pointValue
        } else {
            let combined = value + horizontalRemainder
            pointValue = Double(Int64(combined.rounded(.towardZero)))
            horizontalRemainder = combined - pointValue
        }
        event.setIntegerValueField(integerField(axis), value: Int64((value / 12).rounded(.towardZero)))
        event.setDoubleValueField(fixedField(axis), value: value)
        event.setDoubleValueField(pointField(axis), value: pointValue)
    }

    private func pixelDelta(axis: Int, event: CGEvent) -> Double {
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let integer = event.getIntegerValueField(integerField(axis))
        let fixed = event.getDoubleValueField(fixedField(axis))
        let point = event.getDoubleValueField(pointField(axis))
        if !continuous {
            if integer != 0 { return Double(integer) * 36 }
            if point != 0 { return point * 36 }
            if fixed != 0 { return fixed * 360 }
        }
        if fixed != 0 { return fixed }
        if point != 0 { return point }
        return Double(integer) * 36
    }

    private func zero(axis: Int, event: CGEvent) {
        event.setIntegerValueField(integerField(axis), value: 0)
        event.setDoubleValueField(fixedField(axis), value: 0)
        event.setDoubleValueField(pointField(axis), value: 0)
    }

    private func hasDelta(_ event: CGEvent) -> Bool {
        [1, 2].contains { axis in
            event.getIntegerValueField(integerField(axis)) != 0
                || event.getDoubleValueField(fixedField(axis)) != 0
                || event.getDoubleValueField(pointField(axis)) != 0
        }
    }

    private func integerField(_ axis: Int) -> CGEventField {
        axis == 1 ? .scrollWheelEventDeltaAxis1 : .scrollWheelEventDeltaAxis2
    }

    private func fixedField(_ axis: Int) -> CGEventField {
        axis == 1 ? .scrollWheelEventFixedPtDeltaAxis1 : .scrollWheelEventFixedPtDeltaAxis2
    }

    private func pointField(_ axis: Int) -> CGEventField {
        axis == 1 ? .scrollWheelEventPointDeltaAxis1 : .scrollWheelEventPointDeltaAxis2
    }
}
