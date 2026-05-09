import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/performance_provider.dart';
import '../models/performance_section.dart';
import '../models/training_review.dart';
import '../services/mock_data.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/empty_view.dart';
import 'performance_detail_screen.dart';
import 'training_review_screen.dart';
import 'training_compare_screen.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<PerformanceProvider>().fetch(auth.clientId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perf = context.watch<PerformanceProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: perf.isLoading
              ? const LoadingIndicator(message: 'Lade Leistungsdaten...')
              : perf.error != null
                  ? ErrorView(
                      message: perf.error!,
                      onRetry: _loadData,
                    )
                  : (perf.data.isEmpty && perf.reviews.isEmpty)
                      ? const EmptyView(
                          icon: Icons.show_chart_rounded,
                          title: 'Keine Leistungsdaten',
                          subtitle:
                              'Noch keine Leistungstests erfasst.',
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          children: [
                            ...perf.data.map(
                              (section) =>
                                  PerformanceSectionTile(section: section),
                            ),
                            if (perf.reviews.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              TrainingReviewSectionTile(reviews: perf.reviews),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
        ),
      ),
    );
  }
}

class PerformanceSectionTile extends StatelessWidget {
  final PerformanceSection section;

  const PerformanceSectionTile({super.key, required this.section});

  void _openDetail(BuildContext context, PerformanceItem item) {
    final history = item.history.isNotEmpty
        ? item.history
        : (MockData.performanceHistory[item.name] ?? []);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerformanceDetailScreen(
          item: item,
          history: history,
          sectionTitle: section.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: AppColors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            section.title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${section.items.length} Messwert${section.items.length != 1 ? 'e' : ''}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          iconColor: AppColors.muted,
          collapsedIconColor: AppColors.muted,
          initiallyExpanded: false,
          children: [
            const Divider(color: AppColors.border, height: 1),
            ...section.items.asMap().entries.map(
              (e) => PerformanceItemRow(
                item: e.value,
                isLast: e.key == section.items.length - 1,
                isEven: e.key.isEven,
                onTap: () => _openDetail(context, e.value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrainingReviewSectionTile extends StatefulWidget {
  final List<TrainingReview> reviews;
  const TrainingReviewSectionTile({super.key, required this.reviews});

  @override
  State<TrainingReviewSectionTile> createState() => _TrainingReviewSectionTileState();
}

class _TrainingReviewSectionTileState extends State<TrainingReviewSectionTile> {
  bool _compareMode = false;
  final Set<int> _selected = {};

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    return '${dt.day}. ${months[dt.month - 1]} ${dt.year}';
  }

  void _toggleCompareMode() {
    setState(() {
      _compareMode = !_compareMode;
      _selected.clear();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
    // Auto-navigate when 2+ selected
    if (_selected.length >= 2) {
      final selectedReviews = _selected.map((i) => widget.reviews[i]).toList();
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TrainingCompareScreen(reviews: selectedReviews),
      )).then((_) {
        // Reset compare mode when returning
        setState(() {
          _compareMode = false;
          _selected.clear();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = widget.reviews;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _compareMode ? AppColors.primary : AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: AppColors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.monitor_heart_rounded, color: AppColors.red, size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Training',
                        style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('${reviews.length} Einheit${reviews.length != 1 ? 'en' : ''}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (reviews.length >= 2)
                GestureDetector(
                  onTap: _toggleCompareMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _compareMode ? AppColors.primary : AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _compareMode ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      _compareMode ? 'Abbrechen' : 'Vergleichen',
                      style: TextStyle(
                        color: _compareMode ? AppColors.white : AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: null,
          iconColor: AppColors.muted,
          collapsedIconColor: AppColors.muted,
          initiallyExpanded: false,
          children: [
            const Divider(color: AppColors.border, height: 1),
            if (_compareMode && _selected.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.primary.withOpacity(0.08),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Wähle 2 Trainings zum Vergleichen',
                        style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ...reviews.asMap().entries.map((e) {
              final review = e.value;
              final isLast = e.key == reviews.length - 1;
              final isSelected = _selected.contains(e.key);
              return InkWell(
                onTap: _compareMode
                    ? () => _toggleSelection(e.key)
                    : () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TrainingReviewDetailScreen(review: review),
                      )),
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(13))
                    : BorderRadius.zero,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : e.key.isEven
                            ? Colors.transparent
                            : AppColors.surface2.withOpacity(0.4),
                    border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (_compareMode) ...[
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.muted,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, size: 16, color: AppColors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(review.trainingType,
                                style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(_formatDate(review.date),
                                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                      if (review.hrMax != null)
                        Text('${review.hrMax} bpm',
                            style: const TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                      if (!_compareMode) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.border),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class PerformanceItemRow extends StatelessWidget {
  final PerformanceItem item;
  final bool isLast;
  final bool isEven;
  final VoidCallback? onTap;

  const PerformanceItemRow({
    super.key,
    required this.item,
    this.isLast = false,
    this.isEven = true,
    this.onTap,
  });

  Widget _changeWidget() {
    final change = item.change.toLowerCase();
    if (change == 'up' || change == 'increase' || change == '+') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.arrow_upward_rounded,
              size: 14, color: AppColors.green),
        ],
      );
    } else if (change == 'down' || change == 'decrease' || change == '-') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.arrow_downward_rounded,
              size: 14, color: AppColors.red),
        ],
      );
    } else if (item.change.isNotEmpty && item.change != '0') {
      final isPositive = !item.change.startsWith('-');
      return Text(
        item.change,
        style: TextStyle(
          color: isPositive ? AppColors.green : AppColors.red,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(13))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isEven
              ? Colors.transparent
              : AppColors.surface2.withOpacity(0.4),
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.name,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.value,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.previousValue,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _changeWidget(),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.border),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
