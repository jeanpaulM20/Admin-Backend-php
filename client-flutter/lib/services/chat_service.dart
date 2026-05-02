import '../models/chat_message.dart';
import 'api_client.dart';

class ChatService {
  Future<List<ChatConversation>> getConversations(String clientId) async {
    final data = await apiClient.get('api/client/chat/$clientId/conversations');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ChatConversation.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<ChatMessage>> getMessages(String clientId, String trainerId) async {
    final data = await apiClient.get('api/client/chat/$clientId/messages/$trainerId');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    }
    return [];
  }

  Future<ChatMessage?> sendMessage(String clientId, String trainerId, String text) async {
    final data = await apiClient.post(
      'api/client/chat/$clientId/messages/$trainerId',
      body: {'text': text},
    );
    if (data is Map<String, dynamic>) {
      return ChatMessage.fromJson(data);
    }
    return null;
  }

  Future<void> markAsRead(String clientId, String trainerId) async {
    await apiClient.post('api/client/chat/$clientId/messages/$trainerId/read', body: {});
  }
}
