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
    /// Mehrere Gurte in Reichweite, keiner gewählt — ohne Gurt aufzeichnen
    case chooseStrap

    var label: String {
        switch self {
        case .idle:              return "Nicht verbunden"
        case .scanning:          return "Suche Gurt…"
        case .connecting:        return "Verbinde…"
        case .connected(let n):  return n
        case .disconnected:      return "Verbindung verloren — verbinde neu…"
        case .bluetoothOff:      return "Bluetooth ist ausgeschaltet"
        case .unauthorized:      return "Kein Bluetooth-Zugriff (Einstellungen)"
        case .chooseStrap:       return "Mehrere Gurte gefunden — Gurt in Profil → Sensoren wählen"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// In der Sensor-Suche gefundener Gurt.
struct DiscoveredStrap: Identifiable, Equatable {
    let id: UUID
    let name: String
    /// Signalstärke in dBm (näher an 0 = stärker)
    var rssi: Int

    /// Grobe Stufe 1…3 für die Anzeige.
    var signalLevel: Int { rssi >= -60 ? 3 : rssi >= -75 ? 2 : 1 }
    var signalLabel: String { ["schwach", "mittel", "stark"][signalLevel - 1] }
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

/// Verbindet sich mit Gurten, die den Standard-BLE-Heart-Rate-Service
/// (0x180D / Characteristic 0x2A37) sprechen — Polar H10, Garmin, Wahoo etc.
/// Kein Polar-SDK nötig.
///
/// Gemerkt wird ein Gurt nur nach ausdrücklicher Wahl in Profil → Sensoren
/// (`startDiscovery()` + `select(_:)`) — im Studio liegen oft fremde Gurte in
/// Reichweite. Beim Training (`start()`) wird nur der gemerkte Gurt
/// verbunden; ohne gemerkten Gurt nur dann automatisch, wenn genau einer in
/// Reichweite ist (ohne ihn zu merken), sonst wird ohne Gurt aufgezeichnet.
final class BleHeartRateSource: NSObject, HeartRateSource {
    private static let hrService        = CBUUID(string: "180D")
    private static let hrMeasurement    = CBUUID(string: "2A37")
    private nonisolated static let rememberedKey    = "hr_peripheral_uuid"
    private nonisolated static let rememberedNameKey = "hr_peripheral_name"

    /// Gemerkter (gewählter) Gurt.
    nonisolated static var rememberedId: UUID? {
        UserDefaults.standard.string(forKey: rememberedKey).flatMap(UUID.init(uuidString:))
    }
    nonisolated static var rememberedName: String? {
        UserDefaults.standard.string(forKey: rememberedNameKey)
    }

    var onSample: ((Int) -> Void)?
    var onStateChange: ((HeartRateSourceState) -> Void)?
    /// Suchliste für die Sensor-Einstellungen (nach Signalstärke sortiert).
    var onStrapsChange: (([DiscoveredStrap]) -> Void)?

    private enum Mode { case recording, discovery }
    private var mode: Mode = .recording

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var stopped = false
    /// Gefundene Gurte (Kennung → Gerät + Anzeige)
    private var found: [UUID: (peripheral: CBPeripheral, strap: DiscoveredStrap)] = [:]
    private var lastPublish = Date.distantPast
    /// Entscheid ohne gemerkten Gurt: erst nach kurzem Suchfenster, damit ein
    /// zweiter Gurt in Reichweite sicher mitgezählt wird
    private var autoPick: DispatchWorkItem?
    private static let autoPickWindow: Double = 4
    /// Wächter für den Direktverbindungsversuch zum gemerkten Gurt:
    /// CBCentralManager.connect hat KEIN Timeout — liegt der Gurt in der
    /// Schublade, bliebe der Zustand sonst ewig auf „Verbinde…".
    private var connectTimeout: DispatchWorkItem?
    private static let connectTimeoutSeconds: Double = 10

    /// Aufzeichnung: nur gemerkter Gurt (bzw. genau einer in Reichweite).
    func start() {
        mode = .recording
        startCentral()
    }

    /// Sensor-Einstellungen: alle Gurte in Reichweite auflisten; der gemerkte
    /// wird verbunden, um den Puls zu zeigen.
    func startDiscovery() {
        mode = .discovery
        startCentral()
    }

    /// Gurt aus der Suchliste wählen: merken und verbinden.
    func select(_ id: UUID) {
        guard let entry = found[id] else { return }
        UserDefaults.standard.set(id.uuidString, forKey: Self.rememberedKey)
        UserDefaults.standard.set(entry.strap.name, forKey: Self.rememberedNameKey)
        if let p = peripheral, p.identifier != id {
            central?.cancelPeripheralConnection(p)
            peripheral = nil
        }
        if peripheral == nil { connect(entry.peripheral) }
        publishStraps(force: true)
    }

    /// Gemerkten Gurt vergessen und trennen.
    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.rememberedKey)
        UserDefaults.standard.removeObject(forKey: Self.rememberedNameKey)
        connectTimeout?.cancel(); connectTimeout = nil
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        peripheral = nil
        emit(mode == .discovery ? .scanning : .idle)
        publishStraps(force: true)
    }

    func stop() {
        stopped = true
        connectTimeout?.cancel(); connectTimeout = nil
        autoPick?.cancel(); autoPick = nil
        central?.stopScan()
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        peripheral = nil
        found = [:]
        emit(.idle)
    }

    private func startCentral() {
        stopped = false
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            beginScanOrReconnect()
        }
    }

    private func emit(_ state: HeartRateSourceState) {
        Task { @MainActor in self.onStateChange?(state) }
    }

    private func beginScanOrReconnect() {
        guard let central, central.state == .poweredOn, !stopped else { return }
        // Bekannten Gurt direkt verbinden (schneller als Scan)
        if let uuid = Self.rememberedId,
           let known = central.retrievePeripherals(withIdentifiers: [uuid]).first {
            connect(known)
            // In der Suche trotzdem weiter auflisten (Gurt wechseln)
            if mode == .discovery { scan() }
            return
        }
        scan()
    }

    /// Suche starten. Aufzeichnung ohne gemerkten Gurt: nach dem Suchfenster
    /// entscheiden (genau einer → verbinden, mehrere → ohne Gurt + Hinweis).
    private func scan() {
        guard let central else { return }
        found = [:]
        if peripheral == nil { emit(.scanning) }
        // Doppelte Meldungen nur in der Suche (laufende Signalstärke)
        central.scanForPeripherals(withServices: [Self.hrService],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: mode == .discovery])
        if mode == .recording, Self.rememberedId == nil { armAutoPick(after: Self.autoPickWindow) }
    }

    private func armAutoPick(after seconds: Double) {
        autoPick?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.evaluateAutoPick() }
        autoPick = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func evaluateAutoPick() {
        autoPick = nil
        guard !stopped, mode == .recording, Self.rememberedId == nil, peripheral == nil else { return }
        switch found.count {
        case 0:
            break   // weiter suchen; der erste Fund startet ein neues Fenster
        case 1:
            central?.stopScan()
            if let only = found.values.first { connect(only.peripheral) }
        default:
            // Nicht raten, welcher Gurt der eigene ist
            central?.stopScan()
            emit(.chooseStrap)
        }
    }

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        emit(.connecting)
        central?.connect(p)
        armConnectTimeout(for: p)
    }

    /// Kommt der Gurt nicht binnen 10 s, Versuch abbrechen und weiter suchen
    /// (in der Aufzeichnung nur nach demselben, gemerkten Gurt).
    private func armConnectTimeout(for p: CBPeripheral) {
        connectTimeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.stopped, self.peripheral === p, p.state != .connected else { return }
            self.central?.cancelPeripheralConnection(p)
            self.peripheral = nil
            self.scan()
        }
        connectTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectTimeoutSeconds, execute: work)
    }

    private func publishStraps(force: Bool = false) {
        guard mode == .discovery, let onStrapsChange else { return }
        // Signalstärke höchstens 1× pro Sekunde nachführen
        guard force || Date().timeIntervalSince(lastPublish) >= 1 else { return }
        lastPublish = Date()
        let list = found.values.map(\.strap).sorted { $0.rssi > $1.rssi }
        Task { @MainActor in onStrapsChange(list) }
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
        guard !stopped else { return }
        let rssi = RSSI.intValue
        guard rssi < 0 else { return }   // 127 = nicht verfügbar
        let id = peripheral.identifier
        let isNew = found[id] == nil
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Herzfrequenz-Gurt"
        found[id] = (peripheral, DiscoveredStrap(id: id, name: name, rssi: rssi))

        switch mode {
        case .discovery:
            publishStraps(force: isNew)
            // Gemerkter Gurt taucht auf (nicht direkt abrufbar gewesen)
            if id == Self.rememberedId, self.peripheral == nil { connect(peripheral) }
        case .recording:
            if let remembered = Self.rememberedId {
                // Nur der gewählte Gurt — fremde Gurte ignorieren
                guard id == remembered, self.peripheral == nil else { return }
                central.stopScan()
                connect(peripheral)
            } else if isNew, autoPick == nil, self.peripheral == nil {
                // Fund nach leerem Suchfenster: kurz weitersuchen, dann entscheiden
                armAutoPick(after: 3)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectTimeout?.cancel(); connectTimeout = nil
        peripheral.discoverServices([Self.hrService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        guard !stopped else { return }
        // Kurz warten statt ungedrosselt sofort erneut: direkt nach dem Verlassen
        // der Sensoren-Seite baut iOS die alte Verbindung noch ab
        emit(.connecting)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !self.stopped, self.peripheral === peripheral else { return }
            central.connect(peripheral)
            self.armConnectTimeout(for: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        // Bewusst getrennt (Gurt gewechselt/vergessen): nicht neu verbinden
        guard !stopped, self.peripheral === peripheral else { return }
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
