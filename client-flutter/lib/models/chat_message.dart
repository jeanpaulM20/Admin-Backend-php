class ChatMessage {
  final String id;
  final String text;
  final String senderType; // 'client' or 'trainer'
  final String? author;
  final bool isCircle;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.senderType,
    this.author,
    this.isCircle = false,
    this.createdAt,
  });

  bool get isFromClient => senderType == 'client';
  bool get isFromTrainer => senderType == 'trainer';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final isCircle = _parseBool(json['is_circle']);
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ??
          json['message']?.toString() ??
          json['comment']?.toString() ??
          '',
      senderType: json['sender_type']?.toString() ?? 'client',
      author: json['author']?.toString(),
      isCircle: isCircle,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v == 'true';
    return false;
  }
}

class ChatConversation {
  final String trainerId;
  final String trainerName;
  final String? trainerPicture;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChatConversation({
    required this.trainerId,
    required this.trainerName,
    this.trainerPicture,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      trainerId: json['trainer_id']?.toString() ?? '',
      trainerName: json['trainer_name']?.toString() ?? 'Trainer',
      trainerPicture: json['trainer_picture']?.toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString())
          : null,
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
    );
  }
}
