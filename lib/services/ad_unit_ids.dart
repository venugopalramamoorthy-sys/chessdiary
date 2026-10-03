/// Real AdMob ad unit IDs for RELEASE builds only.
///
/// Debug builds never read this file -- they always use Google's own
/// test ad unit IDs instead (hardcoded in admob_service.dart, safe to
/// request unlimited times, never serve a real ad or generate revenue).
/// This file is what a release build actually requests ads with, so the
/// two placeholders below need to become your real IDs from AdMob
/// Console before a release build is meant to serve real ads.
///
/// PASTE YOUR REAL IDS HERE, replacing the placeholder strings exactly
/// (keep the quotes, keep the trailing semicolon):
///   static const String banner = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
///
/// Find these in AdMob Console → Apps → (your app) → Ad units. A banner
/// unit and an interstitial unit, matching the two ad formats
/// admob_service.dart already uses.
class AdUnitIds {
  AdUnitIds._();

  static const String banner = 'ca-app-pub-1687484988403199/3627771238';
  static const String interstitial = 'REPLACE_WITH_REAL_INTERSTITIAL_AD_UNIT_ID';
}
