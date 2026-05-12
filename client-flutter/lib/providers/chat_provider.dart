import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/mock_data.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _service = ChatService();

  bool _isLoading = false;
  String? _error;
  List<ChatConversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messagesByTrainer = {};
  bool _isMock = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ChatConversation> get conversations => _conversations;

  int get totalUnreadCount =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  List<ChatMessage> messagesFor(String trainerId) =>
      _messagesByTrainer[trainerId] ?? [];

  Future<void> fetchConversations(String clientId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _conversations = await _service.getConversations(clientId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMessages(String clientId, String trainerId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messagesByTrainer[trainerId] =
          await _service.getMessages(clientId, trainerId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String clientId, String trainerId, String text) async {
    if (_isMock) {
      // Fake send in demo mode
      final fake = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        senderType: 'client',
        createdAt: DateTime.now(),
      );
      _messagesByTrainer.putIfAbsent(trainerId, () => []);
      _messagesByTrainer[trainerId]!.add(fake);
      notifyListeners();
      return true;
    }

    try {
      final msg = await _service.sendMessage(clientId, trainerId, text);
      if (msg != null) {
        _messagesByTrainer.putIfAbsent(trainerId, () => []);
        _messagesByTrainer[trainerId]!.add(msg);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> markAsRead(String clientId, String trainerId) async {
    if (_isMock) return;
    try {
      await _service.markAsRead(clientId, trainerId);
      // Update local unread count
      final idx = _conversations.indexWhere((c) => c.trainerId == trainerId);
      if (idx >= 0 && _conversations[idx].unreadCount > 0) {
        _conversations[idx] = ChatConversation(
          trainerId: _conversations[idx].trainerId,
          trainerName: _conversations[idx].trainerName,
          trainerPicture: _conversations[idx].trainerPicture,
          lastMessage: _conversations[idx].lastMessage,
          lastMessageAt: _conversations[idx].lastMessageAt,
          unreadCount: 0,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void loadMockData() {
    _isMock = true;
    _conversations = MockData.chatConversations;
    _messagesByTrainer['7'] = MockData.chatMessages;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
