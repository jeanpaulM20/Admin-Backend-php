import '../models/glucose_reading.dart';
import '../models/libre_auth.dart';
import '../services/libre_api_client.dart';
import '../services/libre_storage_service.dart';

/// Cache-Strategie: Daten werden frisch von der API geladen, wenn
/// - ein gültiges Token vorhanden ist UND
/// - der letzte Sync älter als [_syncInterval] ist.
/// Sonst werden die lokalen Daten zurückgegeben (Offline-First).
class LibreRepository {
  static const _syncInterval = Duration(minutes: 5);

  final LibreStorageService _storage;
  LibreApiClient? _client;

  LibreRepository({LibreStorageService? storage})
      : _storage = storage ?? LibreStorageService();

  // MARK: - Login

  /// Login mit E-Mail + Passwort. Speichert Token + PatientId lokal.
  Future<void> login(String email, String password,
      {LibreRegion region = LibreRegion.eu}) async {
    _client = LibreApiClient(region: region);
    final ticket = await _client!.login(email, password);

    // Erste Connection als Standard-Patient verwenden
    final connections = await _client!.getConnections(ticket.token);
    if (connections.isEmpty) {
      throw LibreApiException(0, 'Keine Libre-Verbindungen gefunden');
    }
    final patientId = connections.first.patientId;

    await _storage.saveAuth(email, ticket, patientId, region);
  }

  Future<void> logout() async {
    await _storage.clearAuth();
    await _storage.clearReadings();
    _client = null;
  }

  Future<bool> get isLoggedIn async {
    final ticket = await _storage.loadAuthTicket();
    return ticket != null && !ticket.isExpired;
  }

  // MARK: - Glukose-Daten (Cache-First)

  /// Gibt Messwerte zurück — frisch von der API oder aus dem lokalen Cache.
  /// [forceRefresh] überspringt die Sync-Interval-Prüfung.
  Future<LibreResult> getReadings({bool forceRefresh = false}) async {
    final cached = await _storage.loadReadings();
    final lastSync = await _storage.loadLastSync();
    final needsSync = forceRefresh ||
        lastSync == null ||
        DateTime.now().difference(lastSync) > _syncInterval;

    if (!needsSync) {
      return LibreResult(readings: cached, fromCache: true, lastSync: lastSync);
    }

    // Versuche frische Daten — falle bei Fehler auf Cache zurück
    try {
      final freshReadings = await _fetchFresh();
      await _storage.saveReadings(freshReadings);
      return LibreResult(
        readings: freshReadings,
        fromCache: false,
        lastSync: DateTime.now(),
      );
    } on LibreApiException catch (e) {
      if (e.code == 401) {
        // Token abgelaufen — User muss sich neu einloggen
        await _storage.clearAuth();
        rethrow;
      }
      // Andere Fehler (Netzwerk): Cache zurückgeben
      return LibreResult(
        readings: cached,
        fromCache: true,
        lastSync: lastSync,
        error: e.message,
      );
    } catch (_) {
      return LibreResult(
        readings: cached,
        fromCache: true,
        lastSync: lastSync,
        error: 'Keine Verbindung möglich — zeige gespeicherte Daten',
      );
    }
  }

  Future<List<GlucoseReading>> _fetchFresh() async {
    final ticket = await _storage.loadAuthTicket();
    final patientId = await _storage.loadPatientId();
    final region = await _storage.loadRegion();
    if (ticket == null || ticket.isExpired || patientId == null) {
      throw LibreApiException(401, 'Bitte erneut einloggen');
    }
    _client ??= LibreApiClient(region: region);
    return _client!.getGraphData(ticket.token, patientId);
  }
}

/// Ergebnis-Wrapper mit Metadaten (Cache-Status, Sync-Zeit, Fehler).
class LibreResult {
  final List<GlucoseReading> readings;
  final bool fromCache;
  final DateTime? lastSync;
  final String? error;

  const LibreResult({
    required this.readings,
    required this.fromCache,
    this.lastSync,
    this.error,
  });

  GlucoseReading? get latest =>
      readings.isEmpty ? null : readings.last;
}
