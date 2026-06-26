import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  // ── Ad Unit IDs ──────────────────────────────────────────────────────────
  // These are Google's official test IDs — safe to use during development.
  // Replace both with real ad unit IDs from AdMob Console before release.
  static const String _bannerId =
      'ca-app-pub-3940256099942544/6300978111'; // test banner
  static const String _interstitialId =
      'ca-app-pub-3940256099942544/1033173712'; // test interstitial

  static InterstitialAd? _interstitialAd;

  // Call once in main() after Firebase.initializeApp()
  static Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  // ── Interstitial ─────────────────────────────────────────────────────────

  static void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  // Show interstitial if ready; silently skips if not loaded yet.
  static void showInterstitial() {
    if (kIsWeb || _interstitialAd == null) return;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    _interstitialAd!.show();
    _interstitialAd = null;
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  static BannerAd createBanner({required BannerAdListener listener}) {
    return BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: listener,
    );
  }
}
