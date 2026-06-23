// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../services/import_manager.dart';
import '../utils/theme.dart';
import '../widgets/game_card.dart';
import 'achievements_screen.dart';
import 'add_game_screen.dart';
import 'events_screen.dart';
import 'library_screen.dart';
import 'openings_screen.dart';
import 'opponents_screen.dart';
import 'progress_screen.dart';
import 'rating_tracker_screen.dart';
import 'share_profile_screen.dart';
import 'study_mode_screen.dart';
import 'game_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  ImportProgress _importProgress = const ImportProgress.idle();

  @override
  void initState() {
    super.initState();
    ImportManager.instance.progressStream.listen((p) {
      if (mounted) setState(() => _importProgress = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _Dashboard(),
      const LibraryScreen(),
      const EventsScreen(),
      const ProgressScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: screens[_currentIndex]),
          // Import progress banner — visible on any tab
          if (_importProgress.active || (_importProgress.done > 0 && !_importProgress.active && _importProgress.error == null))
            _ImportBanner(progress: _importProgress),
          if (_importProgress.error != null)
            _ImportBanner(progress: _importProgress),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up_rounded), label: 'Progress'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddGameScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Game'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }
}

class _ImportBanner extends StatelessWidget {
  final ImportProgress progress;
  const _ImportBanner({required this.progress});

  @override
  Widget build(BuildContext context) {
    final isError = progress.error != null;
    final isDone = !progress.active && progress.done > 0 && !isError;
    final color = isError ? AppTheme.loss : isDone ? AppTheme.primary : AppTheme.primary;

    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (progress.active)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                )
              else
                Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                  size: 16,
                  color: color,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isError
                      ? 'Import failed: ${progress.error}'
                      : isDone
                          ? 'Imported ${progress.done} games from ${progress.source}'
                          : progress.label,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (progress.active) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.fraction,
              backgroundColor: AppTheme.surfaceAlt,
              color: AppTheme.primary,
              minHeight: 3,
            ),
          ],
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName ?? 'Player').split(' ').first;

    return SafeArea(
      child: StreamBuilder<List<ChessGame>>(
        stream: GameService.gamesStream(),
        builder: (context, snap) {
          final games = snap.data ?? [];
          final wins = games.where((g) => g.resultDisplay == 'Win').length;
          final losses = games.where((g) => g.resultDisplay == 'Loss').length;
          final draws = games.where((g) => g.resultDisplay == 'Draw').length;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hey, $firstName 👋',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const Text(
                                'ChessDiary',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Text('♟', style: TextStyle(fontSize: 36)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // W/L/D summary
                      if (games.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _wld('$wins', 'Wins', AppTheme.win),
                              _vDivider(),
                              _wld('$losses', 'Losses', AppTheme.loss),
                              _vDivider(),
                              _wld('$draws', 'Draws', AppTheme.draw),
                              _vDivider(),
                              _wld('${games.length}', 'Total', AppTheme.primary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Quick access grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 3.2,
                        children: [
                          _quickCard(context, '📖', 'Openings', 'Your repertoire',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OpeningsScreen()))),
                          _quickCard(context, '⭐', 'Ratings', 'Track FIDE/national',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingTrackerScreen()))),
                          _quickCard(context, '🎯', 'Study', 'Review your mistakes',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyModeScreen()))),
                          _quickCard(context, '👤', 'Opponents', 'Head-to-head records',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OpponentsScreen()))),
                          _quickCard(context, '🏅', 'Achievements', 'Your badges',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()))),
                          _quickCard(context, '🔗', 'Share Profile', 'Export your stats',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShareProfileScreen()))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Recent Games',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              if (games.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('♟', style: TextStyle(fontSize: 72)),
                          const SizedBox(height: 20),
                          const Text(
                            'Your chess journey\nstarts here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap + Add Game to log your first game.\nAI will read your scoresheet automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => GameCard(
                        game: games[i],
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => GameDetailScreen(game: games[i]),
                          ),
                        ),
                      ),
                      childCount: games.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickCard(BuildContext context, String emoji, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppTheme.textSecondary, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _wld(String count, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(count,
              style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 28, color: AppTheme.surfaceAlt);
}
