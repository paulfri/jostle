import AppKit
import ApplicationServices
import JostleCore

struct RunningApplicationInfo: Equatable {
    let key: String
    let name: String
}

struct AccessibilityWindowTarget {
    let element: AXUIElement
    let application: NSRunningApplication?
    let applicationInfo: RunningApplicationInfo?
}

final class AccessibilityWindowSystem {
    func window(at point: CGPoint) -> AccessibilityWindowTarget? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var hitElement: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &hitElement
        ) == .success, let hitElement else {
            return nil
        }

        let windowElement: AXUIElement
        if stringAttribute(kAXRoleAttribute as CFString, of: hitElement) == (kAXWindowRole as String) {
            windowElement = hitElement
        } else if let containingWindow = elementAttribute(kAXWindowAttribute as CFString, of: hitElement) {
            windowElement = containingWindow
        } else {
            return nil
        }

        var processIdentifier: pid_t = 0
        let application: NSRunningApplication?
        if AXUIElementGetPid(windowElement, &processIdentifier) == .success {
            application = NSRunningApplication(processIdentifier: processIdentifier)
        } else {
            application = nil
        }

        let applicationInfo = application.flatMap { application -> RunningApplicationInfo? in
            guard let key = ApplicationIdentity.key(
                bundleIdentifier: application.bundleIdentifier,
                localizedName: application.localizedName
            ) else {
                return nil
            }
            return RunningApplicationInfo(
                key: key,
                name: application.localizedName.flatMap { $0.isEmpty ? nil : $0 } ?? key
            )
        }

        return AccessibilityWindowTarget(
            element: windowElement,
            application: application,
            applicationInfo: applicationInfo
        )
    }

    func frame(of target: AccessibilityWindowTarget) -> Frame? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, of: target.element),
              let size = sizeAttribute(kAXSizeAttribute as CFString, of: target.element) else {
            return nil
        }
        return Frame(
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        )
    }

    func origin(of target: AccessibilityWindowTarget) -> Point? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, of: target.element) else {
            return nil
        }
        return Point(x: position.x, y: position.y)
    }

    func bringToFront(_ target: AccessibilityWindowTarget) {
        target.application?.activate(options: [.activateIgnoringOtherApps])
        AXUIElementPerformAction(target.element, kAXRaiseAction as CFString)
    }

    @discardableResult
    func apply(_ commands: [GestureCommand], to target: AccessibilityWindowTarget) -> Bool {
        for command in commands {
            let error: AXError
            switch command {
            case let .setPosition(position):
                var point = CGPoint(x: position.x, y: position.y)
                guard let value = AXValueCreate(.cgPoint, &point) else { return false }
                error = AXUIElementSetAttributeValue(
                    target.element,
                    kAXPositionAttribute as CFString,
                    value
                )
            case let .setSize(size):
                var cgSize = CGSize(width: size.width, height: size.height)
                guard let value = AXValueCreate(.cgSize, &cgSize) else { return false }
                error = AXUIElementSetAttributeValue(
                    target.element,
                    kAXSizeAttribute as CFString,
                    value
                )
            }
            guard error == .success else { return false }
        }
        return true
    }

    private func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        copyAttribute(attribute, of: element) as? String
    }

    private func elementAttribute(_ attribute: CFString, of element: AXUIElement) -> AXUIElement? {
        guard let value = copyAttribute(attribute, of: element),
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func pointAttribute(_ attribute: CFString, of element: AXUIElement) -> CGPoint? {
        guard let value = axValueAttribute(attribute, of: element) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeAttribute(_ attribute: CFString, of element: AXUIElement) -> CGSize? {
        guard let value = axValueAttribute(attribute, of: element) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private func axValueAttribute(_ attribute: CFString, of element: AXUIElement) -> AXValue? {
        guard let value = copyAttribute(attribute, of: element),
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXValue.self)
    }

    private func copyAttribute(_ attribute: CFString, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value
    }
}
