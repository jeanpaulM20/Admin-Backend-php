import Foundation
import CoreBluetooth

// MARK: - Modelle

/// Ein Herzfrequenz-Sample (1 Hz vom Gurt).
struct HrSample: Codable {
    let t: Date
    let bpm: Int
}

enum HeartRateSourceState: Equatable {
    case idle
    case scanning
    case connecting
    case connected(String)     // Gerätename
    case disconnected          // Verbindung verloren (Reconnect läuft)
    case bluetoothOff
    case unauthorized

    var label: String {
        switch self {
        case .idle:              return "Nicht verbunden"
        case .scanning:          return "Suche Gurt…"
        case .connecting:        return "Verbinde…"
        case .connected(let n):  return n
        case .disconnected:      return "Verbindung verloren — verbinde neu…"
        case .bluetoothOff:      return "Bluetooth ist ausgeschaltet"
        case .unauthorized:      return "Kein Bluetooth-Zugriff (Einstellungen)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Quelle für Herzfrequenz-Daten — echter BLE-Gurt oder Simulation (Demo/Simulator).
@MainActor
protocol HeartRateSource: AnyObject {
    var onSample: ((Int) -> Void)? { get set }
    var onStateChange: ((HeartRateSourceState) -> Void)? { get set }
    func start()
    func stop()
}

// MARK: - Polar H10 / generischer BLE-Herzfrequenzgurt

/// Verbindet sich mit jedem Gurt, der den Standard-BLE-Heart-Rate-Service
/// (0x180D / Characteristic 0x2A37) spricht — Polar H10, Garmin, Wahoo etc.
/// Kein Polar-SDK nötig. Merkt sich den zuletzt verbundenen Gurt und
/// verbindet automatisch neu bei Abbrüchen.
final class BleHeartRateSource: NSObject, HeartRateSource {
    private static let hrService        = CBUUID(string: "180D")
    private static let hrMeasurement    = CBUUID(string: "2A37")
    private static let rememberedKey    = "hr_peripheral_uuid"

    var onSample: ((Int) -> Void)?
    var onStateChange: ((HeartRateSourceState) -> Void)?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var stopped = false

    func start() {
        stopped = false
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            beginScanOrReconnect()
        }
    }

    func stop() {
        stopped = true
        central?.stopScan()
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        peripheral = nil
        emit(.idle)
    }

    private func emit(_ state: HeartRateSourceState) {
        Task { @MainActor in self.onStateChange?(state) }
    }

    private func beginScanOrReconnect() {
        guard let central, central.state == .poweredOn else { return }
        // Bekannten Gurt direkt verbinden (schneller als Scan)
        if let saved = UserDefaults.standard.string(forKey: Self.rememberedKey),
           let uuid = UUID(uuidString: saved),
           let known = central.retrievePeripherals(withIdentifiers: [uuid]).first {
            connect(known)
            return
        }
        emit(.scanning)
        central.scanForPeripherals(withServices: [Self.hrService])
    }

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        emit(.connecting)
        central?.connect(p)
    }
}

extension BleHeartRateSource: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:    beginScanOrReconnect()
        case .poweredOff:   emit(.bluetoothOff)
        case .unauthorized: emit(.unauthorized)
        default:            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan()
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.rememberedKey)
        peripheral.discoverServices([Self.hrService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        guard !stopped else { return }
        emit(.disconnected)
        central.connect(peripheral)   // erneut versuchen
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        guard !stopped else { return }
        // Gurtkontakt verloren / Reichweite: iOS verbindet automatisch neu,
        // sobald der Gurt wieder sichtbar ist.
        emit(.disconnected)
        central.connect(peripheral)
    }
}

extension BleHeartRateSource: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.hrService }) else { return }
        peripheral.discoverCharacteristics([Self.hrMeasurement], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let char = service.characteristics?.first(where: { $0.uuid == Self.hrMeasurement }) else { return }
        peripheral.setNotifyValue(true, for: char)
        emit(.connected(peripheral.name ?? "Herzfrequenz-Gurt"))
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.hrMeasurement,
              let data = characteristic.value, data.count >= 2 else { return }
        // BLE Heart Rate Measurement: Byte 0 = Flags, Bit 0 = HF-Format (0: UInt8, 1: UInt16 LE)
        let bpm: Int
        if data[0] & 0x01 == 0 {
            bpm = Int(data[1])
        } else {
            guard data.count >= 3 else { return }
            bpm = Int(data[1]) | (Int(data[2]) << 8)
        }
        guard bpm > 20, bpm < 250 else { return }
        Task { @MainActor in self.onSample?(bpm) }
    }
}

// MARK: - Simulation (Demo-Modus & Simulator — BLE gibt es dort nicht)

final class SimulatedHeartRateSource: HeartRateSource {
    var onSample: ((Int) -> Void)?
    var onStateChange: ((HeartRateSourceState) -> Void)?

    private var timer: Timer?
    private var tick = 0

    func start() {
        onStateChange?(.connected("Simulierter Gurt"))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.tick += 1
                // Aufwärmen → Belastung mit Intervallen → leichtes Rauschen
                let base = 95.0 + 55.0 * min(1.0, Double(self.tick) / 300.0)
                let wave = 12.0 * sin(Double(self.tick) / 25.0)
                let noise = Double(Int.random(in: -2...2))
                self.onSample?(Int(base + wave + noise))
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onStateChange?(.idle)
    }
}
