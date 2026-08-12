import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:nutriscan/config/ads_config.dart';
import 'package:nutriscan/providers/payment/subscription_provider.dart';
import 'package:provider/provider.dart';

class AdaptiveBannerAd extends StatefulWidget {
  const AdaptiveBannerAd({super.key});

  @override
  State<AdaptiveBannerAd> createState() => _AdaptiveBannerAdState();
}

class _AdaptiveBannerAdState extends State<AdaptiveBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoadingAd = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isLoadingAd && _bannerAd == null) {
      _loadBannerAd();
    }
  }

  Future<void> _loadBannerAd() async {
    if (!AdsConfig.adsEnabled) return;
    if (_isLoadingAd) return;

    _isLoadingAd = true;

    try {
      // Use standard banner size (320x50)
      _bannerAd = BannerAd(
        adUnitId: AdsConfig.bannerAdUnitId,
        size: AdSize.banner, // 320x50
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted) {
              setState(() {
                _isAdLoaded = true;
                _isLoadingAd = false;
              });
            }
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _bannerAd = null;
            _isLoadingAd = false;
            if (mounted) {
              setState(() => _isAdLoaded = false);
              // Without this the slot stays empty for the whole screen's life:
              // didChangeDependencies won't fire again to retry.
              if (_retryCount < AdsConfig.maxRetryAttempts) {
                _retryCount++;
                _retryTimer?.cancel();
                _retryTimer = Timer(AdsConfig.retryDelay, () {
                  if (mounted) _loadBannerAd();
                });
              }
            }
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      _isLoadingAd = false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdsConfig.adsEnabled) {
      return const SizedBox.shrink();
    }
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        // Hide banner for premium users
        if (subscriptionProvider.hasPremiumFeatures) {
          return const SizedBox.shrink();
        }

        // Show banner only when loaded
        if (!_isAdLoaded || _bannerAd == null) {
          // Don't show anything while loading
          return const SizedBox.shrink();
        }

        return Container(
          alignment: Alignment.center,
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          color: Colors.transparent,
          child: AdWidget(ad: _bannerAd!),
        );
      },
    );
  }
}
