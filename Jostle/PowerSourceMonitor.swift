import Foundation
import IOKit.ps

private func jostlePowerSourceChanged(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.refresh()
}

enum PowerSource: Equatable {
    case external
    case battery
    case unknown
}

final class PowerSourceMonitor {
    var onChange: ((PowerSource, PowerSource) -> Void)?

    private(set) var currentSource: PowerSource
    private var runLoopSource: CFRunLoopSource?

    init() {
        currentSource = Self.readCurrentSource()
    }

    deinit {
        stop()
    }

    func start() {
        guard runLoopSource == nil,
              let source = IOPSNotificationCreateRunLoopSource(
                  jostlePowerSourceChanged,
                  Unmanaged.passUnretained(self).toOpaque()
              )?.takeRetainedValue() else {
            return
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    func stop() {
        guard let runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        self.runLoopSource = nil
    }

    fileprivate func refresh() {
        let updated = Self.readCurrentSource()
        guard updated != currentSource else { return }
        let previous = currentSource
        currentSource = updated
        DispatchQueue.main.async { [weak self] in
            self?.onChange?(previous, updated)
        }
    }

    private static func readCurrentSource() -> PowerSource {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let value = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
              as? String else {
            return .unknown
        }
        switch value {
        case kIOPSACPowerValue, "UPS Power":
            return .external
        case kIOPSBatteryPowerValue:
            return .battery
        default:
            return .unknown
        }
    }
}
