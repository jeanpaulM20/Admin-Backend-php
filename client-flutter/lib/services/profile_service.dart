import '../models/profile_data.dart';
import 'api_client.dart';

class ProfileService {
  Future<ProfileData> getProfile(String clientId) async {
    final data = await apiClient.get('api/client/profile/$clientId');
    if (data == null || data is! Map<String, dynamic>) {
      throw ApiException(500, 'Ungueltige Profildaten');
    }
    return ProfileData.fromJson(data);
  }
}
