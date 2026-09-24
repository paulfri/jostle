import AppKit
import JostleCore

private struct PendingWindowRestore {
    let savedFrame: Frame
    let currentFrame: Frame
    let grabPoint: Point
}

struct RuntimeTimingSummary: Equatable {
    let sampleCount: UInt64
    let averageMicroseconds: Double
    let p95Microseconds: Double
    let p99Microseconds: Double
    let maximumMicroseconds: Double
}

struct InputRuntimeDiagnosticsSnapshot: Equatable {
    let eventTap: RuntimeTimingSummary
    let smoothingTick: RuntimeTimingSummary
    let tapDisabledByTimeoutCount: UInt64
    let tapDisabledByUserInputCount: UInt64
    let jostleSyntheticEventCount: UInt64
}

final class InputRuntimeDiagnostics {
    private struct Histogram {
        static let upperBoundsNanoseconds: [UInt64] = [
            25_000,
            50_000,
            100_000,
            250_000,
            500_000,
            1_000_000,
            2_000_000,
            5_000_000,
            10_000_000,
        ]

        var sampleCount: UInt64 = 0
        var totalNanoseconds: UInt64 = 0
        var maximumNanoseconds: UInt64 = 0
        var bucketCounts = Array(
            repeating: UInt64(0),
            count: upperBoundsNanoseconds.count + 1
        )

        mutating func record(_ durationNanoseconds: UInt64) {
            sampleCount &+= 1
            totalNanoseconds &+= durationNanoseconds
            maximumNanoseconds = max(maximumNanoseconds, durationNanoseconds)
            let bucket = Self.upperBoundsNanoseconds.firstIndex {
                durationNanoseconds <= $0
            } ?? Self.upperBoundsNanoseconds.count
            bucketCounts[bucket] &+= 1
        }

        func summary() -> RuntimeTimingSummary {
            guard sampleCount > 0 else {
                return RuntimeTimingSummary(
                    sampleCount: 0,
                    averageMicroseconds: 0,
                    p95Microseconds: 0,
                    p99Microseconds: 0,
                    maximumMicroseconds: 0
                )
            }
            return RuntimeTimingSummary(
                sampleCount: sampleCount,
                averageMicroseconds: Double(totalNanoseconds) / Double(sampleCount) / 1_000,
                p95Microseconds: percentileMicroseconds(0.95),
                p99Microseconds: percentileMicroseconds(0.99),
                maximumMicroseconds: Double(maximumNanoseconds) / 1_000
            )
        }

        private func percentileMicroseconds(_ percentile: Double) -> Double {
            let target = UInt64(ceil(Double(sampleCount) * percentile))
            var cumulative: UInt64 = 0
            for (index, count) in bucketCounts.enumerated() {
                cumulative &+= count
                if cumulative >= target {
                    if index < Self.upperBoundsNanoseconds.count {
                        return Double(Self.upperBoundsNanoseconds[index]) / 1_000
                    }
                    return Double(maximumNanoseconds) / 1_000
                }
            }
            return Double(maximumNanoseconds) / 1_000
        }
    }

    private let lock = NSLock()
    private var eventTapHistogram = Histogram()
    private var smoothingTickHistogram = Histogram()
    private var tapDisabledByTimeoutCount: UInt64 = 0
    private var tapDisabledByUserInputCount: UInt64 = 0
    private var jostleSyntheticEventCount: UInt64 = 0

    func recordEventTap(
        durationNanoseconds: UInt64,
        type: CGEventType,
        isJostleSynthetic: Bool = false
    ) {
        lock.lock()
        eventTapHistogram.record(durationNanoseconds)
        if type == .tapDisabledByTimeout {
            tapDisabledByTimeoutCount &+= 1
        } else if type == .tapDisabledByUserInput {
            tapDisabledByUserInputCount &+= 1
        }
        if isJostleSynthetic {
            jostleSyntheticEventCount &+= 1
        }
        lock.unlock()
    }

    func recordSmoothingTick(durationNanoseconds: UInt64) {
        lock.lock()
        smoothingTickHistogram.record(durationNanoseconds)
        lock.unlock()
    }

    func snapshot() -> InputRuntimeDiagnosticsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return InputRuntimeDiagnosticsSnapshot(
            eventTap: eventTapHistogram.summary(),
            smoothingTick: smoothingTickHistogram.summary(),
            tapDisabledByTimeoutCount: tapDisabledByTimeoutCount,
            tapDisabledByUserInputCount: tapDisabledByUserInputCount,
            jostleSyntheticEventCount: jostleSyntheticEventCount
        )
    }
}

private func jostleEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
    let isJostleSynthetic = event.getIntegerValueField(.eventSourceUserData)
        == EventTapController.syntheticEventMarker
    let startedAt = DispatchTime.now().uptimeNanoseconds
    let handled = controller.handle(type: type, event: event)
    let finishedAt = DispatchTime.now().uptimeNanoseconds
    controller.recordEventTapDuration(
        finishedAt &- startedAt,
        type: type,
        isJostleSynthetic: isJostleSynthetic
    )
    return handled ? nil : Unmanaged.passUnretained(event)
}

