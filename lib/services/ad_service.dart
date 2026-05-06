import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._();
  factory AdService() => _instance;
  AdService._();

  bool _initialized = false;

  // iOS (AdMob real IDs)
  static const _iosBanner = 'ca-app-pub-1729512161428816/3953930012';
  static const _iosRewarded = 'ca-app-pub-1729512161428816/6684713405';
  // Android (test IDs — create Android ad units in AdMob when ready)
  static const _androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _androidRewarded = 'ca-app-pub-3940256099942544/5224354917';

  String get bannerAdUnitId =>
      Platform.isIOS ? _iosBanner : _androidBanner;

  String get rewardedAdUnitId =>
      Platform.isIOS ? _iosRewarded : _androidRewarded;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    debugPrint('[KOK Ad] MobileAds initialized');
  }

  // ── Banner ──

  BannerAd createBannerAd({
    AdSize size = AdSize.banner,
    VoidCallback? onLoaded,
    VoidCallback? onFailed,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (ad, error) {
          debugPrint('[KOK Ad] Banner failed: $error');
          ad.dispose();
          onFailed?.call();
        },
      ),
    );
  }

  // ── Rewarded ──

  RewardedAd? _rewardedAd;
  bool _isLoadingRewarded = false;

  Future<void> loadRewardedAd() async {
    if (_rewardedAd != null || _isLoadingRewarded) return;
    _isLoadingRewarded = true;

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
          debugPrint('[KOK Ad] Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isLoadingRewarded = false;
          debugPrint('[KOK Ad] Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  Future<bool> showRewardedAd({
    required void Function() onRewarded,
  }) async {
    if (_rewardedAd == null) {
      await loadRewardedAd();
      await Future.delayed(const Duration(seconds: 2));
    }

    final ad = _rewardedAd;
    if (ad == null) return false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[KOK Ad] Rewarded show failed: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
    );

    await ad.show(onUserEarnedReward: (_, __) => onRewarded());
    _rewardedAd = null;
    return true;
  }

  bool get isRewardedAdReady => _rewardedAd != null;
}
