import Combine
import CoreGraphics
import CryptoKit
import Darwin
import Foundation
import IOKit.hid
import JostleCore

struct PointingDeviceInfo: Equatable, Identifiable {
    let id: String
    let displayName: String
    let category: PointingDeviceCategory
    let registryID: UInt64?
}

protocol PointingDeviceProviding: AnyObject {
    var devices: [PointingDeviceInfo] { get }
    func device(for event: CGEvent) -> PointingDeviceInfo?
}

private func jostleDeviceMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard result == kIOReturnSuccess, let context else { return }
    Unmanaged<PointingDeviceManager>.fromOpaque(context)
        .takeUnretainedValue()
        .deviceMatched(device)
}

private func jostleDeviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard result == kIOReturnSuccess, let context else { return }
    Unmanaged<PointingDeviceManager>.fromOpaque(context)
        .takeUnretainedValue()
        .deviceRemoved(device)
}

private func jostleInputValueReceived(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard result == kIOReturnSuccess, let context else { return }
    Unmanaged<PointingDeviceManager>.fromOpaque(context)
        .takeUnretainedValue()
        .inputValueReceived(value)
}

// Quartz does not expose a public device identity on CGEvent. Resolve the
// underlying HID sender when the system symbols are available, and fail open
// to a short recent-device window if an OS version does not export them.
private typealias CopyIOHIDEventFunction = @convention(c) (
    CGEvent
) -> Unmanaged<CFTypeRef>?
private typealias IOHIDEventSenderIDFunction = @convention(c) (CFTypeRef) -> UInt64

private enum HIDEventFunctions {
    static let copyEvent: CopyIOHIDEventFunction? = load(
        "CGEventCopyIOHIDEvent",
        as: CopyIOHIDEventFunction.self
    )
    static let senderID: IOHIDEventSenderIDFunction? = load(
        "IOHIDEventGetSenderID",
        as: IOHIDEventSenderIDFunction.self
    )

    private static let processHandle = dlopen(nil, RTLD_LAZY)

    private static func load<T>(_ name: String, as type: T.Type) -> T? {
        guard let processHandle,
              let symbol = dlsym(processHandle, name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }
}

enum PointingDeviceClassifier {
    static func category(
        primaryUsagePage: Int,
        primaryUsage: Int,
        conformsToTouchpad: Bool
    ) -> PointingDeviceCategory? {
        if conformsToTouchpad {
            return .trackpad
        }
        guard primaryUsagePage == kHIDPage_GenericDesktop,
              primaryUsage == kHIDUsage_GD_Mouse
                || primaryUsage == kHIDUsage_GD_Pointer else {
            return nil
        }
        return .mouse
    }
}

final class PointingDeviceManager: ObservableObject, PointingDeviceProviding {
    @Published private(set) var devices: [PointingDeviceInfo] = []
    var onDeviceDisconnected: ((String) -> Void)?

    private let manager: IOHIDManager
    private let lock = NSLock()
    private var devicesByRegistryID: [UInt64: PointingDeviceInfo] = [:]
    private var registryIDByDevice: [IOHIDDevice: UInt64] = [:]
    private var lastActiveDevice: PointingDeviceInfo?
    private var lastActiveTimestamp: TimeInterval?
    private var running = false

    init() {
        manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
    }

    deinit {
        stop()
    }

    func start() {
        guard !running else { return }
        running = true

        let matches: [[String: Int]] = [
            [
                kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
            ],
            [
                kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey: kHIDUsage_GD_Pointer,
            ],
            [
                kIOHIDDeviceUsagePageKey: kHIDPage_Digitizer,
                kIOHIDDeviceUsageKey: kHIDUsage_Dig_TouchPad,
            ],
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, jostleDeviceMatched, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, jostleDeviceRemoved, context)
        IOHIDManagerRegisterInputValueCallback(manager, jostleInputValueReceived, context)
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        if let connected = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            connected.forEach(deviceMatched)
        }
    }

    func stop() {
        guard running else { return }
        running = false
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.commonModes.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        lock.withLock {
            devicesByRegistryID.removeAll()
            registryIDByDevice.removeAll()
            lastActiveDevice = nil
            lastActiveTimestamp = nil
        }
        devices = []
    }

    func device(for event: CGEvent) -> PointingDeviceInfo? {
        let senderID = HIDEventFunctions.copyEvent?(event)
            .flatMap { hidEvent in
                HIDEventFunctions.senderID?(hidEvent.takeRetainedValue())
            }
        let now = ProcessInfo.processInfo.systemUptime
        return lock.withLock {
            if let senderID, let device = devicesByRegistryID[senderID] {
                return device
            }
            guard let lastActiveTimestamp,
                  now - lastActiveTimestamp <= 0.25 else {
                return nil
            }
            return lastActiveDevice
        }
    }

