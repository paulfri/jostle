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
    static func input(type: CGEventType, flags: CGEventFlags) -> InputEvent {
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
        return InputEvent(type: eventType, button: button, modifiers: modifiers(from: flags))
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
    private var moveDidDrag = false
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
            .otherMouseUp
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
        let input = CGEventInputAdapter.input(type: type, flags: event.flags)
        let configuration = EventPolicyConfiguration(
            sessionActive: sessionActive,
            gestureActive: gestureState.isActive,
            middleClickResize: settings.middleClickResize,
            resizeOnly: settings.resizeOnly,
            requiredModifiers: settings.modifiers
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
            return reduce(.resizeBy(
                deltaX: event.getDoubleValueField(.mouseEventDeltaX),
                deltaY: event.getDoubleValueField(.mouseEventDeltaY),
                timestamp: now
            ))
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
                windowRestoreStore.remember(restoreFrame, for: target.identity)
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

        targetWindow = target
        if resize {
            windowRestoreStore.removeFrame(for: target.identity)
            resetMoveTracking()
        } else {
            moveDidDrag = false
            let savedFrame = windowRestoreStore.frame(for: target.identity)
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
        }
        if !gestureState.isActive {
            targetWindow = nil
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
        resetMoveTracking()
    }

    private func resetMoveTracking() {
        pendingWindowRestore = nil
        gestureRestoreFrame = nil
        moveDidDrag = false
    }
}
