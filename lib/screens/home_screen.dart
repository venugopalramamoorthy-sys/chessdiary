// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_model.dart';
import '../services/game_service.dart';
import '../services/import_manager.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';
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
import '../services/auth_service.dart';

Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('You can sign back in any time.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sign out',
              style: TextStyle(color: AppTheme.loss)),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await AuthService.signOut();
  }
}

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

  List<WebTabItem> _stickyTabs(BuildContext context) {
    void goAdd() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AddGameScreen()));
    switch (_currentIndex) {
      case 1: // Library
        return [
          WebTabItem('HOME', WT.charcoal, () => setState(() => _currentIndex = 0)),
          WebTabItem('ADD GAME', WT.greenLt, goAdd),
        ];
      case 2: // Events
        return [
          WebTabItem('HOME', WT.charcoal, () => setState(() => _currentIndex = 0)),
          WebTabItem('LIBRARY', WT.charcoal, () => setState(() => _currentIndex = 1)),
        ];
      case 3: // Progress
        return [
          WebTabItem('YOUR STATS', WT.greenLt, () {}),
          WebTabItem('HOME', WT.charcoal, () => setState(() => _currentIndex = 0)),
        ];
      default: // Home/Dashboard
        return [
          WebTabItem('LIBRARY', WT.charcoal, () => setState(() => _currentIndex = 1)),
          WebTabItem('ADD GAME', WT.greenLt, goAdd),
        ];
    }
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
      appBar: kIsWeb
          ? AppBar(
              backgroundColor: const Color(0xFFF8F7F3),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 20,
              title: const Text('♟  ChessDiary',
                  style: TextStyle(
                    color: Color(0xFF0E180E),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  )),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(
                    height: 1, thickness: 1, color: Color(0xFFDDD8CB)),
              ),
              actions: const [_WebProfileMenu(), SizedBox(width: 12)],
            )
          : null,
      body: WebBodyWithTabs(
        tabs: kIsWeb ? _stickyTabs(context) : [],
        child: Column(
          children: [
            Expanded(
              child: WT.isWide(context)
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: screens[_currentIndex]),
                        const WebAdRail(),
                      ],
                    )
                  : screens[_currentIndex],
            ),
            // Import progress banner — visible on any tab
            if (_importProgress.active || (_importProgress.done > 0 && !_importProgress.active && _importProgress.error == null))
              _ImportBanner(progress: _importProgress),
            if (_importProgress.error != null)
              _ImportBanner(progress: _importProgress),
          ],
        ),
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
        backgroundColor: kIsWeb ? WT.accent : AppTheme.primary,
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
    final color = isError
        ? (kIsWeb ? WT.loss : AppTheme.loss)
        : (kIsWeb ? WT.accent : AppTheme.primary);

    return Container(
      width: double.infinity,
      color: kIsWeb ? WT.bgAlt : AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (progress.active)
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kIsWeb ? WT.accent : AppTheme.primary),
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
    final user      = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName ?? 'Player').split(' ').first;
    final web       = kIsWeb;

    return SafeArea(
      child: StreamBuilder<List<ChessGame>>(
        stream: GameService.gamesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return web
                ? const WebChessLoader(message: 'Loading your games…')
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final games  = snap.data ?? [];
          final wins   = games.where((g) => g.resultDisplay == 'Win').length;
          final losses = games.where((g) => g.resultDisplay == 'Loss').length;
          final draws  = games.where((g) => g.resultDisplay == 'Draw').length;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(web ? 28 : 20, web ? 28 : 24, web ? 28 : 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── greeting row ───────────────────────────────────
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hey, $firstName 👋',
                                style: TextStyle(
                                  color: web ? WT.muted : AppTheme.textSecondary,
                                  fontSize: web ? 13 : 14,
                                  fontFamily: web ? GoogleFonts.inter().fontFamily : null,
                                ),
                              ),
                              Text(
                                'ChessDiary',
                                style: web
                                    ? GoogleFonts.playfairDisplay(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: WT.ink,
                                        height: 1.2,
                                      )
                                    : const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text('♟',
                              style: TextStyle(
                                  fontSize: 32,
                                  color: web ? WT.border : null)),
                          if (!web) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded,
                                  color: AppTheme.textSecondary),
                              tooltip: 'Sign out',
                              onPressed: () => confirmLogout(context),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: web ? 28 : 24),

                      // ── W / L / D summary ──────────────────────────────
                      if (games.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: web
                              ? WT.cardDeco()
                              : BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                          child: Row(
                            children: [
                              _wld('$wins',         'Wins',   web ? WT.win  : AppTheme.win,  web),
                              _vDivider(web),
                              _wld('$losses',       'Losses', web ? WT.loss : AppTheme.loss, web),
                              _vDivider(web),
                              _wld('$draws',        'Draws',  web ? WT.draw : AppTheme.draw, web),
                              _vDivider(web),
                              _wld('${games.length}','Total', web ? WT.accent : AppTheme.primary, web),
                            ],
                          ),
                        ),
                        SizedBox(height: web ? 28 : 24),
                      ],

                      // ── quick access grid ──────────────────────────────
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: web ? 10 : 12,
                        mainAxisSpacing: web ? 10 : 12,
                        childAspectRatio: web ? 3.6 : 3.2,
                        children: [
                          _QuickCard('📖', 'Openings', 'Your repertoire',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OpeningsScreen()))),
                          _QuickCard('⭐', 'Ratings', 'Track FIDE/national',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingTrackerScreen()))),
                          _QuickCard('🎯', 'Study', 'Review your mistakes',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyModeScreen()))),
                          _QuickCard('👤', 'Opponents', 'Head-to-head records',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OpponentsScreen()))),
                          _QuickCard('🏅', 'Achievements', 'Your badges',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()))),
                          _QuickCard('🔗', 'Share Profile', 'Export your stats',
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShareProfileScreen()))),
                        ],
                      ),
                      SizedBox(height: web ? 32 : 24),

                      // ── recent games heading ───────────────────────────
                      Text(
                        'Recent Games',
                        style: web
                            ? GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: WT.ink)
                            : const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ── empty state ─────────────────────────────────────────────
              if (games.isEmpty)
                SliverFillRemaining(
                  child: web
                      ? const WebEmptyState(
                          title: 'Your chess journal is empty',
                          subtitle:
                              'Tap + Add Game to log your first game.\nAI will read your scoresheet automatically.',
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('♟', style: TextStyle(fontSize: 72)),
                                SizedBox(height: 20),
                                Text(
                                  'Your chess journey\nstarts here',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Tap + Add Game to log your first game.\nAI will read your scoresheet automatically.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: AppTheme.textSecondary, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      web ? 28 : 20, 0, web ? 28 : 20, 100),
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

  Widget _wld(String count, String label, Color color, bool web) {
    return Expanded(
      child: Column(
        children: [
          web
              ? Text(count, style: WT.anton(26, color: color, spacing: 0))
              : Text(count,
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
          Text(label,
              style: web
                  ? WT.lora(10, color: WT.muted)
                  : const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _vDivider(bool web) => Container(
      width: 1, height: 28, color: web ? WT.border : AppTheme.surfaceAlt);
}

// ── hover-enabled quick-access card (web) / static card (mobile) ─────────────
class _QuickCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickCard(this.emoji, this.title, this.subtitle, this.onTap);

  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final web  = kIsWeb;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: web
          ? WT.cardDeco(hovered: _hovered)
          : BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
      child: Row(
        children: [
          Text(widget.emoji,
              style: TextStyle(fontSize: web ? 20 : 24)),
          SizedBox(width: web ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.title,
                    style: web
                        ? WT.labelSm(12)
                        : const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                Text(widget.subtitle,
                    style: web
                        ? WT.bodySm(10)
                        : const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: web ? WT.muted : AppTheme.textSecondary,
              size: 11),
        ],
      ),
    );

    if (web) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(onTap: widget.onTap, child: body),
      );
    }
    return GestureDetector(onTap: widget.onTap, child: body);
  }
}

// ── Web-only profile / logout menu ───────────────────────────────────────────
class _WebProfileMenu extends StatelessWidget {
  const _WebProfileMenu();

  @override
  Widget build(BuildContext context) {
    final user    = FirebaseAuth.instance.currentUser;
    final label   = user?.displayName ?? user?.email ?? 'Account';
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      color: WT.charcoal,
      offset: const Offset(0, 56),
      elevation: 0,
      shape: const Border(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar circle
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: WT.greenLt, shape: BoxShape.circle),
              child: Text(initial,
                  style: WT.anton(12, color: WT.white, spacing: 0)),
            ),
            const SizedBox(width: 8),
            Text(label.split(' ').first,
                style: WT.lora(13, color: WT.silver)),
            const Icon(Icons.arrow_drop_down, color: WT.darkGrey, size: 18),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 14, color: WT.silver),
              const SizedBox(width: 10),
              Text('SIGN OUT', style: WT.anton(11, color: WT.white, spacing: 1.5)),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'signout') confirmLogout(context);
      },
    );
  }
}
