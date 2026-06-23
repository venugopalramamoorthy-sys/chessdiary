import 'package:flutter_test/flutter_test.dart';

// Tests for win-rate calculation and the opening "needs review" flagging
// logic that lives in OpeningsScreen._OpeningStat and PlayerStats.
// These are pure functions so they don't need Firebase or Flutter at all.

// Mirrors the rule in OpeningsScreen._OpeningStat.needsReview
bool needsReview(int wins, int losses, int draws) {
  final total = wins + losses + draws;
  if (total < 3) return false;
  return wins / total < 0.4;
}

double winRate(int wins, int total) => total == 0 ? 0.0 : wins / total;

void main() {
  group('Opening "needs review" flag (<40% win rate, ≥3 games)', () {
    test('0 wins from 5 games → flagged', () {
      expect(needsReview(0, 5, 0), isTrue);
    });

    test('1 win from 3 games (33%) → flagged', () {
      expect(needsReview(1, 2, 0), isTrue);
    });

    test('1 win from 4 games (25%) → flagged', () {
      expect(needsReview(1, 3, 0), isTrue);
    });

    test('exactly 40% win rate → NOT flagged (threshold is strict <40%)', () {
      // 2/5 = 40% — boundary: < 40% flags, == 40% does not
      expect(needsReview(2, 3, 0), isFalse);
    });

    test('50% win rate → NOT flagged', () {
      expect(needsReview(3, 3, 0), isFalse);
    });

    test('100% win rate → NOT flagged', () {
      expect(needsReview(5, 0, 0), isFalse);
    });

    test('fewer than 3 games → NOT flagged even with 0 wins', () {
      expect(needsReview(0, 2, 0), isFalse);
      expect(needsReview(0, 1, 0), isFalse);
      expect(needsReview(0, 0, 0), isFalse);
    });

    test('draws count toward total but not toward wins', () {
      // 1 win, 0 losses, 4 draws → 1/5 = 20% → flagged
      expect(needsReview(1, 0, 4), isTrue);
    });

    test('exactly 3 games at 0% → flagged', () {
      expect(needsReview(0, 3, 0), isTrue);
    });
  });

  group('Player win-rate calculation', () {
    test('50% win rate', () {
      expect(winRate(5, 10), closeTo(0.5, 0.001));
    });

    test('0 games returns 0', () {
      expect(winRate(0, 0), equals(0.0));
    });

    test('100% win rate', () {
      expect(winRate(10, 10), equals(1.0));
    });

    test('0% win rate', () {
      expect(winRate(0, 8), equals(0.0));
    });

    test('typical result: 7 wins from 20', () {
      expect(winRate(7, 20), closeTo(0.35, 0.001));
    });
  });
}
