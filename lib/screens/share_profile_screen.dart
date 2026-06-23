import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/platform_file.dart';
import '../services/badge_service.dart';
import '../services/game_service.dart';
import '../services/rating_service.dart';
import '../utils/theme.dart';

class ShareProfileScreen extends StatefulWidget {
  const ShareProfileScreen({super.key});

  @override
  State<ShareProfileScreen> createState() => _ShareProfileScreenState();
}

class _ShareProfileScreenState extends State<ShareProfileScreen> {
  final _repaintKey = GlobalKey();
  PlayerStats? _stats;
  List<Badge> _badges = [];
  List<RatingEntry> _ratings = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await GameService.getPlayerStats();
    final badges = await BadgeService.getEarnedBadges();
    final ratings = await RatingService.getAllEntries();
    if (mounted) {
      setState(() {
        _stats = stats;
        _badges = badges;
        _ratings = ratings;
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final path = await platformSaveFile(
        'chessdiary_profile.png', bytes, 'image/png');
      if (path != null) {
        await Share.shareXFiles(
          [XFile(path)],
          text: 'My ChessDiary stats — ${_stats!.totalGames} games logged, ${(_stats!.winRate * 100).toStringAsFixed(0)}% win rate',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.loss),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Profile'),
        actions: [
          if (!_loading)
            IconButton(
              icon: _exporting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                  : const Icon(Icons.share_rounded),
              onPressed: _exporting ? null : _export,
              tooltip: 'Export as image',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Preview — tap share to export as image',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    key: _repaintKey,
                    child: _ProfileCard(
                      stats: _stats!,
                      badges: _badges,
                      latestRating: _ratings.isNotEmpty ? _ratings.last : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _exporting ? null : _export,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share as Image'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Notes, tags, and login details are never included.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final PlayerStats stats;
  final List<Badge> badges;
  final RatingEntry? latestRating;

  const _ProfileCard({
    required this.stats,
    required this.badges,
    this.latestRating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary.withOpacity(0.3), AppTheme.primary.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Text('♟', style: TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ChessDiary',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    Text('${stats.totalGames} games logged',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Win/Loss/Draw row
                Row(
                  children: [
                    _statBox('${stats.wins}', 'Wins', AppTheme.win),
                    const SizedBox(width: 10),
                    _statBox('${stats.losses}', 'Losses', AppTheme.loss),
                    const SizedBox(width: 10),
                    _statBox('${stats.draws}', 'Draws', AppTheme.draw),
                    const SizedBox(width: 10),
                    _statBox(
                      '${(stats.winRate * 100).toStringAsFixed(0)}%',
                      'Win Rate',
                      AppTheme.primary,
                    ),
                  ],
                ),

                // Stacked bar
                const SizedBox(height: 12),
                if (stats.totalGames > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        if (stats.wins > 0)
                          Flexible(flex: stats.wins, child: Container(height: 8, color: AppTheme.win)),
                        if (stats.losses > 0)
                          Flexible(flex: stats.losses, child: Container(height: 8, color: AppTheme.loss)),
                        if (stats.draws > 0)
                          Flexible(flex: stats.draws, child: Container(height: 8, color: AppTheme.draw)),
                      ],
                    ),
                  ),

                // Favourite opening
                if (stats.favoriteOpening != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.book_rounded, color: AppTheme.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Favourite opening: ${stats.favoriteOpening}',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],

                // Rating
                if (latestRating != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppTheme.secondary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${_ratingTypeName(latestRating!.type)} rating: ${latestRating!.rating}',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                    ],
                  ),
                ],

                // Badges
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Achievements',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: badges.take(8).map((b) {
                      final badge = b as Badge;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                        ),
                        child: Text('${badge.emoji} ${badge.title}',
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                      );
                    }).toList(),
                  ),
                ],

                // Footer
                const SizedBox(height: 16),
                const Text('Made with ChessDiary',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _ratingTypeName(String type) {
    switch (type) {
      case 'fide': return 'FIDE';
      case 'national': return 'National';
      case 'ecf': return 'ECF';
      default: return 'Rating';
    }
  }
}
