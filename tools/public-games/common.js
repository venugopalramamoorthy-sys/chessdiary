'use strict';

const fs = require('fs');
const path = require('path');

// Same rule as PublicReportService.slugPattern in the app and the
// publicGames rules in firestore.rules.
const SLUG_RE = /^[a-z0-9-]{8,80}$/;

// The bar a report must clear before it can be indexed and carry ads; the
// app shows the same numbers (PublicReportService.minOwnWords/minComments).
const MIN_OWN_WORDS = 150;
const MIN_COMMENTED_MOMENTS = 2;

function words(text) {
  return String(text || '').trim().split(/\s+/).filter(Boolean).length;
}

function quality(report) {
  const moments = report.moments || [];
  const commented = moments.filter((m) => words(m.comment) > 0).length;
  const ownWords = words(report.notes) + moments.reduce((n, m) => n + words(m.comment), 0);
  return { ownWords, commented, meetsBar: ownWords >= MIN_OWN_WORDS && commented >= MIN_COMMENTED_MOMENTS };
}

function approvedForIndex(report) {
  return report.approved === true && quality(report).meetsBar;
}

// Firestore via the Admin SDK's modular API (firebase-admin 12+; v14 removed
// the old namespaced admin.apps / admin.firestore()).
function loadDb() {
  const { initializeApp, getApps, applicationDefault, cert } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  if (!getApps().length) {
    const key = path.resolve(__dirname, '..', '..', 'serviceAccount.json');
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      initializeApp({ credential: applicationDefault() });
    } else if (fs.existsSync(key)) {
      initializeApp({ credential: cert(require(key)) });
    } else {
      throw new Error('No Firebase Admin credentials: put serviceAccount.json at the repo root ' +
        '(Firebase Console → Project settings → Service accounts), or set SKIP_PUBLIC_GAMES=1 to deploy without report pages.');
    }
  }
  return getFirestore();
}

module.exports = { SLUG_RE, MIN_OWN_WORDS, MIN_COMMENTED_MOMENTS, words, quality, approvedForIndex, loadDb };
