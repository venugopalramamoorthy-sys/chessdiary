// Renders a published game report (publicGames/{slug}) to HTML.
//
// Shared by two callers so a report looks the same however it is served:
//   - web/g/index.html, in the browser, for share links that have not been
//     built into static pages yet (those pages are noindex, no ads);
//   - tools/public-games/build.js, in Node at deploy time, which writes an
//     indexable static page for every approved report.
// Input is the plain report object (see normalise() in build.js and
// fromFirestoreRest() below); every user-supplied string is escaped here.
(function (root) {
  var PIECE_DEFS = typeof module !== 'undefined' && module.exports
    ? require('./pieces.js')
    : root.CD_PIECE_DEFS;

  var SITE = 'https://chessdiary.app';
  var QUALITY = {
    inaccuracy: { label: 'Inaccuracy', symbol: '?!' },
    mistake: { label: 'Mistake', symbol: '?' },
    blunder: { label: 'Blunder', symbol: '??' },
    checkmate: { label: 'Checkmate', symbol: '#' },
  };
  var SOURCE = {
    paper: 'over-the-board tournament',
    'chess.com': 'Chess.com',
    lichess: 'Lichess',
    other: 'chess',
  };
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'];
  // Tactical motifs (as the analysis names them) -> the guide that explains them.
  var MOTIF_GUIDES = [
    [/fork/i, '/guides/knight-forks-how-to-spot-them/', 'Knight Forks: How to Spot Them'],
    [/pin|skewer|discover/i, '/guides/pins-skewers-and-discovered-attacks/', 'Pins, Skewers and Discovered Attacks'],
    [/back.?rank/i, '/guides/back-rank-mate-how-to-stop-it/', 'Back-Rank Mate and How to Stop It'],
    [/mate/i, '/guides/checkmate-patterns-every-player-should-know/', 'Checkmate Patterns Every Player Should Know'],
  ];

  function esc(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  // Blank lines separate paragraphs; single newlines become line breaks.
  function paragraphs(text, cls) {
    return String(text || '').trim().split(/\n\s*\n/).filter(Boolean).map(function (p) {
      return '<p' + (cls ? ' class="' + cls + '"' : '') + '>' +
        esc(p.trim()).replace(/\n/g, '<br>') + '</p>';
    }).join('\n');
  }

  function moveLabel(ply, san) {
    var n = Math.floor(ply / 2) + 1;
    return n + (ply % 2 === 0 ? '.' : '&hellip;') + esc(san);
  }

  function displayDate(d) {
    var m = /^(\d{4})-(\d{2})(?:-(\d{2}))?/.exec(d || '');
    if (!m) return '';
    var month = MONTHS[parseInt(m[2], 10) - 1] || '';
    return (m[3] ? parseInt(m[3], 10) + ' ' : '') + month + ' ' + m[1];
  }

  function pawns(cp) {
    return (Math.round(Math.abs(cp) / 10) / 10).toFixed(1);
  }

  function playerLine(p) {
    return esc(p.name) + (p.rating ? ' (' + esc(p.rating) + ')' : '');
  }

  function resultPhrase(result) {
    if (result === '1-0') return 'White wins';
    if (result === '0-1') return 'Black wins';
    if (result === '1/2-1/2') return 'Draw';
    return 'Unfinished';
  }

  function fullMoves(r) {
    return Math.ceil((r.moves || []).length / 2);
  }

  function title(r) {
    var head = r.opening ? r.opening : 'An ' + (SOURCE[r.source] || 'chess') + ' game';
    var t = head + ': ' + resultPhrase(r.result) + ' in ' + fullMoves(r) + ' moves, annotated';
    if (r.white.rating && r.black.rating) t += ' (' + r.white.rating + ' vs ' + r.black.rating + ')';
    return t;
  }

  function description(r) {
    var notes = String(r.notes || '').replace(/\s+/g, ' ').trim();
    if (notes.length >= 80) return notes.length > 155 ? notes.slice(0, 152).replace(/\s+\S*$/, '') + '…' : notes;
    return 'A ' + (SOURCE[r.source] || 'chess') + ' game annotated by the player who played it: ' +
      resultPhrase(r.result).toLowerCase() + ' in ' + fullMoves(r) + ' moves, with Stockfish analysis of the critical moments.';
  }

  // ── Board diagram ────────────────────────────────────────────────────────
  var PIECE_IDS = {
    P: 'white-pawn', N: 'white-knight', B: 'white-bishop', R: 'white-rook', Q: 'white-queen', K: 'white-king',
    p: 'black-pawn', n: 'black-knight', b: 'black-bishop', r: 'black-rook', q: 'black-queen', k: 'black-king',
  };

  function boardSvg(fen, flip, label) {
    var rows = String(fen).split(' ')[0].split('/');
    var out = ['<svg viewBox="0 0 390 390" width="360" height="360" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="' + esc(label) + '">'];
    out.push('<rect x="0" y="0" width="390" height="390" fill="#212121"/>');
    for (var r = 0; r < 8; r++) {
      for (var f = 0; f < 8; f++) {
        var x = 15 + 45 * (flip ? 7 - f : f), y = 15 + 45 * (flip ? 7 - r : r);
        out.push('<rect x="' + x + '" y="' + y + '" width="45" height="45" fill="' + ((r + f) % 2 ? '#b58863' : '#f0d9b5') + '"/>');
      }
    }
    for (var i = 0; i < 8; i++) {
      var file = 'abcdefgh'[flip ? 7 - i : i], rank = flip ? i + 1 : 8 - i;
      out.push('<text x="' + (37.5 + 45 * i) + '" y="11" font-size="10" text-anchor="middle" fill="#e5e5e5" font-family="Georgia,serif">' + file + '</text>');
      out.push('<text x="7.5" y="' + (41 + 45 * i) + '" font-size="10" text-anchor="middle" fill="#e5e5e5" font-family="Georgia,serif">' + rank + '</text>');
    }
    rows.forEach(function (row, ri) {
      var fi = 0;
      for (var c = 0; c < row.length; c++) {
        var ch = row[c];
        if (/\d/.test(ch)) { fi += parseInt(ch, 10); continue; }
        if (PIECE_IDS[ch]) {
          var px = 15 + 45 * (flip ? 7 - fi : fi), py = 15 + 45 * (flip ? 7 - ri : ri);
          out.push('<use href="#cd-' + PIECE_IDS[ch] + '" transform="translate(' + px + ',' + py + ')"/>');
        }
        fi++;
      }
    });
    out.push('</svg>');
    return out.join('');
  }

  // ── Evaluation graph (same geometry as the sample-analysis pages) ───────
  function evalGraph(r) {
    var curve = r.evalCurve || [];
    if (curve.length < 2) return '';
    var x0 = 44, x1 = 686, mid = 119, half = 105, cap = 800;
    function x(i) { return x0 + (x1 - x0) * i / (curve.length - 1); }
    function y(v) { return mid - Math.max(-cap, Math.min(cap, v)) / cap * half; }
    var s = ['<svg viewBox="0 0 700 260" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Engine evaluation after each half-move, from White\'s point of view">'];
    [-8, -4, 0, 4, 8].forEach(function (p) {
      var yy = y(p * 100).toFixed(1);
      s.push('<line x1="' + x0 + '" y1="' + yy + '" x2="' + x1 + '" y2="' + yy + '" stroke="' + (p ? '#E8E6DF' : '#9A9890') + '" stroke-width="1"' + (p ? '' : ' stroke-dasharray="3,3"') + '/>');
      s.push('<text x="38" y="' + (+yy + 4) + '" font-size="10.5" text-anchor="end" fill="#666" font-family="Georgia,serif">' + (p > 0 ? '+' : p < 0 ? '−' : '') + Math.abs(p) + '</text>');
    });
    for (var m = 10; 2 * m - 1 < curve.length; m += 10) {
      var xm = x(2 * m - 1).toFixed(1);
      s.push('<line x1="' + xm + '" y1="14" x2="' + xm + '" y2="224" stroke="#EFEDE6" stroke-width="1"/>');
      s.push('<text x="' + xm + '" y="240" font-size="10.5" text-anchor="middle" fill="#666" font-family="Georgia,serif">move ' + m + '</text>');
    }
    s.push('<polyline points="' + curve.map(function (v, i) { return x(i).toFixed(1) + ',' + y(v).toFixed(1); }).join(' ') +
      '" fill="none" stroke="#1B5E20" stroke-width="2.4" stroke-linejoin="round"/>');
    (r.moments || []).forEach(function (mo) {
      if (mo.ply >= curve.length) return;
      var cx = x(mo.ply), cy = y(curve[mo.ply]);
      s.push('<circle cx="' + cx.toFixed(1) + '" cy="' + cy.toFixed(1) + '" r="4" fill="#B3261E"/>');
      s.push('<text x="' + cx.toFixed(1) + '" y="' + (cy > 40 ? cy - 12 : cy + 20).toFixed(1) + '" font-size="10.5" text-anchor="middle" fill="#0C0C0C" font-weight="bold" font-family="Georgia,serif">' +
        moveLabel(mo.ply, mo.move).replace('&hellip;', '...') + '</text>');
    });
    s.push('</svg>');
    return s.join('');
  }

  function counts(r) {
    var c = { white: {}, black: {} };
    (r.analysis || []).forEach(function (a) {
      var side = a.ply % 2 === 0 ? 'white' : 'black';
      c[side][a.quality] = (c[side][a.quality] || 0) + 1;
    });
    return c;
  }

  function moveList(r) {
    var flagged = {};
    (r.analysis || []).forEach(function (a) { flagged[a.ply] = a.quality; });
    function cell(ply) {
      var san = r.moves[ply];
      if (san == null) return '<td></td>';
      var q = QUALITY[flagged[ply]];
      return '<td>' + esc(san) + (q && flagged[ply] !== 'checkmate'
        ? '<span class="mq q-' + flagged[ply] + '" title="' + q.label + '">' + q.symbol + '</span>' : '') + '</td>';
    }
    var rows = [];
    for (var ply = 0; ply < r.moves.length; ply += 2) {
      rows.push('<tr><td class="num-col">' + (ply / 2 + 1) + '.</td>' + cell(ply) + cell(ply + 1) + '</tr>');
    }
    return '<div class="movelist-wrap"><table class="movelist"><thead><tr><th>#</th><th>White</th><th>Black</th></tr></thead><tbody>' +
      rows.join('') + '</tbody></table></div>';
  }

  function relatedGuides(r) {
    var seen = {}, links = [];
    (r.moments || []).forEach(function (mo) {
      MOTIF_GUIDES.forEach(function (g) {
        if (mo.motif && g[0].test(mo.motif) && !seen[g[1]]) { seen[g[1]] = 1; links.push([g[1], g[2]]); }
      });
    });
    links.push(['/guides/how-to-read-a-stockfish-analysis-report/', 'How to Read a Stockfish Analysis Report']);
    links.push(['/guides/how-to-review-a-tournament-loss/', 'How to Review a Tournament Loss']);
    return links;
  }

  function motifLink(motif) {
    for (var i = 0; i < MOTIF_GUIDES.length; i++) {
      if (MOTIF_GUIDES[i][0].test(motif)) return '<a href="' + MOTIF_GUIDES[i][1] + '">' + esc(motif) + '</a>';
    }
    return esc(motif);
  }

  // ── Page ─────────────────────────────────────────────────────────────────
  function render(r) {
    var author = r.playerColor === 'black' ? 'black' : 'white';
    var flip = author === 'black';
    var c = counts(r);
    var h = [];

    h.push('<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>' + PIECE_DEFS + '</defs></svg>');
    h.push('<div class="page-eyebrow"><span>Player-Annotated Game</span></div>');
    h.push('<h1>' + esc(title(r)) + '</h1>');
    var byline = 'Annotated by ' + esc(r.authorName) + ', who played ' + (author === 'white' ? 'White' : 'Black');
    if (r.publishedAt) byline += ' &nbsp;·&nbsp; Published ' + esc(displayDate(r.publishedAt));
    if (r.updatedAt && r.publishedAt && r.updatedAt.slice(0, 10) !== r.publishedAt.slice(0, 10)) {
      byline += ' &nbsp;·&nbsp; Updated ' + esc(displayDate(r.updatedAt));
    }
    h.push('<p class="byline">' + byline + '</p>');

    var meta = ['<strong>White:</strong> ' + playerLine(r.white), '<strong>Black:</strong> ' + playerLine(r.black)];
    if (r.datePlayed) meta.push(esc(displayDate(r.datePlayed)));
    if (r.event) meta.push(esc(r.event));
    if (r.timeControl) meta.push(esc(r.timeControl.charAt(0).toUpperCase() + r.timeControl.slice(1)));
    meta.push('<strong>Result:</strong> ' + esc(r.result));
    h.push('<p class="game-meta">' + meta.join(' &nbsp;·&nbsp; ') + '</p>');

    h.push('<p>This ' + esc(SOURCE[r.source] || 'chess') + ' game was published on ChessDiary by ' + esc(r.authorName) +
      ', who played the ' + author + ' pieces. The notes and the comments on each critical moment are theirs; the evaluations come from ChessDiary&rsquo;s Stockfish analysis of the game.</p>');

    if (String(r.notes || '').trim()) {
      h.push('<hr class="divider"><h2>THE PLAYER&rsquo;S NOTES</h2>');
      h.push(paragraphs(r.notes));
    }

    var graph = evalGraph(r);
    if (graph) {
      h.push('<hr class="divider"><h2>THE GAME IN ONE GRAPH</h2>');
      h.push('<div class="graph-card">' + graph + '<div class="graph-legend">Evaluation after each half-move from White&rsquo;s point of view, in pawns, capped at ±8. Red dots mark the critical moments below.</div></div>');
    }

    if ((r.moments || []).length) {
      h.push('<hr class="divider"><h2>CRITICAL MOMENTS</h2>');
      r.moments.forEach(function (mo) {
        var q = QUALITY[mo.quality] || { label: mo.quality };
        var side = mo.ply % 2 === 0 ? 'White' : 'Black';
        h.push('<h3>' + moveLabel(mo.ply, mo.move) + ' <span class="qb q-' + esc(mo.quality) + '">' + esc(q.label) + '</span></h3>');
        var cap = side + ' to move. ' + side + ' played ' + moveLabel(mo.ply, mo.move);
        if (mo.cpLoss) cap += ', losing about ' + pawns(mo.cpLoss) + ' pawns';
        cap += '.';
        if (mo.bestMove) cap += ' Stockfish preferred ' + moveLabel(mo.ply, mo.bestMove) + '.';
        h.push('<figure class="board">' + boardSvg(mo.fen, flip, side + ' to move, before ' + moveLabel(mo.ply, mo.move).replace('&hellip;', '...')) +
          '<figcaption>' + cap + (mo.motif ? ' Theme: ' + motifLink(mo.motif) + '.' : '') + '</figcaption></figure>');
        if (String(mo.comment || '').trim()) {
          h.push('<div class="player-note"><span class="player-note-label">' + esc(r.authorName) + ':</span>' + paragraphs(mo.comment) + '</div>');
        }
      });
    }

    h.push('<hr class="divider"><h2>WHAT THE ENGINE FLAGGED</h2>');
    h.push('<div class="table-wrap"><table class="simple"><thead><tr><th></th><th>White</th><th>Black</th></tr></thead><tbody>' +
      ['inaccuracy', 'mistake', 'blunder'].map(function (k) {
        return '<tr><td><span class="qb q-' + k + '">' + QUALITY[k].label + '</span></td><td>' + (c.white[k] || 0) + '</td><td>' + (c.black[k] || 0) + '</td></tr>';
      }).join('') + '</tbody></table></div>');
    h.push('<p>Counts cover the moves the analysis flagged as most significant (up to twenty per game), so a long game can have more small inaccuracies than are listed here.</p>');

    h.push('<hr class="divider"><h2>FULL MOVE LIST</h2>');
    h.push(moveList(r));

    h.push('<div class="cta-box"><p><strong>Have a game you want to understand?</strong> ChessDiary reads a photo of your paper scoresheet or imports your Chess.com and Lichess games, and runs every one through Stockfish.</p>' +
      '<div class="cta-actions"><a href="/app" class="cta-primary">Analyse your own games →</a><a href="/games/" class="cta-secondary">More player-annotated games →</a></div></div>');

    h.push('<div class="related"><h3>RELATED GUIDES</h3>' + relatedGuides(r).map(function (l) {
      return '<a href="' + l[0] + '">' + esc(l[1]) + ' →</a>';
    }).join('') + '</div>');

    h.push('<p class="credit">Published by a ChessDiary user, who chose what to share; opponents are not named unless the game was played on a public platform and the player chose to show the name. ' +
      'See something wrong with this page? <a href="/contact/?report=' + encodeURIComponent(r.slug) + '">Report it</a>. ' +
      'Board diagrams use piece graphics by Colin M.L. Burnett (CC BY-SA 3.0 / GPL).</p>');

    return {
      title: title(r),
      description: description(r),
      path: '/g/' + r.slug + '/',
      html: h.join('\n'),
      jsonLd: {
        '@context': 'https://schema.org',
        '@type': 'Article',
        headline: title(r),
        description: description(r),
        author: { '@type': 'Person', name: r.authorName },
        publisher: { '@type': 'Organization', name: 'ChessDiary', url: SITE + '/' },
        datePublished: (r.publishedAt || '').slice(0, 10) || undefined,
        dateModified: (r.updatedAt || r.publishedAt || '').slice(0, 10) || undefined,
        mainEntityOfPage: SITE + '/g/' + r.slug + '/',
      },
    };
  }

  // Index of approved reports for /games/, newest first.
  function renderIndex(reports) {
    var h = ['<div class="page-eyebrow"><span>From the ChessDiary Community</span></div>',
      '<h1>PLAYER-ANNOTATED GAMES</h1>',
      '<p>Real games, published by the players who played them. Each one has the player&rsquo;s own notes on what they were thinking, Stockfish&rsquo;s verdict on the critical moments, and the full score. Every report is reviewed before it appears here.</p>',
      '<hr class="divider">'];
    reports.forEach(function (r) {
      var notes = String(r.notes || '').replace(/\s+/g, ' ').trim();
      h.push('<div class="game-card"><h3><a href="/g/' + encodeURIComponent(r.slug) + '/">' + esc(title(r)) + '</a></h3>' +
        '<p class="game-meta">' + playerLine(r.white) + ' &ndash; ' + playerLine(r.black) + ' &nbsp;·&nbsp; ' + esc(displayDate(r.datePlayed)) +
        ' &nbsp;·&nbsp; annotated by ' + esc(r.authorName) + '</p>' +
        (notes ? '<p>' + esc(notes.length > 220 ? notes.slice(0, 217).replace(/\s+\S*$/, '') + '…' : notes) + '</p>' : '') + '</div>');
    });
    h.push('<div class="cta-box"><p><strong>Publish your own game.</strong> Analyse a game in ChessDiary, add your notes, and choose <em>Publish to web</em> on the game screen.</p>' +
      '<div class="cta-actions"><a href="/app" class="cta-primary">Open ChessDiary →</a><a href="/sample-analysis/" class="cta-secondary">See the sample analyses →</a></div></div>');
    return h.join('\n');
  }

  // Firestore REST document -> the plain report object render() expects.
  function fromFirestoreRest(doc) {
    function val(v) {
      if (!v) return null;
      if ('stringValue' in v) return v.stringValue;
      if ('integerValue' in v) return parseInt(v.integerValue, 10);
      if ('doubleValue' in v) return v.doubleValue;
      if ('booleanValue' in v) return v.booleanValue;
      if ('timestampValue' in v) return v.timestampValue;
      if ('nullValue' in v) return null;
      if ('arrayValue' in v) return (v.arrayValue.values || []).map(val);
      if ('mapValue' in v) return fields(v.mapValue.fields || {});
      return null;
    }
    function fields(f) {
      var o = {};
      Object.keys(f).forEach(function (k) { o[k] = val(f[k]); });
      return o;
    }
    return fromStored(fields(doc.fields || {}));
  }

  // Stored Firestore fields (already decoded to plain values) -> report object.
  function fromStored(d) {
    return {
      slug: d.slug,
      authorName: d.authorName,
      playerColor: d.playerColor,
      white: { name: d.whiteName, rating: d.whiteRating },
      black: { name: d.blackName, rating: d.blackRating },
      result: d.result,
      datePlayed: d.datePlayed,
      source: d.source,
      event: d.event,
      opening: d.opening,
      timeControl: d.timeControl,
      moves: d.moves || [],
      evalCurve: d.evalCurve || [],
      analysis: d.analysis || [],
      moments: d.moments || [],
      notes: d.notes || '',
      approved: d.approved === true,
      publishedAt: d.publishedAt,
      updatedAt: d.updatedAt,
    };
  }

  var api = { render: render, renderIndex: renderIndex, fromFirestoreRest: fromFirestoreRest, fromStored: fromStored, esc: esc };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.CDReport = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
