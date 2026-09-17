import AppKit
import JostleCore

private struct PendingWindowRestore {
    let savedFrame: Frame
    let currentFrame: Frame
    let grabPoint: Point
}

private func jostleEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(type: type, event: event)
        ? nil
        : Unmanaged.passUnretained(event)
}

enum CGEventInputAdapter {
    static func input(
        type: CGEventType,
        flags: CGEventFlags,
        clickCount: Int64 = 1,
        keyCode: Int64? = nil
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
            keyCode: keyCode.map(Int.init)
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

final class EventTapController {
    var onRecentApplication: ((RunningApplicationInfo) -> Void)?

    private let settingsStore: SettingsStore
    private let windowSystem: AccessibilityWindowSystem
    private let screenGeometryProvider: ScreenGeometryProvider
    private let snapPreviewController: SnapPreviewController
    private let windowRestoreStore: WindowRestoreStore
    private let gestureConfiguration: GestureConfiguration
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var gestureState = GestureState.idle
    private var targetWindow: AccessibilityWindowTarget?
    private var activeSnapFrame: Frame?
    private var pendingWindowRestore: PendingWindowRestore?
    private var gestureRestoreFrame: Frame?
    private var gestureInitialFrame: Frame?
    private var gestureInitialRestoreRecord: WindowRestoreRecord?
    private var moveDidDrag = false
    private var resizeDidDrag = false
    private var ownedActionButton: MouseButton?
    private(set) var sessionActive = true
    private(set) var isEnabled = false

    init(
        settingsStore: SettingsStore,
        windowSystem: AccessibilityWindowSystem = AccessibilityWindowSystem(),
        screenGeometryProvider: ScreenGeometryProvider = ScreenGeometryProvider(),
        snapPreviewController: SnapPreviewController = SnapPreviewController(),
        windowRestoreStore: WindowRestoreStore = WindowRestoreStore(),
        gestureConfiguration: GestureConfiguration
    ) {
        self.settingsStore = settingsStore
        self.windowSystem = windowSystem
        self.screenGeometryProvider = screenGeometryProvider
        self.snapPreviewController = snapPreviewController
        self.windowRestoreStore = windowRestoreStore
        self.gestureConfiguration = gestureConfiguration
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }
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
        isEnabled = true
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        cancelGesture()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        isEnabled = false
    }

    func setEnabled(_ enabled: Bool) {
        guard let eventTap else {
            isEnabled = false
            return
        }
        if !enabled {
            cancelGesture()
        }
        CGEvent.tapEnable(tap: eventTap, enable: enabled)
        isEnabled = enabled
    }

    func setSessionActive(_ active: Bool) {
        sessionActive = active
        if !active {
            cancelGesture()
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        let settings = settingsStore.settings
        let input = CGEventInputAdapter.input(
            type: type,
            flags: event.flags,
            clickCount: event.getIntegerValueField(.mouseEventClickState),
            keyCode: type == .keyDown
                ? event.getIntegerValueField(.keyboardEventKeycode)
                : nil
        )
        let configuration = EventPolicyConfiguration(
            sessionActive: sessionActive,
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
            if let eventTap, isEnabled {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return false
        case .beginMove:
            return beginGesture(at: event.location, resize: false)
        case .beginResize:
            clearSnapPreview()
            return beginGesture(at: event.location, resize: true)
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
            return reduce(.resizeBy(
                deltaX: event.getDoubleValueField(.mouseEventDeltaX),
                deltaY: event.getDoubleValueField(.mouseEventDeltaY),
                timestamp: now
            ))
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

    private func actionTarget(
        at point: CGPoint,
        settings: JostleSettings
    ) -> (AccessibilityWindowTarget, Frame)? {
        guard let target = windowSystem.window(at: point),
              let frame = windowSystem.frame(of: target) else {
            return nil
        }
        if let applicationInfo = target.applicationInfo,
           settings.excludedApplications[applicationInfo.key] != nil {
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

        if wasMoving, didDrag, let target {
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
        guard windowSystem.setFrame(restoredFrame, of: targetWindow) else {
            cancelGesture()
            return false
        }
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

    private func beginGesture(at point: CGPoint, resize: Bool) -> Bool {
        guard let target = windowSystem.window(at: point) else {
            cancelGesture()
            return false
        }
        if let applicationInfo = target.applicationInfo,
           settingsStore.settings.excludedApplications[applicationInfo.key] != nil {
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

    @discardableResult
    private func reduce(_ input: GestureInput) -> Bool {
        let transition = GestureEngine.reduce(
            state: gestureState,
            input: input,
            configuration: gestureConfiguration
        )
        gestureState = transition.state

        if !transition.commands.isEmpty {
            guard let targetWindow,
                  windowSystem.apply(transition.commands, to: targetWindow) else {
                cancelGesture()
                return true
            }
            if case .resizing = gestureState,
               let constrainedFrame = windowSystem.frame(of: targetWindow) {
                gestureState = GestureEngine.reduce(
                    state: gestureState,
                    input: .synchronizeFrame(constrainedFrame),
                    configuration: gestureConfiguration
                ).state
            }
        }
        if !gestureState.isActive {
            targetWindow = nil
        }
        return true
    }

    private func cancelGestureAndRestore() -> Bool {
        guard gestureState.isActive else { return false }
        let target = targetWindow
        let initialFrame = gestureInitialFrame
        let initialRecord = gestureInitialRestoreRecord

        cancelGesture()

        if let target, let initialFrame {
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
        ownedActionButton = nil
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
