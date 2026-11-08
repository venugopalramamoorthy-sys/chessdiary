# Public game reports

Players can publish an analysed game as a public page at `chessdiary.app/g/<slug>/`, with their own notes and a comment on each critical moment. Approved reports also become static, indexable pages listed on `chessdiary.app/games/`.

**Why this exists:** AdSense rejected the site for "low-value content". Most of what the crawler could see was generic chess guides, while the app itself sits behind a login and is noindex. These reports add pages that exist nowhere else: real games, explained by the people who played them.

## How it works

```
App (Publish screen) ──writes──▶ Firestore publicGames/{slug}   (approved: false)
                                        │
          share link /g/<slug>/ ◀── web/g/index.html reads it via the REST API
                                     (browser-rendered, noindex, no ads)
                                        │
  you: tools/public-games/reports.js approve <slug>   (approved: true, Admin SDK)
                                        │
  bash deploy.sh ── tools/public-games/build.js ──▶ static /g/<slug>/index.html
                                                      + /games/ + sitemap entries
                                                      (indexable, ads)
```

Both kinds of page are drawn by the same renderer (`web/g/report-render.js`), so they look the same.

## Privacy rules

These are enforced in `PublicReportService.buildReport` and covered by unit tests.

- **The public page is a copy.** It's a frozen copy of selected fields, never a live view of the private game.
- **Over-the-board games:**
  - The opponent is always shown as "Opponent".
  - Only the month and year are shown, not the day.
- **Chess.com and Lichess games:** the opponent's username is shown only if the player switches it on. These games show the exact date.
- **Event name:** hidden unless the player switches it on.
- **Never published:**
  - the player's email or account name (they choose a display name, and email addresses are rejected);
  - scoresheet images;
  - the private notes field. That field only pre-fills the notes box on first publish.
- **Removal:**
  - Unpublishing deletes the document.
  - Deleting a game deletes its report (`GameService.deleteGame`).
  - Deleting an account deletes all of that account's reports (`AuthService.deleteAccount`).

## Quality bar and moderation

- **Eligible to publish:** the game is fully analysed (it has analysis data and an eval curve), it has at least 20 moves, and it has at least one critical moment.
- **Eligible to be indexed and show ads:** the player has written at least 150 words across their notes and comments, has commented on at least 2 moments, **and** you have approved the report.
  - `build.js` checks the word and comment counts again at build time.
  - The same numbers are defined in `PublicReportService` and in `tools/public-games/common.js`; keep the two in step.
- **Edits reset approval.** The rules force `approved == false` on every write from the app, so after any edit the page drops out of the index on the next deploy until you approve it again.
- **Bad language:** a short blocked-word list runs in the app before publishing.
- **Report links:** every report has a "Report it" link that opens `/contact/?report=<slug>` with the form pre-filled.

### Moderation commands

```bash
cd tools/public-games && npm ci          # first time only
node reports.js list --pending           # what is waiting for review
node reports.js show <slug>              # read the notes and comments
node reports.js approve <slug>           # refuses below the bar unless --force
node reports.js unapprove <slug>
node reports.js takedown <slug>          # deletes the report and unlinks the game
bash deploy.sh                           # from the repo root: publishes approved pages
```

## Deploying

- **Deploys build the report pages.** `deploy.sh` runs `build.js` after `flutter build web`. Every Firebase deploy replaces the entire site, so a deploy without this step would take every approved report offline.
- **The Admin key is required.** The build needs `serviceAccount.json` at the repo root. It's gitignored; download it from Firebase Console → Project settings → Service accounts.
- **Without the key, the deploy fails.** To deploy anyway, set `SKIP_PUBLIC_GAMES=1`, knowing that this removes the report pages until the next full deploy.
- **Firestore rules are separate.** Deploy them with `firebase deploy --only firestore:rules`.

## Files

| File | Purpose |
|---|---|
| `lib/services/public_report_service.dart` | Choosing critical moments, computing positions, applying the privacy filter, publish/unpublish |
| `lib/screens/publish_report_screen.dart` | Publish / update / unpublish screen, with the consent box |
| `firestore.rules` (`publicGames`) | Allowed fields, ownership checks, `approved` locked to false for the app |
| `web/g/index.html` | Share-link viewer **and** the template for the static pages; keep its `CD:*` markers |
| `web/g/report-render.js`, `web/g/pieces.js` | Shared renderer; piece artwork generated from python-chess |
| `tools/public-games/build.js` | Static page build (run by `deploy.sh`) |
| `tools/public-games/reports.js` | Moderation command-line tool |
| `tools/public-games/test.js` | Offline build test against `fixture.json` (`npm test`) |
| `test/public_report_service_test.dart` | App-side unit tests |

## Not in v1

- Comments, likes, profile or follower pages
- Scoresheet images
- Embeds on other sites
- Publishing several games at once
- An interactive board on the public page. The pages are fully static, which is better for search engines; a board that steps through the moves could be added later as an enhancement.
