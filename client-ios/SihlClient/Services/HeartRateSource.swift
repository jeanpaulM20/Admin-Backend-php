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
    /// Kein Sensor gespeichert — ohne Puls aufzeichnen (nie fremd verbinden)
    case noSavedStrap

    var label: String {
        switch self {
        case .idle:              return "Nicht verbunden"
        case .scanning:          return "Suche Gurt…"
        case .connecting:        return "Verbinde…"
        case .connected(let n):  return n
        case .disconnected:      return "Verbindung verloren — verbinde neu…"
        case .bluetoothOff:      return "Bluetooth ist ausgeschaltet"
        case .unauthorized:      return "Kein Bluetooth-Zugriff (Einstellungen)"
        case .noSavedStrap:      return "Kein Sensor gespeichert — in Profil → Sensoren hinzufügen"
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
    var sensorId: String { StrapIdentity.sensorId(name: name, serial: nil, uuid: id) }
    var model: String { StrapIdentity.model(name: name) }
    var signalLabel: String { ["schwach", "mittel", "stark"][signalLevel - 1] }
}

/// Gespeicherter (vom Nutzer hinzugefügter) Herzfrequenz-Sensor.
struct SavedStrap: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    /// Zuletzt verbunden — der jüngste wird beim Training zuerst versucht
    var lastUsed: Date?
    /// Seriennummer aus dem BLE-Dienst „Geräteinformation" (0x180A/0x2A25),
    /// beim ersten Verbinden gelesen
    var serial: String? = nil

    /// Sensor-ID wie auf dem Gurt (Polar: Geräte-ID im Namen), sonst Serien-
    /// nummer, zuletzt die Kurzform der iOS-Kennung
    var sensorId: String { StrapIdentity.sensorId(name: name, serial: serial, uuid: id) }
    /// Name ohne angehängte Geräte-ID („Polar H10")
    var model: String { StrapIdentity.model(name: name) }
}

/// Zerlegt Gurt-Namen wie „Polar H10 9A1B2C3D" in Modell und Geräte-ID.
enum StrapIdentity {
    /// 8-stellige Hex-ID am Namensende (Polar druckt sie auf den Gurt)
    static func deviceId(in name: String) -> String? {
        guard let last = name.split(separator: " ").last, last.count == 8,
              last.allSatisfy(\.isHexDigit) else { return nil }
        return last.uppercased()
    }

    static func model(name: String) -> String {
        guard deviceId(in: name) != nil else { return name }
        let parts = name.split(separator: " ").dropLast()
        return parts.isEmpty ? name : parts.joined(separator: " ")
    }

    static func sensorId(name: String, serial: String?, uuid: UUID) -> String {
        if let id = deviceId(in: name) { return id }
        if let serial = serial?.trimmingCharacters(in: .whitespacesAndNewlines), !serial.isEmpty {
            return serial
        }
        return String(uuid.uuidString.prefix(8))
    }
}

/// Liste der gespeicherten Sensoren (geräteweit, nicht je Konto: der Gurt
/// gehört zum Gerät der Person). Nur mit diesen verbindet sich die App
/// automatisch — beim Training draussen sind oft fremde Gurte in Reichweite.
enum SavedStraps {
    private static let key = "hr_saved_straps"
    /// Vorgänger: ein einzelner gemerkter Gurt
    private static let legacyIdKey = "hr_peripheral_uuid"
    private static let legacyNameKey = "hr_peripheral_name"

    /// Jüngst verbundener zuerst.
    static var all: [SavedStrap] {
        let ud = UserDefaults.standard
        if let data = ud.data(forKey: key),
           let list = try? JSONDecoder().decode([SavedStrap].self, from: data) {
            return list.sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }
        // Einmalige Übernahme des bisher gemerkten Gurts
        if let raw = ud.string(forKey: legacyIdKey), let id = UUID(uuidString: raw) {
            let list = [SavedStrap(id: id, name: ud.string(forKey: legacyNameKey) ?? "Herzfrequenz-Gurt", lastUsed: nil)]
            save(list)
            ud.removeObject(forKey: legacyIdKey)
            ud.removeObject(forKey: legacyNameKey)
            return list
        }
        return []
    }

    static var ids: Set<UUID> { Set(all.map(\.id)) }
    static func contains(_ id: UUID) -> Bool { all.contains { $0.id == id } }

    static func add(id: UUID, name: String) {
        var list = all.filter { $0.id != id }
        list.insert(SavedStrap(id: id, name: name, lastUsed: Date()), at: 0)
        save(list)
    }

    static func remove(_ id: UUID) {
        save(all.filter { $0.id != id })
    }

    /// Seriennummer nachtragen (gelesen nach dem Verbinden).
    static func setSerial(_ id: UUID, serial: String) {
        var list = all
        guard let i = list.firstIndex(where: { $0.id == id }), list[i].serial != serial else { return }
        list[i].serial = serial
        save(list)
    }

    /// Verbindung hergestellt: als zuletzt genutzt markieren, Namen nachführen.
    static func touch(_ id: UUID, name: String?) {
        var list = all
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        list[i].lastUsed = Date()
        if let name, !name.isEmpty { list[i].name = name }
        save(list)
    }

