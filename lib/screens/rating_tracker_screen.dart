import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/rating_service.dart';
import '../utils/theme.dart';

class RatingTrackerScreen extends StatefulWidget {
  const RatingTrackerScreen({super.key});

  @override
  State<RatingTrackerScreen> createState() => _RatingTrackerScreenState();
}

class _RatingTrackerScreenState extends State<RatingTrackerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rating Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Log rating',
            onPressed: _addEntry,
          ),
        ],
      ),
      body: StreamBuilder<List<RatingEntry>>(
        stream: RatingService.entriesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) return _emptyState();

          // Group by type
          final Map<String, List<RatingEntry>> byType = {};
          for (final e in entries) {
            (byType[e.type] ??= []).add(e);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Latest ratings summary
                _latestSummary(byType),
                const SizedBox(height: 16),
                // Chart per type
                ...byType.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _typeChart(entry.key, entry.value),
                    )),
                // Full history list
                _historyList(entries),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _latestSummary(Map<String, List<RatingEntry>> byType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Ratings',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 14),
          ...byType.entries.map((entry) {
            final sorted = List<RatingEntry>.from(entry.value)
              ..sort((a, b) => b.date.compareTo(a.date));
            final latest = sorted.first;
            final prev = sorted.length > 1 ? sorted[1] : null;
            final diff = prev != null ? latest.rating - prev.rating : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(_typeIcon(entry.key), style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_typeName(entry.key),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        Text('${latest.rating}',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (diff != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: diff >= 0
                            ? AppTheme.win.withOpacity(0.15)
                            : AppTheme.loss.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        diff >= 0 ? '+$diff' : '$diff',
                        style: TextStyle(
                          color: diff >= 0 ? AppTheme.win : AppTheme.loss,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _typeChart(String type, List<RatingEntry> entries) {
    if (entries.length < 2) return const SizedBox();
    final sorted = List<RatingEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));
    final spots = sorted.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.rating.toDouble()))
        .toList();
    final minY = sorted.map((e) => e.rating).reduce((a, b) => a < b ? a : b) - 30.0;
    final maxY = sorted.map((e) => e.rating).reduce((a, b) => a > b ? a : b) + 30.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_typeIcon(type), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('${_typeName(type)} Trend',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppTheme.surfaceAlt, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= sorted.length) return const SizedBox();
                        final d = sorted[idx].date;
                        return Text('${d.month}/${d.year % 100}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.secondary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: AppTheme.secondary,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.secondary.withOpacity(0.1),
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

  Widget _historyList(List<RatingEntry> entries) {
    final sorted = List<RatingEntry>.from(entries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('History',
                style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          ...sorted.map((e) => ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(_typeIcon(e.type), style: const TextStyle(fontSize: 16)),
                  ),
                ),
                title: Text(
                  '${e.rating}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                subtitle: Text(
                  '${_typeName(e.type)} · ${e.date.day}/${e.date.month}/${e.date.year}'
                  '${e.note != null ? ' · ${e.note}' : ''}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary, size: 20),
                  onPressed: () => _deleteEntry(e),
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _addEntry() async {
    final ratingCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = 'fide';
    DateTime date = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Log Rating',
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Type selector
              Row(
                children: ['fide', 'national', 'ecf', 'other'].map((t) {
                  final sel = type == t;
                  return GestureDetector(
                    onTap: () => setModal(() => type = t),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary.withOpacity(0.2) : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? AppTheme.primary : Colors.transparent),
                      ),
                      child: Text(
                        '${_typeIcon(t)} ${_typeName(t)}',
                        style: TextStyle(
                            color: sel ? AppTheme.primary : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ratingCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Rating',
                  prefixIcon: Icon(Icons.star_rounded, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              // Date picker
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppTheme.primary)),
                      child: child!,
                    ),
                  );
                  if (picked != null) setModal(() => date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppTheme.textSecondary, size: 18),
                      const SizedBox(width: 12),
                      Text('${date.day}/${date.month}/${date.year}',
                          style: const TextStyle(color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. After national championship',
                  prefixIcon: Icon(Icons.notes_rounded, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final rating = int.tryParse(ratingCtrl.text.trim());
                  if (rating == null) return;
                  await RatingService.addEntry(RatingEntry(
                    id: '',
                    date: date,
                    rating: rating,
                    type: type,
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  ));
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Rating'),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _deleteEntry(RatingEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete entry?',
            style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.loss)),
          ),
        ],
      ),
    );
    if (confirm == true) await RatingService.deleteEntry(entry.id);
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('No ratings logged yet',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap + to log your official rating',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addEntry,
            icon: const Icon(Icons.add),
            label: const Text('Log Rating'),
          ),
        ],
      ),
    );
  }

  String _typeIcon(String type) {
    switch (type) {
      case 'fide': return '🌍';
      case 'national': return '🏅';
      case 'ecf': return '🏴󠁧󠁢󠁥󠁮󠁧󠁿';
      default: return '⭐';
    }
  }

  String _typeName(String type) {
    switch (type) {
      case 'fide': return 'FIDE';
      case 'national': return 'National';
      case 'ecf': return 'ECF';
      default: return 'Other';
    }
  }
}
