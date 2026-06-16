import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/glucose_reading.dart';
import '../models/libre_auth.dart';

/// Lokale Persistenz für Libre-Daten via SharedPreferences.
/// Alle Messdaten bleiben offline verfügbar; kein Backend nötig.
class LibreStorageService {
  static const _keyToken = 'libre_auth_token';
  static const _keyTokenExpires = 'libre_auth_expires';
  static const _keyEmail = 'libre_email';
  static const _keyRegion = 'libre_region';
  static const _keyReadings = 'libre_glucose_readings';
  static const _keyPatientId = 'libre_patient_id';
  static const _keyLastSync = 'libre_last_sync';

  // MARK: - Auth

  Future<void> saveAuth(String email, LibreAuthTicket ticket,
      String patientId, LibreRegion region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyToken, ticket.token);
    await prefs.setInt(
        _keyTokenExpires, ticket.expires.millisecondsSinceEpoch);
    await prefs.setString(_keyPatientId, patientId);
    await prefs.setString(_keyRegion, region.name);
  }

  Future<LibreAuthTicket?> loadAuthTicket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    final expiresMs = prefs.getInt(_keyTokenExpires);
    if (token == null || expiresMs == null) return null;
    return LibreAuthTicket(
      token: token,
      expires: DateTime.fromMillisecondsSinceEpoch(expiresMs),
    );
  }

  Future<String?> loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  Future<String?> loadPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPatientId);
  }

  Future<LibreRegion> loadRegion() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_keyRegion) ?? 'eu';
    return LibreRegion.values.firstWhere((r) => r.name == name,
        orElse: () => LibreRegion.eu);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyTokenExpires);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPatientId);
    await prefs.remove(_keyRegion);
  }

  // MARK: - Glukose-Readings

  Future<void> saveReadings(List<GlucoseReading> readings) async {
    final prefs = await SharedPreferences.getInstance();
    final json = readings.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_keyReadings, json);
    await prefs.setString(_keyLastSync, DateTime.now().toIso8601String());
  }

  Future<List<GlucoseReading>> loadReadings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_keyReadings) ?? [];
    return jsonList.map((s) {
      try {
        return GlucoseReading.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<GlucoseReading>().toList();
  }

  Future<DateTime?> loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastSync);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  Future<void> clearReadings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyReadings);
    await prefs.remove(_keyLastSync);
  }
}
