import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_unit_ids.dart';

class AdMobService {
  // ── Ad Unit IDs ──────────────────────────────────────────────────────────
  // Debug builds always use Google's official test ad unit IDs -- safe to
  // request unlimited times, never deliver a real ad or real revenue.
  // Release builds read from AdUnitIds (ad_unit_ids.dart), which ships
  // with clearly marked placeholders until real IDs are pasted in there --
  // see that file's own doc comment. Never invent a real-looking ID here.
  static String get _bannerId => kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111' // Google test banner
      : AdUnitIds.banner;
  static String get _interstitialId => kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712' // Google test interstitial
      : AdUnitIds.interstitial;

  static InterstitialAd? _interstitialAd;

  /// Call once in main(), after Firebase.initializeApp(). Runs Google's
  /// User Messaging Platform (UMP) consent flow BEFORE ever touching
  /// MobileAds.instance.initialize() -- requestConsentInfoUpdate() checks
  /// where the user is and what they've already decided, then
  /// loadAndShowConsentFormIfRequired() shows the consent form only if
  /// one is actually required (EEA/UK/Switzerland, or wherever else
  /// Google's own geography rules require it -- this app doesn't decide
  /// that itself). The ads SDK is only initialized afterward, and only if
  /// ConsentInformation.instance.canRequestAds() says yes -- a user who
  /// hasn't consented (or whose status came back unclear) sees no ads
  /// this session rather than this code guessing what they'd want.
  static Future<void> initialize() async {
    if (kIsWeb) return;

    final params = ConsentRequestParameters(
      consentDebugSettings: kDebugMode ? _debugConsentSettings() : null,
    );

    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              debugPrint('UMP consent form error: ${formError.message}');
            }
          });
        } catch (e) {
          // Best-effort: a failure loading/showing the form shouldn't
          // crash startup. canRequestAds() below is still the real gate
          // on whether ads actually get requested.
          debugPrint('UMP consent form load/show threw: $e');
        }
        await _initializeAdsIfConsented();
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        // Couldn't even determine consent status (e.g. no network at
        // startup) -- fail closed: don't initialize the ads SDK this
        // session rather than assuming consent was given.
        debugPrint('UMP requestConsentInfoUpdate failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  static Future<void> _initializeAdsIfConsented() async {
    if (await ConsentInformation.instance.canRequestAds()) {
      await MobileAds.instance.initialize();
      _loadInterstitial();
    }
  }

  /// Debug-only EEA simulation + test-device registration, so the
  /// consent flow can actually be exercised without being physically in
  /// the EEA, and so AdMob doesn't treat this device's ad requests as
  /// real traffic while testing.
  ///
  /// PASTE YOUR TEST DEVICE ID BELOW. Find it by running a debug build
  /// once with any ad request -- AdMob logs a line like:
  ///   "Use RequestConfiguration.Builder#setTestDeviceIds(Arrays.asList("ABCDEF0123456789ABCDEF0123456789"))"
  /// to logcat/the debug console the first time it sees a request from
  /// an unregistered device. Copy that hashed ID in as a string below.
  static ConsentDebugSettings _debugConsentSettings() {
    return ConsentDebugSettings(
      debugGeography: DebugGeography.debugGeographyEea,
      testIdentifiers: [
        'PASTE_YOUR_TEST_DEVICE_HASHED_ID_HERE',
      ],
    );
  }

  /// Whether a "Privacy options" entry should be shown in the app's
  /// account menu -- UMP sets this to required only when the user is
  /// somewhere (EEA/UK/Switzerland) that needs an ongoing way to revisit
  /// their consent choice, not just a one-time prompt at first launch.
  static Future<bool> isPrivacyOptionsRequired() async {
    if (kIsWeb) return false;
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// Re-opens the UMP consent form so the user can change an earlier
  /// choice -- wire this to the "Privacy options" menu entry.
  static Future<void> showPrivacyOptionsForm() async {
    if (kIsWeb) return;
    await ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        debugPrint('UMP privacy options form error: ${formError.message}');
      }
    });
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
