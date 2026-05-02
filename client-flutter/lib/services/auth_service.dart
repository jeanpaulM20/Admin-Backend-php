import '../models/auth_token.dart';
import 'api_client.dart';

class AuthService {
  Future<AuthToken> login(String email, String password) async {
    final data = await apiClient.post('api/token', body: {
      'email': email,
      'password': password,
    });
    if (data == null || data is! Map<String, dynamic>) {
      throw ApiException(401, 'Login fehlgeschlagen');
    }
    return AuthToken.fromJson(data);
  }
}
