import Foundation
import IOKit.pwr_mgt

protocol PowerAssertionServicing: AnyObject {
    var isHeld: Bool { get }
    func acquire(allowDisplaySleep: Bool) throws
    func release()
}

final class PowerAssertionController: PowerAssertionServicing {
    private var assertionID: IOPMAssertionID?

    var isHeld: Bool { assertionID != nil }

    deinit {
        release()
    }

    func acquire(allowDisplaySleep: Bool) throws {
        let assertionType = allowDisplaySleep
            ? kIOPMAssertionTypePreventUserIdleSystemSleep
            : kIOPMAssertionTypePreventUserIdleDisplaySleep
        var newAssertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            assertionType as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Jostle keep-awake session" as CFString,
            &newAssertionID
        )
        guard result == kIOReturnSuccess else {
            throw PowerAssertionError.creationFailed(code: result)
        }

        let oldAssertionID = assertionID
        assertionID = newAssertionID
        if let oldAssertionID {
            IOPMAssertionRelease(oldAssertionID)
        }
    }

    func release() {
        guard let assertionID else { return }
        IOPMAssertionRelease(assertionID)
        self.assertionID = nil
    }
}

private enum PowerAssertionError: LocalizedError {
    case creationFailed(code: IOReturn)

    var errorDescription: String? {
        switch self {
        case let .creationFailed(code):
            "Couldn’t keep this Mac awake (IOKit error \(code))."
        }
    }
}