enum CGEventInputAdapter {
    static func input(
        type: CGEventType,
        flags: CGEventFlags,
        clickCount: Int64 = 1,
        keyCode: Int64? = nil,
        mouseButtonNumber: Int64? = nil
    ) -> InputEvent {
        let eventType: InputEventType
        let button: MouseButton
        switch type {
        case .leftMouseDown:
            eventType = .mouseDown
            button = .left
        case .rightMouseDown:
            eventType = .mouseDown
            button = .right
        case .otherMouseDown:
            eventType = .mouseDown
            button = .other
        case .leftMouseDragged:
            eventType = .mouseDragged
            button = .left
        case .rightMouseDragged:
            eventType = .mouseDragged
            button = .right
        case .otherMouseDragged:
            eventType = .mouseDragged
            button = .other
        case .leftMouseUp:
            eventType = .mouseUp
            button = .left
        case .rightMouseUp:
            eventType = .mouseUp
            button = .right
        case .otherMouseUp:
            eventType = .mouseUp
            button = .other
        case .keyDown:
            eventType = .keyDown
            button = .none
        case .tapDisabledByTimeout:
            eventType = .tapDisabledByTimeout
            button = .none
        case .tapDisabledByUserInput:
            eventType = .tapDisabledByUserInput
            button = .none
        default:
            eventType = .unknown
            button = .none
        }
        return InputEvent(
            type: eventType,
            button: button,
            modifiers: modifiers(from: flags),
            clickCount: Int(clickCount),
            keyCode: keyCode.map(Int.init),
            buttonNumber: button == .none ? nil : mouseButtonNumber.map(Int.init)
        )
    }

    static func modifiers(from flags: CGEventFlags) -> Set<Modifier> {
        var modifiers: Set<Modifier> = []
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlphaShift) { modifiers.insert(.capsLock) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }
        return modifiers
    }
}

enum CGEventScrollAdapter {
    static func reverse(_ event: CGEvent) {
        guard event.type == .scrollWheel else { return }
        let integerFields: [CGEventField] = [
            .scrollWheelEventDeltaAxis1,
            .scrollWheelEventDeltaAxis2,
            .scrollWheelEventDeltaAxis3,
        ]
        let doubleFields: [CGEventField] = [
            .scrollWheelEventFixedPtDeltaAxis1,
            .scrollWheelEventFixedPtDeltaAxis2,
            .scrollWheelEventFixedPtDeltaAxis3,
            .scrollWheelEventPointDeltaAxis1,
            .scrollWheelEventPointDeltaAxis2,
            .scrollWheelEventPointDeltaAxis3,
        ]

        // Core Graphics keeps the delta representations coupled. Snapshot them
        // before writing so an earlier write cannot be read and negated twice.
        let integerValues = integerFields.map(event.getIntegerValueField)
        let doubleValues = doubleFields.map(event.getDoubleValueField)
        for (field, value) in zip(integerFields, integerValues) {
            event.setIntegerValueField(field, value: -value)
        }
        for (field, value) in zip(doubleFields, doubleValues) {
            event.setDoubleValueField(field, value: -value)
        }
    }
}

final class EventTapController {
    static let syntheticEventMarker: Int64 = 0x4A_4F_53_54_4C_45

    static func processName(executableURL: URL?, localizedName: String?) -> String? {
        if let name = executableURL?.lastPathComponent, !name.isEmpty {
            return name
        }
        return localizedName.flatMap { $0.isEmpty ? nil : $0 }
    }

    var onRecentApplication: ((RunningApplicationInfo) -> Void)?
    var onToggleKeepAwake: (() -> Void)?

    private let settingsStore: SettingsStore
    private let windowSystem: AccessibilityWindowSystem
    private let frameWriter: WindowFrameWriter
    private let screenGeometryProvider: ScreenGeometryProvider
    private let snapPreviewController: SnapPreviewController
    private let scrollCustomizationController: ScrollCustomizationController
    private let resizeFeedbackController: ResizeFeedbackController
    private let runtimeDiagnostics: InputRuntimeDiagnostics
    private let windowRestoreStore: WindowRestoreStore
    private let gestureConfiguration: GestureConfiguration
    private weak var pointingDeviceProvider: PointingDeviceProviding?
    private let safeMode: Bool
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var gestureState = GestureState.idle
    private var targetWindow: AccessibilityWindowTarget?
    /// Frame writes handed to `frameWriter` for the active gesture, oldest first, with the
    /// frame each asked for and the correction that had been applied when it was submitted.
    private var inFlightFrameWrites: [InFlightFrameWrite] = []
    private var frameWriteGeneration: UInt64 = 0
    /// Sum of every reconciliation applied during the active gesture, as a frame delta.
    private var frameCorrection = Frame(x: 0, y: 0, width: 0, height: 0)
    private var activeSnapFrame: Frame?
    private var pendingWindowRestore: PendingWindowRestore?
    private var gestureRestoreFrame: Frame?
    private var gestureInitialFrame: Frame?
    private var gestureInitialRestoreRecord: WindowRestoreRecord?
    private var moveDidDrag = false
    private var resizeDidDrag = false
    private var ownedActionButton: MouseButton?
    private var pendingFocusWorkItem: DispatchWorkItem?
    private var pendingFocusPoint: CGPoint?
    private var pendingFocusDevice: PointingDeviceInfo?
    private var lastFocusedWindow: AccessibilityWindowIdentity?
    private var activeInputGestureButtonNumber: Int?
    private var activeInputGestureAction: PointerButtonAction?
    private var ownedInputActionButtonNumber: Int?
    private var stopped = false
    private(set) var sessionActive = true
    private(set) var requestedEnabled = true

