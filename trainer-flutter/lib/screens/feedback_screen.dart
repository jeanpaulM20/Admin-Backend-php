import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class FeedbackItem {
  final int id;
  final String clientName;
  final String date;
  final int rating;
  final String comment;
  bool isRead;

  FeedbackItem({
    required this.id,
    required this.clientName,
    required this.date,
    required this.rating,
    required this.comment,
    required this.isRead,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    // NestJS embeds full client object
    final clientObj = json['client'] as Map<String, dynamic>?;
    String clientName = json['client_name']?.toString() ??
        _buildName(json, 'client_first_name', 'client_last_name') ??
        '';
    if (clientName.isEmpty && clientObj != null) {
      clientName = _buildName(clientObj, 'firstname', 'lastname') ??
          clientObj['name']?.toString() ??
          'Unbekannt';
    }
    if (clientName.isEmpty) clientName = 'Unbekannt';

    return FeedbackItem(
      id: _parseInt(json['id'] ?? json['feedback_id'] ?? 0),
      clientName: clientName,
      date: json['date']?.toString() ??
          json['created_at']?.toString() ??
          json['feedback_date']?.toString() ??
          '',
      rating: _parseInt(json['rating'] ?? json['stars'] ?? 0),
      // NestJS uses "message" property (maps to "text" DB column)
      comment: json['message']?.toString() ??
          json['comment']?.toString() ??
          json['feedback']?.toString() ??
          json['text']?.toString() ??
          '',
      // NestJS camelCase: readTrainer
      isRead: json['readTrainer'] == true ||
          json['readTrainer'] == 1 ||
          json['is_read'] == true ||
          json['is_read'] == 1 ||
          json['read'] == true ||
          json['read'] == 1,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _buildName(
      Map<String, dynamic> json, String firstKey, String lastKey) {
    final first = json[firstKey]?.toString() ?? '';
    final last = json[lastKey]?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isNotEmpty ? name : null;
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoading = false;
  String? _error;
  List<FeedbackItem> _allFeedback = [];
  final Set<int> _markingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFeedback();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeedback() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiService.get(ApiConfig.feedback);
      final List<dynamic> items = response is List
          ? response
          : (response is Map && response.containsKey('data')
              ? response['data'] as List<dynamic>
              : []);
      setState(() {
        _allFeedback =
            items.map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>)).toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Feedback konnte nicht geladen werden.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(FeedbackItem item) async {
    if (item.isRead || _markingIds.contains(item.id)) return;
    setState(() => _markingIds.add(item.id));
    try {
      // NestJS: POST /api/feedback/:id/read
      await _apiService.post('${ApiConfig.feedback}/${item.id}/read');
      setState(() => item.isRead = true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      setState(() => _markingIds.remove(item.id));
    }
  }

  List<FeedbackItem> get _unreadFeedback =>
      _allFeedback.where((f) => !f.isRead).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Feedback',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFeedback,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.muted,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Ungelesen'),
                  if (_unreadFeedback.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadFeedback.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Alle'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFeedbackList(_unreadFeedback, isUnreadTab: true),
                    _buildFeedbackList(_allFeedback, isUnreadTab: false),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.primary, size: 40),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _fetchFeedback,
            child: const Text(
              'Erneut versuchen',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackList(List<FeedbackItem> items, {required bool isUnreadTab}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUnreadTab ? Icons.mark_email_read_outlined : Icons.feedback_outlined,
              color: AppColors.muted,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              isUnreadTab ? 'Kein ungelesenes Feedback' : 'Noch kein Feedback',
              style:
                  const TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _FeedbackCard(
          item: items[index],
          isMarking: _markingIds.contains(items[index].id),
          onTap: () => _markAsRead(items[index]),
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackItem item;
  final bool isMarking;
  final VoidCallback onTap;

  const _FeedbackCard({
    required this.item,
    required this.isMarking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primary.withAlpha(18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? AppColors.primary.withAlpha(70)
                : AppColors.border,
            width: isUnread ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.clientName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight:
                          isUnread ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (isMarking)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _StarRating(rating: item.rating),
            const SizedBox(height: 8),
            if (item.comment.isNotEmpty)
              Text(
                item.comment,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.date.isNotEmpty)
                  Text(
                    item.date,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                if (!isUnread)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 13, color: AppColors.muted),
                      SizedBox(width: 4),
                      Text(
                        'Gelesen',
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Tippen zum Markieren',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: index < rating
              ? const Color(0xFFFFB300)
              : AppColors.muted,
        );
      }),
    );
  }
}
