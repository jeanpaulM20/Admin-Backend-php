import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/trainer.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _trainerKey = 'trainer_data';

  final ApiService _apiService = ApiService();

  String _computeToken(String passcode) {
    final input = ApiConfig.salt + passcode;
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  Future<Trainer> login(String passcode) async {
    final token = _computeToken(passcode);

    // NestJS auth: set token header, then GET /api/trainer/me to verify + fetch profile
    _apiService.setAuthToken(token);

    final response = await _apiService.get(ApiConfig.trainerMe);

    if (response == null) {
      throw ApiException('No response from server');
    }

    Map<String, dynamic> trainerData;
    if (response is Map<String, dynamic>) {
      trainerData = response;
    } else {
      throw ApiException('Invalid response format');
    }

    final trainer = Trainer.fromJson(trainerData);

    // Store token and trainer data
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_trainerKey, jsonEncode(trainerData));

    return trainer;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_trainerKey);
    _apiService.clearAuthToken();
  }

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Trainer?> getStoredTrainer() async {
    final prefs = await SharedPreferences.getInstance();
    final trainerJson = prefs.getString(_trainerKey);
    if (trainerJson == null) return null;
    try {
      final data = jsonDecode(trainerJson) as Map<String, dynamic>;
      return Trainer.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<bool> restoreSession() async {
    final token = await getStoredToken();
    if (token == null) return false;
    _apiService.setAuthToken(token);
    return true;
  }
}
