import CoreBluetooth
import Foundation

struct PointingDeviceBatteryReading: Equatable, Identifiable {
    let id: UUID
    let deviceName: String
    let level: Int
}

protocol PointingDeviceBatteryMonitoring: AnyObject {
    var onChange: (() -> Void)? { get set }
    var readings: [PointingDeviceBatteryReading] { get }
    func setEnabled(_ enabled: Bool)
}

/// Reads the public Bluetooth Battery Service used by supported pointing
/// devices. Devices without the standard service are intentionally ignored.
final class PointingDeviceBatteryMonitor: NSObject, PointingDeviceBatteryMonitoring {
    var onChange: (() -> Void)?

    private(set) var readings: [PointingDeviceBatteryReading] = []
    private let isPointingDeviceName: (String) -> Bool
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var names: [UUID: String] = [:]
    private var enabled = false

    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")

    init(isPointingDeviceName: @escaping (String) -> Bool) {
        self.isPointingDeviceName = isPointingDeviceName
        super.init()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != self.enabled else { return }
        self.enabled = enabled
        if enabled {
            if central == nil {
                central = CBCentralManager(
                    delegate: self,
                    queue: .main,
                    options: [CBCentralManagerOptionShowPowerAlertKey: false]
                )
            } else {
                discoverSupportedDevices()
            }
        } else {
            if central?.state == .poweredOn {
                central?.stopScan()
                for peripheral in peripherals.values where peripheral.state != .disconnected {
                    central?.cancelPeripheralConnection(peripheral)
                }
            }
            peripherals.removeAll()
            names.removeAll()
            replaceReadings([])
        }
    }

    private func discoverSupportedDevices() {
        guard enabled, let central, central.state == .poweredOn else { return }
        let connected = central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
        for peripheral in connected {
            consider(peripheral, advertisedName: nil)
        }
        central.scanForPeripherals(
            withServices: [Self.batteryService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func consider(_ peripheral: CBPeripheral, advertisedName: String?) {
        let name = advertisedName ?? peripheral.name ?? ""
        guard !name.isEmpty, isPointingDeviceName(name) else { return }
        names[peripheral.identifier] = name
        peripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        if peripheral.state == .connected {
            peripheral.discoverServices([Self.batteryService])
        } else if peripheral.state == .disconnected {
            central?.connect(peripheral, options: nil)
        }
    }

    private func update(peripheral: CBPeripheral, level: Int) {
        guard let name = names[peripheral.identifier] else { return }
        var values = readings.filter { $0.id != peripheral.identifier }
        values.append(PointingDeviceBatteryReading(
            id: peripheral.identifier,
            deviceName: name,
            level: min(100, max(0, level))
        ))
        replaceReadings(values.sorted {
            $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending
        })
    }

    private func remove(peripheral: CBPeripheral) {
        peripherals[peripheral.identifier] = nil
        names[peripheral.identifier] = nil
        replaceReadings(readings.filter { $0.id != peripheral.identifier })
    }

    private func replaceReadings(_ values: [PointingDeviceBatteryReading]) {
        guard values != readings else { return }
        readings = values
        onChange?()
    }
}

extension PointingDeviceBatteryMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            discoverSupportedDevices()
        } else {
            replaceReadings([])
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        consider(
            peripheral,
            advertisedName: advertisementData[CBAdvertisementDataLocalNameKey] as? String
        )
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.batteryService])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        remove(peripheral: peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        remove(peripheral: peripheral)
        discoverSupportedDevices()
    }
}

extension PointingDeviceBatteryMonitor: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        for service in peripheral.services ?? [] where service.uuid == Self.batteryService {
            peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        for characteristic in service.characteristics ?? []
            where characteristic.uuid == Self.batteryLevel {
            peripheral.readValue(for: characteristic)
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.batteryLevel,
              let byte = characteristic.value?.first else {
            return
        }
        update(peripheral: peripheral, level: Int(byte))
    }
}