    private static func save(_ list: [SavedStrap]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
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

/// Verbindet sich mit Gurten, die den Standard-BLE-Heart-Rate-Service
/// (0x180D / Characteristic 0x2A37) sprechen — Polar H10, Garmin, Wahoo etc.
/// Kein Polar-SDK nötig.
///
/// Sensoren werden nur nach ausdrücklichem Hinzufügen in Profil → Sensoren
/// gespeichert (`startDiscovery()` + `add(_:)`). Beim Training (`start()`)
/// verbindet sich die App AUSSCHLIESSLICH mit gespeicherten Sensoren, der
/// zuletzt genutzte zuerst; ohne gespeicherten Sensor wird ohne Puls
/// aufgezeichnet — nie mit einem fremden Gurt in Reichweite.
final class BleHeartRateSource: NSObject, HeartRateSource {
    private static let hrService        = CBUUID(string: "180D")
    private static let hrMeasurement    = CBUUID(string: "2A37")
    /// Geräteinformation → Seriennummer (Sensor-ID bei Gurten ohne ID im Namen)
    private static let deviceInfo       = CBUUID(string: "180A")
    private static let serialNumber     = CBUUID(string: "2A25")
    /// Name des aktuell verbundenen Sensors (für die Anzeige).
    private(set) var connectedId: UUID?

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
    /// Wächter für den Direktverbindungsversuch zum gemerkten Gurt:
    /// CBCentralManager.connect hat KEIN Timeout — liegt der Gurt in der
    /// Schublade, bliebe der Zustand sonst ewig auf „Verbinde…".
    private var connectTimeout: DispatchWorkItem?
    private static let connectTimeoutSeconds: Double = 10

    /// Aufzeichnung: nur gespeicherte Sensoren.
    func start() {
        mode = .recording
        guard !SavedStraps.all.isEmpty else {
            // Nichts zu verbinden — Bluetooth gar nicht erst suchen lassen
            stopped = true
            emit(.noSavedStrap)
            return
        }
        startCentral()
    }

    /// Sensor-Einstellungen: gespeicherte Sensoren verbinden (Puls zeigen)
    /// und alle Gurte in Reichweite auflisten, um neue hinzuzufügen.
    func startDiscovery() {
        mode = .discovery
        startCentral()
    }

    /// Gefundenen Gurt als Sensor hinzufügen und verbinden.
    func add(_ id: UUID) {
        guard let entry = found[id] else { return }
        SavedStraps.add(id: id, name: entry.strap.name)
        if let p = peripheral, p.identifier != id {
            central?.cancelPeripheralConnection(p)
            peripheral = nil
        }
        if peripheral == nil { connect(entry.peripheral) }
        publishStraps(force: true)
    }

    /// Gespeicherten Sensor entfernen; ist er verbunden, trennen.
    func remove(_ id: UUID) {
        SavedStraps.remove(id)
        if let p = peripheral, p.identifier == id {
            connectTimeout?.cancel(); connectTimeout = nil
            central?.cancelPeripheralConnection(p)
            peripheral = nil
            connectedId = nil
            emit(mode == .discovery ? .scanning : .idle)
        }
        publishStraps(force: true)
    }

    func stop() {
        stopped = true
        connectTimeout?.cancel(); connectTimeout = nil
        central?.stopScan()
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        peripheral = nil
        connectedId = nil
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
        // Zuletzt genutzten gespeicherten Sensor direkt verbinden (schneller
        // als Scan); die übrigen gespeicherten findet die Suche
        if let latest = SavedStraps.all.first,
           let known = central.retrievePeripherals(withIdentifiers: [latest.id]).first {
            connect(known)
            // In der Suche trotzdem weiter auflisten (Sensor hinzufügen)
            if mode == .discovery { scan() }
            return
        }
        scan()
    }

    /// Suche starten. In der Aufzeichnung wird jeder Fund verworfen, der
    /// kein gespeicherter Sensor ist.
    private func scan() {
        guard let central else { return }
        found = [:]
        if peripheral == nil { emit(.scanning) }
        // Doppelte Meldungen nur in der Suche (laufende Signalstärke)
        central.scanForPeripherals(withServices: [Self.hrService],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: mode == .discovery])
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

        let saved = SavedStraps.contains(id)
        switch mode {
        case .discovery:
            publishStraps(force: isNew)
            // Gespeicherter Sensor taucht auf (nicht direkt abrufbar gewesen)
            if saved, self.peripheral == nil { connect(peripheral) }
        case .recording:
            // Nur gespeicherte Sensoren — fremde Gurte ignorieren
            guard saved, self.peripheral == nil else { return }
            central.stopScan()
            connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectTimeout?.cancel(); connectTimeout = nil
        peripheral.discoverServices([Self.hrService, Self.deviceInfo])
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
        if let info = peripheral.services?.first(where: { $0.uuid == Self.deviceInfo }) {
            peripheral.discoverCharacteristics([Self.serialNumber], for: info)
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.hrService }) else { return }
        peripheral.discoverCharacteristics([Self.hrMeasurement], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if service.uuid == Self.deviceInfo {
            if let serial = service.characteristics?.first(where: { $0.uuid == Self.serialNumber }) {
                peripheral.readValue(for: serial)
            }
            return
        }
        guard let char = service.characteristics?.first(where: { $0.uuid == Self.hrMeasurement }) else { return }
        peripheral.setNotifyValue(true, for: char)
        connectedId = peripheral.identifier
        SavedStraps.touch(peripheral.identifier, name: peripheral.name)
        emit(.connected(peripheral.name ?? "Herzfrequenz-Gurt"))
        publishStraps(force: true)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == Self.serialNumber {
            if let data = characteristic.value,
               let serial = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)),
               !serial.isEmpty {
                SavedStraps.setSerial(peripheral.identifier, serial: serial)
                publishStraps(force: true)
            }
            return
        }
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
