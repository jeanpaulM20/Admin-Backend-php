import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/empty_view.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _selectedTrainerId;
  String? _selectedTrainerName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConversations());
  }

  Future<void> _loadConversations() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<ChatProvider>().fetchConversations(auth.clientId!);
      // Auto-select if only one trainer
      final convs = context.read<ChatProvider>().conversations;
      if (convs.length == 1 && _selectedTrainerId == null) {
        _openThread(convs.first.trainerId, convs.first.trainerName);
      }
    }
  }

  void _openThread(String trainerId, String trainerName) {
    setState(() {
      _selectedTrainerId = trainerId;
      _selectedTrainerName = trainerName;
    });
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      context.read<ChatProvider>().fetchMessages(auth.clientId!, trainerId);
      context.read<ChatProvider>().markAsRead(auth.clientId!, trainerId);
    }
  }

  void _backToList() {
    setState(() {
      _selectedTrainerId = null;
      _selectedTrainerName = null;
    });
    _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTrainerId != null) {
      return _ChatThread(
        trainerId: _selectedTrainerId!,
        trainerName: _selectedTrainerName ?? 'Trainer',
        onBack: _backToList,
      );
    }
    return _ConversationList(
      onSelect: _openThread,
      onRefresh: _loadConversations,
    );
  }
}

// ── Conversation List ──────────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final void Function(String trainerId, String trainerName) onSelect;
  final Future<void> Function() onRefresh;

  const _ConversationList({required this.onSelect, required this.onRefresh});

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays < 7) return 'vor ${diff.inDays} T.';
    return DateFormat('dd.MM.yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: onRefresh,
          child: chat.isLoading
              ? const LoadingIndicator(message: 'Lade Nachrichten...')
              : chat.error != null
                  ? ErrorView(message: chat.error!, onRetry: onRefresh)
                  : chat.conversations.isEmpty
                      ? const EmptyView(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Keine Nachrichten',
                          subtitle: 'Starte eine Unterhaltung mit deinem Trainer.',
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: chat.conversations.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final conv = chat.conversations[index];
                            return _ConversationTile(
                              conversation: conv,
                              timeLabel: _formatTime(conv.lastMessageAt),
                              onTap: () => onSelect(conv.trainerId, conv.trainerName),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final String timeLabel;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = conversation.trainerName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.trainerName,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? 'Noch keine Nachrichten',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: conversation.unreadCount > 0
                                ? AppColors.text
                                : AppColors.muted,
                            fontSize: 13,
                            fontWeight: conversation.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (conversation.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}

// ── Chat Thread ─────────────────────────────────────────────────────

class _ChatThread extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final VoidCallback onBack;

  const _ChatThread({
    required this.trainerId,
    required this.trainerName,
    required this.onBack,
  });

  @override
  State<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<_ChatThread> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context
          .read<ChatProvider>()
          .sendMessage(auth.clientId!, widget.trainerId, text);
      _scrollToBottom();
    }
    setState(() => _sending = false);
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context
          .read<ChatProvider>()
          .fetchMessages(auth.clientId!, widget.trainerId);
    }
  }

  String _formatMessageTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('HH:mm').format(dt);
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Heute';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Gestern';
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messagesFor(widget.trainerId);

    // Schedule scroll after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.background,
      // Header
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.text, size: 18),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.trainerName
                            .split(' ')
                            .where((w) => w.isNotEmpty)
                            .map((w) => w[0])
                            .take(2)
                            .join()
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.trainerName,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.muted, size: 20),
                    tooltip: 'Aktualisieren',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Schreibe die erste Nachricht!',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      // Date separator
                      Widget? dateHeader;
                      if (index == 0 ||
                          (msg.createdAt != null &&
                              messages[index - 1].createdAt != null &&
                              msg.createdAt!.day !=
                                  messages[index - 1].createdAt!.day)) {
                        dateHeader = Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12, top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _formatDateHeader(
                                  msg.createdAt ?? DateTime.now()),
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 11),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          if (dateHeader != null) dateHeader,
                          _MessageBubble(
                            message: msg,
                            timeLabel: _formatMessageTime(msg.createdAt),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style:
                          const TextStyle(color: AppColors.text, fontSize: 14),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Nachricht schreiben...',
                        hintStyle: const TextStyle(
                            color: AppColors.muted, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.surface2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: AppColors.white, size: 18),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String timeLabel;

  const _MessageBubble({required this.message, required this.timeLabel});

  @override
  Widget build(BuildContext context) {
    final isClient = message.isFromClient;

    return Align(
      alignment: isClient ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isClient ? AppColors.primary : AppColors.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isClient ? 16 : 4),
            bottomRight: Radius.circular(isClient ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isClient ? AppColors.white : AppColors.text,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: TextStyle(
                color: isClient
                    ? AppColors.white.withOpacity(0.6)
                    : AppColors.muted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