    var isOperational: Bool {
        guard let eventTap, CFMachPortIsValid(eventTap) else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    var isEnabled: Bool {
        requestedEnabled && isOperational
    }

    var inputCustomizationsRequested: Bool {
        settingsStore.settings.inputCustomization.isEnabled && !safeMode
    }

    var eventTapRequested: Bool {
        !stopped && (requestedEnabled || inputCustomizationsRequested)
    }

    var inputCustomizationsEnabled: Bool {
        inputCustomizationsRequested && isOperational
    }

    var isInSafeMode: Bool { safeMode }
    var diagnosticsSnapshot: InputRuntimeDiagnosticsSnapshot { runtimeDiagnostics.snapshot() }

    fileprivate func recordEventTapDuration(
        _ durationNanoseconds: UInt64,
        type: CGEventType,
        isJostleSynthetic: Bool
    ) {
        runtimeDiagnostics.recordEventTap(
            durationNanoseconds: durationNanoseconds,
            type: type,
            isJostleSynthetic: isJostleSynthetic
        )
    }

    init(
        settingsStore: SettingsStore,
        windowSystem: AccessibilityWindowSystem = AccessibilityWindowSystem(),
        screenGeometryProvider: ScreenGeometryProvider = ScreenGeometryProvider(),
        snapPreviewController: SnapPreviewController = SnapPreviewController(),
        resizeFeedbackController: ResizeFeedbackController = ResizeFeedbackController(),
        windowRestoreStore: WindowRestoreStore = WindowRestoreStore(),
        pointingDeviceProvider: PointingDeviceProviding? = nil,
        safeMode: Bool = false,
        runtimeDiagnostics: InputRuntimeDiagnostics = InputRuntimeDiagnostics(),
        gestureConfiguration: GestureConfiguration
    ) {
        self.settingsStore = settingsStore
        self.windowSystem = windowSystem
        frameWriter = WindowFrameWriter(windowSystem: windowSystem)
        self.screenGeometryProvider = screenGeometryProvider
        self.snapPreviewController = snapPreviewController
        self.resizeFeedbackController = resizeFeedbackController
        self.windowRestoreStore = windowRestoreStore
        self.pointingDeviceProvider = pointingDeviceProvider
        self.safeMode = safeMode
        self.runtimeDiagnostics = runtimeDiagnostics
        scrollCustomizationController = ScrollCustomizationController(
            onTickDuration: runtimeDiagnostics.recordSmoothingTick(durationNanoseconds:)
        )
        self.gestureConfiguration = gestureConfiguration
        frameWriter.onResult = { [weak self] result in
            self?.handleFrameWriteResult(result)
        }
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        stopped = false
        requestedEnabled = true
        return ensureOperational()
    }

    @discardableResult
    func ensureOperational() -> Bool {
        guard eventTapRequested else {
            tearDownEventTap()
            return true
        }

        if let eventTap, CFMachPortIsValid(eventTap) {
            if !CGEvent.tapIsEnabled(tap: eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            if CGEvent.tapIsEnabled(tap: eventTap) {
                return true
            }
        }

        tearDownEventTap()
        return createEventTap()
    }

    func suspend() {
        tearDownEventTap()
    }

    func stop() {
        stopped = true
        requestedEnabled = false
        scrollCustomizationController.cancel()
        tearDownEventTap()
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        requestedEnabled = enabled
        if enabled {
            return ensureOperational()
        }

        let activeInputButton = activeInputGestureButtonNumber
        let canceledInputGesture = activeInputButton != nil && cancelGestureAndRestore()
        if activeInputButton == nil {
            cancelGesture()
        }
        cancelPendingFocus(resetLastWindow: true)
        guard !inputCustomizationsRequested else {
            if canceledInputGesture {
                ownedInputActionButtonNumber = activeInputButton
            }
            return ensureOperational()
        }
        if let eventTap, CFMachPortIsValid(eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        return true
    }

    private func createEventTap() -> Bool {
        let eventMask = [
            CGEventType.leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .leftMouseUp,
            .rightMouseUp,
            .otherMouseUp,
            .mouseMoved,
            .scrollWheel,
            .keyDown
        ].reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: jostleEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGEvent.tapIsEnabled(tap: tap) else {
            tearDownEventTap()
            return false
        }
        return true
    }

    private func tearDownEventTap() {
        cancelGestureForInterruption()
        scrollCustomizationController.cancel()
        cancelPendingFocus(resetLastWindow: true)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    func setSessionActive(_ active: Bool) {
        sessionActive = active
        if !active {
            cancelGestureForInterruption()
            scrollCustomizationController.cancel()
            cancelPendingFocus(resetLastWindow: true)
        }
    }

    func pointingDeviceDidDisconnect() {
        cancelGestureForInterruption()
        scrollCustomizationController.cancel()
        cancelPendingFocus(resetLastWindow: true)
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return false
        }

        let device = inputCustomizationsRequested
            ? pointingDeviceProvider?.device(for: event)
            : nil
        if type == .scrollWheel {
            return handleScroll(event, device: device)
        }
        if type == .mouseMoved {
            scheduleFocusFollowsPointer(at: event.location, device: device)
            return false
        }
        if type == .leftMouseDown
            || type == .rightMouseDown
            || type == .otherMouseDown
            || type == .leftMouseDragged
            || type == .rightMouseDragged
            || type == .otherMouseDragged
            || type == .keyDown {
            cancelPendingFocus(resetLastWindow: true)
        }

        let settings = settingsStore.settings
        let input = CGEventInputAdapter.input(
            type: type,
            flags: event.flags,
            clickCount: event.getIntegerValueField(.mouseEventClickState),
            keyCode: type == .keyDown
                ? event.getIntegerValueField(.keyboardEventKeycode)
                : nil,
            mouseButtonNumber: type == .keyDown
                ? nil
                : event.getIntegerValueField(.mouseEventButtonNumber)
        )

        if (inputCustomizationsRequested
            || activeInputGestureButtonNumber != nil
            || ownedInputActionButtonNumber != nil),
           let handled = handleInputButtonEvent(
               input,
               event: event,
               settings: settings
           ) {
            return handled
        }

        let configuration = EventPolicyConfiguration(
            sessionActive: sessionActive && requestedEnabled,
            gestureActive: gestureState.isActive,
            middleClickResize: settings.middleClickResize,
            resizeOnly: settings.resizeOnly,
            requiredModifiers: settings.modifiers,
            doubleClickActionsEnabled: settings.doubleClickActionsEnabled,
            ownedActionButton: ownedActionButton
        )

        switch EventPolicy.intent(for: input, configuration: configuration) {
        case .passThrough:
            return false
        case .reenableEventTap:
            let inputButtonNumber = activeInputGestureButtonNumber
            let interruptedButton: MouseButton?
            if case .resizing = gestureState {
                interruptedButton = settings.middleClickResize ? .other : .right
            } else if gestureState.isActive {
                interruptedButton = .left
            } else {
                interruptedButton = nil
            }
            cancelGestureForInterruption()
            if let inputButtonNumber {
                ownedInputActionButtonNumber = inputButtonNumber
            } else {
                ownedActionButton = interruptedButton
            }
            if let eventTap, eventTapRequested, CFMachPortIsValid(eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return false
        case .beginMove:
            clearResizeFeedback()
            return beginGesture(at: event.location, resize: false)
        case .beginResize:
            clearSnapPreview()
            let began = beginGesture(at: event.location, resize: true)
            updateResizeFeedback(settings: settings)
            return began
        case .continueMove:
            moveDidDrag = true
            guard performPendingWindowRestore() else { return true }
            updateSnapPreview(at: event.location, settings: settings)
            return reduce(.moveBy(
                deltaX: event.getDoubleValueField(.mouseEventDeltaX),
                deltaY: event.getDoubleValueField(.mouseEventDeltaY),
                timestamp: now
            ))
        case .continueResize:
            if !resizeDidDrag, let targetWindow {
                windowRestoreStore.removeFrame(for: targetWindow.identity)
            }
            resizeDidDrag = true
            let handled = reduce(.resizeBy(
                deltaX: event.getDoubleValueField(.mouseEventDeltaX),
                deltaY: event.getDoubleValueField(.mouseEventDeltaY),
                timestamp: now
            ))
            updateResizeFeedback(settings: settings)
            return handled
        case .toggleMaximize:
            let handled = toggleMaximize(at: event.location, settings: settings)
            ownedActionButton = handled ? input.button : nil
            return handled
        case .snapByRegion:
            let handled = snapByRegion(at: event.location, settings: settings)
            ownedActionButton = handled ? input.button : nil
            return handled
        case .endActionClick:
            ownedActionButton = nil
            return true
        case .cancelGesture:
            if let inputButtonNumber = activeInputGestureButtonNumber {
                let handled = cancelGestureAndRestore()
                ownedInputActionButtonNumber = handled ? inputButtonNumber : nil
                return handled
            }
            let button: MouseButton
            if case .resizing = gestureState {
                button = settings.middleClickResize ? .other : .right
            } else {
                button = .left
            }
            let handled = cancelGestureAndRestore()
            ownedActionButton = handled ? button : nil
            return handled
        case .endGesture:
            if moveDidDrag, case .moving = gestureState {
                updateSnapPreview(at: event.location, settings: settings)
            }
            return endGesture()
        }
    }

    private func handleScroll(
        _ event: CGEvent,
        device: PointingDeviceInfo?
    ) -> Bool {
        guard inputCustomizationsRequested else {
            scrollCustomizationController.cancel()
            return false
        }
        let category = device?.category
            ?? (event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
                ? .trackpad
                : .mouse)
        let application = NSWorkspace.shared.frontmostApplication
        let settings = ScrollProfileResolver.resolve(
            input: settingsStore.settings.inputCustomization,
            deviceKey: device?.id,
            deviceCategory: category,
            applicationBundleIdentifier: application?.bundleIdentifier,
            processName: Self.processName(
                executableURL: application?.executableURL,
                localizedName: application?.localizedName
            )
        )
        return scrollCustomizationController.handle(event, settings: settings)
    }

    private func handleInputButtonEvent(
        _ input: InputEvent,
        event: CGEvent,
        settings: JostleSettings
    ) -> Bool? {
        guard let buttonNumber = input.buttonNumber,
              buttonNumber >= 3 else {
            return nil
        }

        if ownedInputActionButtonNumber == buttonNumber {
            switch input.type {
            case .mouseUp:
                ownedInputActionButtonNumber = nil
                return true
            case .mouseDragged:
                return true
            default:
                break
            }
        }

        if let activeInputGestureButtonNumber,
           buttonNumber != activeInputGestureButtonNumber {
            return nil
        }
        guard activeInputGestureButtonNumber != nil || !gestureState.isActive else {
            return nil
        }

        let action = inputCustomizationsRequested
            ? settings.inputCustomization.action(forButtonNumber: buttonNumber)
            : .systemDefault
        switch PointerButtonGesturePolicy.intent(
            eventType: input.type,
            buttonNumber: buttonNumber,
            configuredAction: action,
            activeButtonNumber: activeInputGestureButtonNumber,
            activeAction: activeInputGestureAction
        ) {
        case .beginMove:
            guard requestedEnabled else { return nil }
            clearResizeFeedback()
            let began = beginGesture(at: event.location, resize: false)
            if began {
                activeInputGestureButtonNumber = buttonNumber
                activeInputGestureAction = .moveWindow
            }
            return began
        case .beginResize:
            guard requestedEnabled else { return nil }
            clearSnapPreview()
            let began = beginGesture(at: event.location, resize: true)
            if began {
                activeInputGestureButtonNumber = buttonNumber
                activeInputGestureAction = .resizeWindow
                updateResizeFeedback(settings: settings)
            }
            return began
        case .continueMove:
            moveDidDrag = true
            guard performPendingWindowRestore() else { return true }
            updateSnapPreview(at: event.location, settings: settings)
            return reduce(.moveBy(
                deltaX: event.getDoubleValueField(.mouseEventDeltaX),
                deltaY: event.getDoubleValueField(.mouseEventDeltaY),
                timestamp: now
            ))
        case .continueResize:
            if !resizeDidDrag, let targetWindow {
                windowRestoreStore.removeFrame(for: targetWindow.identity)
            }
            resizeDidDrag = true
            let handled = reduce(.resizeBy(
                deltaX: event.getDoubleValueField(.mouseEventDeltaX),
                deltaY: event.getDoubleValueField(.mouseEventDeltaY),
                timestamp: now
            ))
            updateResizeFeedback(settings: settings)
            return handled
        case .end:
            if moveDidDrag, case .moving = gestureState {
                updateSnapPreview(at: event.location, settings: settings)
            }
            let handled = endGesture()
            activeInputGestureButtonNumber = nil
            activeInputGestureAction = nil
            return handled
        case .passThrough:
            break
        }

        guard input.type == .mouseDown,
              action != .systemDefault,
              !action.beginsWindowGesture else {
            return nil
        }
        let handled = performInputAction(action, at: event.location, settings: settings)
        if handled {
            ownedInputActionButtonNumber = buttonNumber
        }
        return handled
    }

    private func performInputAction(
        _ action: PointerButtonAction,
        at point: CGPoint,
        settings: JostleSettings
    ) -> Bool {
        switch action {
        case .systemDefault, .moveWindow, .resizeWindow:
            return false
        case .back:
            return postCommandShortcut(keyCode: 33)
        case .forward:
            return postCommandShortcut(keyCode: 30)
        case .toggleMaximize:
            return requestedEnabled && toggleMaximize(at: point, settings: settings)
        case .tileLeft:
            return requestedEnabled
                && snapWindow(at: point, target: .leftHalf, settings: settings)
        case .tileRight:
            return requestedEnabled
                && snapWindow(at: point, target: .rightHalf, settings: settings)
        case .moveToNextDisplay:
            return requestedEnabled && moveWindowToNextDisplay(at: point, settings: settings)
        case .toggleKeepAwake:
            guard let onToggleKeepAwake else { return false }
            onToggleKeepAwake()
            return true
        }
    }

    private func postCommandShortcut(keyCode: CGKeyCode) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            return false
        }
        for event in [keyDown, keyUp] {
            event.flags = .maskCommand
            event.setIntegerValueField(
                .eventSourceUserData,
                value: Self.syntheticEventMarker
            )
            event.post(tap: .cgSessionEventTap)
        }
        return true
    }

    private var now: MonotonicTime {
        DispatchTime.now().uptimeNanoseconds
    }

    private func toggleMaximize(at point: CGPoint, settings: JostleSettings) -> Bool {
        guard let (target, currentFrame) = actionTarget(at: point, settings: settings),
              let screen = screenGeometryProvider.geometry(
                containing: Point(x: point.x, y: point.y)
              ) else {
            return false
        }

        if let record = windowRestoreStore.record(for: target.identity),
           record.kind == .maximized {
            if windowSystem.setFrame(record.frame, of: target) {
                windowRestoreStore.removeFrame(for: target.identity)
            }
            return true
        }

        let restoreFrame = windowRestoreStore.frame(for: target.identity) ?? currentFrame
        let maximizedFrame = SnapPolicy.frame(
            for: .maximize,
            in: screen.visibleFrame,
            gap: settings.snapGap,
            screenMargin: settings.snapScreenMargin
        )
        if windowSystem.setFrame(maximizedFrame, of: target) {
            windowRestoreStore.remember(
                restoreFrame,
                kind: .maximized,
                for: target.identity
            )
        }
        return true
    }

    private func snapByRegion(at point: CGPoint, settings: JostleSettings) -> Bool {
        guard let (target, currentFrame) = actionTarget(at: point, settings: settings),
              let screen = screenGeometryProvider.geometry(
                containing: Point(x: point.x, y: point.y)
              ) else {
            return false
        }

        let section = GeometryPolicy.resizeSection(
            for: Point(x: point.x, y: point.y),
            in: currentFrame
        )
        let snapTarget = SnapPolicy.target(for: section)
        let snapFrame = SnapPolicy.frame(
            for: snapTarget,
            in: screen.visibleFrame,
            gap: settings.snapGap,
            screenMargin: settings.snapScreenMargin
        )
        let restoreFrame = windowRestoreStore.frame(for: target.identity) ?? currentFrame
        if windowSystem.setFrame(snapFrame, of: target) {
            windowRestoreStore.remember(
                restoreFrame,
                kind: .snapped,
                for: target.identity
            )
        }
        return true
    }

    private func snapWindow(
        at point: CGPoint,
        target snapTarget: SnapTarget,
        settings: JostleSettings
    ) -> Bool {
        guard let (target, currentFrame) = actionTarget(at: point, settings: settings),
              let screen = screenGeometryProvider.geometry(
                  containing: Point(x: point.x, y: point.y)
              ) else {
            return false
        }
        let snapFrame = SnapPolicy.frame(
            for: snapTarget,
            in: screen.visibleFrame,
            gap: settings.snapGap,
            screenMargin: settings.snapScreenMargin
        )
        let restoreFrame = windowRestoreStore.frame(for: target.identity) ?? currentFrame
        guard windowSystem.setFrame(snapFrame, of: target) else { return false }
        windowRestoreStore.remember(
            restoreFrame,
            kind: snapTarget == .maximize ? .maximized : .snapped,
            for: target.identity
        )
        return true
    }

    private func moveWindowToNextDisplay(
        at point: CGPoint,
        settings: JostleSettings
    ) -> Bool {
        guard let (target, currentFrame) = actionTarget(at: point, settings: settings) else {
            return false
        }
        let screens = screenGeometryProvider.geometries
        guard screens.count > 1 else { return false }
        let center = Point(
            x: currentFrame.origin.x + currentFrame.size.width / 2,
            y: currentFrame.origin.y + currentFrame.size.height / 2
        )
        guard let sourceIndex = screens.firstIndex(where: { screen in
            center.x >= screen.frame.origin.x
                && center.x <= screen.frame.origin.x + screen.frame.size.width
                && center.y >= screen.frame.origin.y
                && center.y <= screen.frame.origin.y + screen.frame.size.height
        }) else {
            return false
        }
        let source = screens[sourceIndex].visibleFrame
        let destination = screens[(sourceIndex + 1) % screens.count].visibleFrame
        let width = min(currentFrame.size.width, destination.size.width)
        let height = min(currentFrame.size.height, destination.size.height)
        let sourceTravelX = max(1, source.size.width - currentFrame.size.width)
        let sourceTravelY = max(1, source.size.height - currentFrame.size.height)
        let relativeX = min(1, max(0, (currentFrame.origin.x - source.origin.x) / sourceTravelX))
        let relativeY = min(1, max(0, (currentFrame.origin.y - source.origin.y) / sourceTravelY))
        let movedFrame = Frame(
            x: destination.origin.x + relativeX * max(0, destination.size.width - width),
            y: destination.origin.y + relativeY * max(0, destination.size.height - height),
            width: width,
            height: height
        )
        guard windowSystem.setFrame(movedFrame, of: target) else { return false }
        windowRestoreStore.removeFrame(for: target.identity)
        return true
    }

    private func actionTarget(
        at point: CGPoint,
        settings: JostleSettings
    ) -> (AccessibilityWindowTarget, Frame)? {
        frameWriter.flush()
        guard let target = windowSystem.window(at: point),
              let frame = windowSystem.frame(of: target) else {
            return nil
        }
        if !settings.windowControlsEnabled(
            forApplicationKey: target.applicationInfo?.key
        ) {
            return nil
        }
        if let applicationInfo = target.applicationInfo {
            onRecentApplication?(applicationInfo)
        }
        if settings.bringWindowToFront {
            windowSystem.bringToFront(target)
        }
        return (target, frame)
    }

    private func updateSnapPreview(at point: CGPoint, settings: JostleSettings) {
        guard settings.snapEnabled,
              case .moving = gestureState,
              let screen = screenGeometryProvider.geometry(
                containing: Point(x: point.x, y: point.y)
              ),
              let target = SnapPolicy.target(
                for: Point(x: point.x, y: point.y),
                in: screen.frame,
                activationDistance: 12
              ) else {
            clearSnapPreview()
            return
        }

        let frame = SnapPolicy.frame(
            for: target,
            in: screen.visibleFrame,
            gap: settings.snapGap,
            screenMargin: settings.snapScreenMargin
        )
        activeSnapFrame = frame
        snapPreviewController.show(frame: frame)
    }

    private func endGesture() -> Bool {
        let snapTarget = activeSnapFrame
        let target = targetWindow
        let restoreFrame = gestureRestoreFrame
        let didDrag = moveDidDrag
        let wasMoving: Bool
        if case .moving = gestureState {
            wasMoving = true
        } else {
            wasMoving = false
        }

        let handled = reduce(.end(timestamp: now))
        clearSnapPreview()
        clearResizeFeedback()

        if wasMoving, didDrag, let target {
            frameWriter.flush()
            if let snapTarget,
               windowSystem.setFrame(snapTarget, of: target),
               let restoreFrame {
                windowRestoreStore.remember(
                    restoreFrame,
                    kind: .snapped,
                    for: target.identity
                )
            } else {
                windowRestoreStore.removeFrame(for: target.identity)
            }
        }
        resetMoveTracking()
        activeInputGestureButtonNumber = nil
        activeInputGestureAction = nil
        return handled
    }

    private func performPendingWindowRestore() -> Bool {
        guard let pendingWindowRestore, let targetWindow else { return true }
        self.pendingWindowRestore = nil
        let restoredFrame = WindowRestorePolicy.restoredFrame(
            savedFrame: pendingWindowRestore.savedFrame,
            currentFrame: pendingWindowRestore.currentFrame,
            grabbedAt: pendingWindowRestore.grabPoint
        )
        frameWriter.flush()
        guard windowSystem.setFrame(restoredFrame, of: targetWindow) else {
            cancelGesture()
            return false
        }
        resetFrameWriteTracking()
        gestureState = GestureEngine.reduce(
            state: .idle,
            input: .beginMove(frame: restoredFrame, timestamp: now),
            configuration: gestureConfiguration
        ).state
        return true
    }

    private func clearSnapPreview() {
        activeSnapFrame = nil
        snapPreviewController.hide()
    }

    private func updateResizeFeedback(settings: JostleSettings) {
        guard settings.resizeFeedbackEnabled,
              case let .resizing(context) = gestureState else {
            clearResizeFeedback()
            return
        }
        resizeFeedbackController.show(
            frame: context.frame,
            section: context.resizeSection
        )
    }

    private func clearResizeFeedback() {
        resizeFeedbackController.hide()
    }

    private func beginGesture(at point: CGPoint, resize: Bool) -> Bool {
        frameWriter.flush()
        guard let target = windowSystem.window(at: point) else {
            cancelGesture()
            return false
        }
        if !settingsStore.settings.windowControlsEnabled(
            forApplicationKey: target.applicationInfo?.key
        ) {
            cancelGesture()
            return false
        }

        guard let frame = windowSystem.frame(of: target) else {
            cancelGesture()
            return false
        }

        resetMoveTracking()
        targetWindow = target
        gestureInitialFrame = frame
        gestureInitialRestoreRecord = windowRestoreStore.record(for: target.identity)
        if !resize {
            let savedFrame = gestureInitialRestoreRecord?.frame
            gestureRestoreFrame = savedFrame ?? frame
            pendingWindowRestore = savedFrame.map {
                PendingWindowRestore(
                    savedFrame: $0,
                    currentFrame: frame,
                    grabPoint: Point(x: point.x, y: point.y)
                )
            }
        }
        if let applicationInfo = target.applicationInfo {
            onRecentApplication?(applicationInfo)
        }
        if settingsStore.settings.bringWindowToFront {
            windowSystem.bringToFront(target)
        }

        if resize {
            let section = GeometryPolicy.resizeSection(
                for: Point(x: point.x, y: point.y),
                in: frame
            )
            return reduce(.beginResize(frame: frame, section: section, timestamp: now))
        }
        return reduce(.beginMove(frame: frame, timestamp: now))
    }

    private func scheduleFocusFollowsPointer(
        at point: CGPoint,
        device: PointingDeviceInfo?
    ) {
        let settings = settingsStore.settings
        guard requestedEnabled,
              sessionActive,
              !gestureState.isActive,
              settings.hasEnabledFocusFollowsPointerRule else {
            cancelPendingFocus(resetLastWindow: false)
            return
        }

        pendingFocusPoint = point
        pendingFocusDevice = device
        let configuredDelay = max(0, settings.focusFollowsPointerDelay)
        if configuredDelay == 0, pendingFocusWorkItem != nil {
            return
        }
        pendingFocusWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let point = pendingFocusPoint else { return }
            applyFocusFollowsPointer(at: point, device: pendingFocusDevice)
        }
        pendingFocusWorkItem = workItem
        let delay = configuredDelay == 0 ? 0.016 : configuredDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func applyFocusFollowsPointer(
        at point: CGPoint,
        device: PointingDeviceInfo?
    ) {
        pendingFocusWorkItem = nil
        pendingFocusPoint = nil
        pendingFocusDevice = nil
        let settings = settingsStore.settings
        guard requestedEnabled,
              sessionActive,
              !gestureState.isActive,
              NSEvent.pressedMouseButtons == 0,
              settings.hasEnabledFocusFollowsPointerRule,
              let target = windowSystem.window(at: point),
              target.identity.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              settings.focusFollowsPointerEnabled(
                  forApplicationKey: target.applicationInfo?.key,
                  deviceKey: device?.id,
                  deviceCategory: device?.category ?? .unknown
              ) else {
            return
        }
        if target.identity == lastFocusedWindow, target.application?.isActive == true {
            return
        }

        windowSystem.bringToFront(target)
        lastFocusedWindow = target.identity
    }

    private func cancelPendingFocus(resetLastWindow: Bool) {
        pendingFocusWorkItem?.cancel()
        pendingFocusWorkItem = nil
        pendingFocusPoint = nil
        pendingFocusDevice = nil
        if resetLastWindow {
            lastFocusedWindow = nil
        }
    }

    @discardableResult
    private func reduce(_ input: GestureInput) -> Bool {
        let minimumWindowSize: Size?
        if case .resizing = gestureState {
            minimumWindowSize = gestureConfiguration.minimumWindowSize
        } else {
            minimumWindowSize = nil
        }
        let transition = GestureEngine.reduce(
            state: gestureState,
            input: input,
            configuration: gestureConfiguration
        )
        gestureState = transition.state

        if !transition.commands.isEmpty {
            guard let targetWindow else {
                cancelGesture()
                return true
            }
            frameWriteGeneration &+= 1
            if let requested = gestureState.context?.frame {
                inFlightFrameWrites.append(InFlightFrameWrite(
                    generation: frameWriteGeneration,
                    requested: requested,
                    correctionAtSubmit: frameCorrection
                ))
            }
            frameWriter.submit(WindowFrameWriter.Request(
                generation: frameWriteGeneration,
                target: targetWindow,
                commands: transition.commands,
                minimumWindowSize: minimumWindowSize
            ))
        }
        if !gestureState.isActive {
            targetWindow = nil
            resetFrameWriteTracking()
        }
        return true
    }

    private struct InFlightFrameWrite {
        var generation: UInt64
        var requested: Frame
        var correctionAtSubmit: Frame
    }

    /// Folds what the app actually did with a write back into the gesture. Only the
    /// difference from the request matters, so an app that ignores nothing costs nothing,
    /// and an app that clamps (a minimum size, a screen edge) keeps later deltas anchored
    /// to the frame it allowed instead of to one it refused.
    private func handleFrameWriteResult(_ result: WindowFrameWriter.Result) {
        guard gestureState.isActive,
              let targetWindow,
              targetWindow.identity == result.identity else {
            return
        }
        guard let actual = result.actualFrame else {
            cancelGesture()
            return
        }
        guard let index = inFlightFrameWrites.firstIndex(where: { $0.generation == result.generation }) else {
            return
        }
        let write = inFlightFrameWrites[index]
        // Older entries were coalesced away by the writer and will never report.
        inFlightFrameWrites.removeSubrange(...index)

        // Restate the request in terms of the frame as corrected since it was submitted.
        var requested = write.requested
        requested.origin.x += frameCorrection.origin.x - write.correctionAtSubmit.origin.x
        requested.origin.y += frameCorrection.origin.y - write.correctionAtSubmit.origin.y
        requested.size.width += frameCorrection.size.width - write.correctionAtSubmit.size.width
        requested.size.height += frameCorrection.size.height - write.correctionAtSubmit.size.height
        guard requested != actual else { return }

        gestureState = GestureEngine.reduce(
            state: gestureState,
            input: .reconcileFrame(requested: requested, actual: actual),
            configuration: gestureConfiguration
        ).state
        frameCorrection.origin.x += actual.origin.x - requested.origin.x
        frameCorrection.origin.y += actual.origin.y - requested.origin.y
        frameCorrection.size.width += actual.size.width - requested.size.width
        frameCorrection.size.height += actual.size.height - requested.size.height
        if case .resizing = gestureState {
            updateResizeFeedback(settings: settingsStore.settings)
        }
    }

    private func resetFrameWriteTracking() {
        inFlightFrameWrites.removeAll()
        frameCorrection = Frame(x: 0, y: 0, width: 0, height: 0)
    }

    private func cancelGestureForInterruption() {
        if !cancelGestureAndRestore() {
            cancelGesture()
        }
    }

    private func cancelGestureAndRestore() -> Bool {
        guard gestureState.isActive else { return false }
        let target = targetWindow
        let initialFrame = gestureInitialFrame
        let initialRecord = gestureInitialRestoreRecord

        cancelGesture()

        if let target, let initialFrame {
            frameWriter.flush()
            _ = windowSystem.setFrame(initialFrame, of: target)
            if let initialRecord {
                windowRestoreStore.remember(
                    initialRecord.frame,
                    kind: initialRecord.kind,
                    for: target.identity
                )
            } else {
                windowRestoreStore.removeFrame(for: target.identity)
            }
        }
        return true
    }

    private func cancelGesture() {
        clearSnapPreview()
        clearResizeFeedback()
        if moveDidDrag,
           pendingWindowRestore == nil,
           let targetWindow {
            windowRestoreStore.removeFrame(for: targetWindow.identity)
        }
        let transition = GestureEngine.reduce(
            state: gestureState,
            input: .cancel(timestamp: now),
            configuration: gestureConfiguration
        )
        gestureState = transition.state
        targetWindow = nil
        resetFrameWriteTracking()
        ownedActionButton = nil
        ownedInputActionButtonNumber = nil
        activeInputGestureButtonNumber = nil
        activeInputGestureAction = nil
        resetMoveTracking()
    }

    private func resetMoveTracking() {
        pendingWindowRestore = nil
        gestureRestoreFrame = nil
        gestureInitialFrame = nil
        gestureInitialRestoreRecord = nil
        moveDidDrag = false
        resizeDidDrag = false
    }
}