    fileprivate func deviceMatched(_ device: IOHIDDevice) {
        guard running,
              let registryID = Self.registryID(for: device),
              let info = Self.deviceInfo(for: device, registryID: registryID) else {
            return
        }
        lock.withLock {
            devicesByRegistryID[registryID] = info
            registryIDByDevice[device] = registryID
        }
        publishDevices()
    }

    fileprivate func deviceRemoved(_ device: IOHIDDevice) {
        let removed = lock.withLock { () -> PointingDeviceInfo? in
            guard let registryID = registryIDByDevice.removeValue(forKey: device),
                  let info = devicesByRegistryID.removeValue(forKey: registryID) else {
                return nil
            }
            if lastActiveDevice == info {
                lastActiveDevice = nil
                lastActiveTimestamp = nil
            }
            return info
        }
        if let removed {
            publishDevices()
            onDeviceDisconnected?(removed.id)
        }
    }

    fileprivate func inputValueReceived(_ value: IOHIDValue) {
        guard running else { return }
        let element = IOHIDValueGetElement(value)
        let usagePage = Int(IOHIDElementGetUsagePage(element))
        let usage = Int(IOHIDElementGetUsage(element))
        let relevant: Bool
        switch usagePage {
        case kHIDPage_GenericDesktop:
            relevant = usage == kHIDUsage_GD_X
                || usage == kHIDUsage_GD_Y
                || usage == kHIDUsage_GD_Wheel
        case kHIDPage_Button:
            relevant = true
        default:
            relevant = false
        }
        guard relevant,
              IOHIDValueGetIntegerValue(value) != 0,
              let registryID = lock.withLock({
                  registryIDByDevice[IOHIDElementGetDevice(element)]
              }),
              let info = lock.withLock({ devicesByRegistryID[registryID] }) else {
            return
        }
        lock.withLock {
            lastActiveDevice = info
            lastActiveTimestamp = ProcessInfo.processInfo.systemUptime
        }
    }

    private func publishDevices() {
        let snapshot = lock.withLock {
            devicesByRegistryID.values.sorted {
                let order = $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
        }
        if Thread.isMainThread {
            devices = snapshot
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.devices = snapshot
            }
        }
    }

    private static func deviceInfo(
        for device: IOHIDDevice,
        registryID: UInt64
    ) -> PointingDeviceInfo? {
        let name = property(kIOHIDProductKey, of: device) as String? ?? "Pointing Device"
        let vendorID = property(kIOHIDVendorIDKey, of: device) as Int? ?? 0
        let productID = property(kIOHIDProductIDKey, of: device) as Int? ?? 0
        let serial = property(kIOHIDSerialNumberKey, of: device) as String?
        let locationID = property(kIOHIDLocationIDKey, of: device) as Int?
        let transport = property(kIOHIDTransportKey, of: device) as String? ?? "unknown"
        let primaryUsagePage = property(kIOHIDPrimaryUsagePageKey, of: device) as Int? ?? 0
        let primaryUsage = property(kIOHIDPrimaryUsageKey, of: device) as Int? ?? 0
        let conformsToTouchpad = IOHIDDeviceConformsTo(
            device,
            UInt32(kHIDPage_Digitizer),
            UInt32(kHIDUsage_Dig_TouchPad)
        )
        guard let category = PointingDeviceClassifier.category(
            primaryUsagePage: primaryUsagePage,
            primaryUsage: primaryUsage,
            conformsToTouchpad: conformsToTouchpad
        ) else {
            return nil
        }

        let stableIdentity = [
            transport,
            String(vendorID),
            String(productID),
            serial ?? locationID.map(String.init) ?? name,
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(stableIdentity.utf8))
            .prefix(12)
            .map { String(format: "%02x", $0) }
            .joined()

        return PointingDeviceInfo(
            id: "hid-\(digest)",
            displayName: name,
            category: category,
            registryID: registryID
        )
    }

    private static func registryID(for device: IOHIDDevice) -> UInt64? {
        let service = IOHIDDeviceGetService(device)
        guard service != .zero else { return nil }
        var registryID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS else {
            return nil
        }
        return registryID
    }

    private static func property<T>(_ key: String, of device: IOHIDDevice) -> T? {
        IOHIDDeviceGetProperty(device, key as CFString) as? T
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
