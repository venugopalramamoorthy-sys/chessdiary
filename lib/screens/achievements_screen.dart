import 'package:flutter/material.dart' hide Badge;
import 'package:intl/intl.dart';
import '../services/badge_service.dart';
import '../utils/theme.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: StreamBuilder<List<Badge>>(
        stream: BadgeService.badgesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final badges = snap.data ?? [];
          if (badges.isEmpty) return _emptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: badges.length,
            itemBuilder: (_, i) => _BadgeTile(badge: badges[i]),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('🏅', style: TextStyle(fontSize: 56)),
          SizedBox(height: 16),
          Text('No badges yet',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Log games, analyse mistakes, and build streaks\nto earn your first badge!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Badge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(badge.emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(badge.title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(badge.description,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'Earned ${DateFormat('d MMM yyyy').format(badge.earnedAt)}',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
