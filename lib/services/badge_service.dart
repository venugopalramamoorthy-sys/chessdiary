import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_model.dart';
import '../services/rating_service.dart';

class Badge {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final DateTime earnedAt;

  Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.earnedAt,
  });

  factory Badge.fromMap(Map<String, dynamic> map, String id) => Badge(
        id: id,
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        emoji: map['emoji'] ?? '🏅',
        earnedAt: DateTime.parse(map['earnedAt']),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'emoji': emoji,
        'earnedAt': earnedAt.toIso8601String(),
      };
}

// All possible milestone definitions
class _Milestone {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool Function(_MilestoneData data) check;

  _Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.check,
  });
}

class _MilestoneData {
  final List<ChessGame> games;
  final int ratingCount;

  _MilestoneData({required this.games, required this.ratingCount});

  int get total => games.length;
  int get wins => games.where((g) => g.resultDisplay == 'Win').length;
  int get analysedCount => games.where((g) => g.analysis.isNotEmpty).length;

  bool get hasBlunderFreeGame => games.any((g) =>
      g.analysis.isNotEmpty &&
      g.analysis.every((a) => a.quality != 'blunder'));

  int get currentWinStreak {
    int streak = 0;
    for (final g in games) {
      if (g.resultDisplay == 'Win') streak++;
      else break;
    }
    return streak;
  }

  bool get hasChessComImport => games.any((g) => g.source == 'chess.com');
  bool get hasLichessImport => games.any((g) => g.source == 'lichess');
  bool get hasPaperGame => games.any((g) => g.source == 'paper');

  Set<String> get uniqueOpponents =>
      games.map((g) => g.opponentName.trim().toLowerCase())
          .where((n) => n.isNotEmpty && n != 'unknown')
          .toSet();

  Set<String> get uniqueOpenings =>
      games.map((g) => g.opening ?? '').where((o) => o.isNotEmpty).toSet();
}

final _milestones = [
  _Milestone(
    id: 'first_game',
    title: 'First Move',
    description: 'Logged your first game',
    emoji: '♟️',
    check: (d) => d.total >= 1,
  ),
  _Milestone(
    id: 'games_10',
    title: 'Getting Started',
    description: 'Logged 10 games',
    emoji: '📚',
    check: (d) => d.total >= 10,
  ),
  _Milestone(
    id: 'games_50',
    title: 'Dedicated Player',
    description: 'Logged 50 games',
    emoji: '🎯',
    check: (d) => d.total >= 50,
  ),
  _Milestone(
    id: 'games_100',
    title: 'Century',
    description: 'Logged 100 games',
    emoji: '💯',
    check: (d) => d.total >= 100,
  ),
  _Milestone(
    id: 'games_500',
    title: 'Chess Obsessed',
    description: 'Logged 500 games',
    emoji: '🔥',
    check: (d) => d.total >= 500,
  ),
  _Milestone(
    id: 'win_streak_3',
    title: 'On a Roll',
    description: '3-game win streak',
    emoji: '⚡',
    check: (d) => d.currentWinStreak >= 3,
  ),
  _Milestone(
    id: 'win_streak_5',
    title: 'Hot Streak',
    description: '5-game win streak',
    emoji: '🔥',
    check: (d) => d.currentWinStreak >= 5,
  ),
  _Milestone(
    id: 'win_streak_10',
    title: 'Unstoppable',
    description: '10-game win streak',
    emoji: '👑',
    check: (d) => d.currentWinStreak >= 10,
  ),
  _Milestone(
    id: 'first_analysis',
    title: 'Under the Microscope',
    description: 'Analysed your first game',
    emoji: '🔍',
    check: (d) => d.analysedCount >= 1,
  ),
  _Milestone(
    id: 'blunder_free',
    title: 'Clean Game',
    description: 'Completed a game with no blunders',
    emoji: '✨',
    check: (d) => d.hasBlunderFreeGame,
  ),
  _Milestone(
    id: 'import_chesscom',
    title: 'Chess.com Connected',
    description: 'Imported games from Chess.com',
    emoji: '♟',
    check: (d) => d.hasChessComImport,
  ),
  _Milestone(
    id: 'import_lichess',
    title: 'Lichess Explorer',
    description: 'Imported games from Lichess',
    emoji: '🦁',
    check: (d) => d.hasLichessImport,
  ),
  _Milestone(
    id: 'paper_game',
    title: 'Old School',
    description: 'Logged a paper scoresheet game',
    emoji: '📝',
    check: (d) => d.hasPaperGame,
  ),
  _Milestone(
    id: 'opponents_10',
    title: 'Social Player',
    description: 'Played against 10 different opponents',
    emoji: '🤝',
    check: (d) => d.uniqueOpponents.length >= 10,
  ),
  _Milestone(
    id: 'openings_5',
    title: 'Opening Explorer',
    description: 'Played 5 different openings',
    emoji: '📖',
    check: (d) => d.uniqueOpenings.length >= 5,
  ),
  _Milestone(
    id: 'rating_logged',
    title: 'Rated Player',
    description: 'Logged your first official rating',
    emoji: '⭐',
    check: (d) => d.ratingCount >= 1,
  ),
];

class BadgeService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;
  static CollectionReference get _col =>
      _db.collection('users').doc(_uid).collection('badges');

  static Future<List<Badge>> getEarnedBadges() async {
    final snap = await _col.orderBy('earnedAt', descending: true).get();
    return snap.docs
        .map((d) => Badge.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  static Stream<List<Badge>> badgesStream() => _col
      .orderBy('earnedAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => Badge.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList());

  /// Check for newly earned badges and save them to Firestore.
  /// Returns list of newly awarded badges (so caller can show a popup).
  static Future<List<Badge>> checkAndAward(List<ChessGame> games) async {
    final ratingEntries = await RatingService.getAllEntries();
    final data = _MilestoneData(games: games, ratingCount: ratingEntries.length);

    // Load already-earned badge IDs
    final earned = await getEarnedBadges();
    final earnedIds = earned.map((b) => b.id).toSet();

    final newlyAwarded = <Badge>[];
    final batch = _db.batch();

    for (final milestone in _milestones) {
      if (earnedIds.contains(milestone.id)) continue;
      if (!milestone.check(data)) continue;

      final badge = Badge(
        id: milestone.id,
        title: milestone.title,
        description: milestone.description,
        emoji: milestone.emoji,
        earnedAt: DateTime.now(),
      );
      batch.set(_col.doc(milestone.id), badge.toMap());
      newlyAwarded.add(badge);
    }

    if (newlyAwarded.isNotEmpty) await batch.commit();
    return newlyAwarded;
  }
}
