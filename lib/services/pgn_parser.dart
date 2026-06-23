class PgnParser {
  /// Parses a PGN string into the same map format as GeminiService returns.
  static Map<String, dynamic> parse(String pgn) {
    final headers = <String, String>{};
    final headerRe = RegExp(r'\[(\w+)\s+"([^"]*)"\]');
    for (final m in headerRe.allMatches(pgn)) {
      headers[m.group(1)!] = m.group(2)!;
    }

    // Extract clock times BEFORE stripping comments
    final clocks = extractClockSeconds(pgn);

    // Strip headers and comments, extract move tokens
    final noHeaders = pgn.replaceAll(RegExp(r'\[.*?\]\s*', dotAll: true), '');
    final noComments = noHeaders.replaceAll(RegExp(r'\{[^}]*\}'), '');
    final noClock = noComments.replaceAll(RegExp(r'\$\d+'), '');
    final tokens = noClock
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .where((t) => !RegExp(r'^\d+\.+$').hasMatch(t))
        .where((t) => !RegExp(r'^(1-0|0-1|1/2-1/2|\*)$').hasMatch(t))
        .toList();

    final result = headers['Result'] ?? '*';
    final dateRaw = headers['Date'] ?? headers['UTCDate'];
    String? dateStr;
    if (dateRaw != null && dateRaw != '????.??.??') {
      dateStr = dateRaw.replaceAll('.', '-');
    }

    return {
      'playerWhite': headers['White'] ?? 'Unknown',
      'playerBlack': headers['Black'] ?? 'Unknown',
      'result': result,
      'event': headers['Event'],
      'date': dateStr,
      'moves': tokens,
      'pgn': pgn.trim(),
      'opening': headers['Opening'] ?? headers['ECO'],
      'ratingWhite': int.tryParse(headers['WhiteElo'] ?? ''),
      'ratingBlack': int.tryParse(headers['BlackElo'] ?? ''),
      'totalMoves': tokens.length,
      'parseConfidence': 'high',
      'notes': '',
      'clockSeconds': clocks,
    };
  }

  /// Extracts clock times (seconds remaining) from %clk annotations in PGN comments.
  /// Returns one value per half-move in order.
  /// Format: { [%clk h:mm:ss] } or { [%clk m:ss] }
  static List<int> extractClockSeconds(String pgn) {
    final clocks = <int>[];
    final commentRe = RegExp(r'\{([^}]*)\}');
    final clkRe = RegExp(r'\[%clk\s+(\d+):(\d+):(\d+)\]');
    final clkShortRe = RegExp(r'\[%clk\s+(\d+):(\d+)\]');

    for (final cm in commentRe.allMatches(pgn)) {
      final comment = cm.group(1) ?? '';
      final m = clkRe.firstMatch(comment);
      if (m != null) {
        final h = int.parse(m.group(1)!);
        final min = int.parse(m.group(2)!);
        final sec = int.parse(m.group(3)!);
        clocks.add(h * 3600 + min * 60 + sec);
        continue;
      }
      // Try short format (m:ss without hours)
      final s = clkShortRe.firstMatch(comment);
      if (s != null) {
        final min = int.parse(s.group(1)!);
        final sec = int.parse(s.group(2)!);
        clocks.add(min * 60 + sec);
      }
    }
    return clocks;
  }
}
