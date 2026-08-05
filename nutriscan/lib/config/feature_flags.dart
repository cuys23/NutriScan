import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:nutriscan/config/api_config.dart';

/// Ops kill switches / live-tunable values (docs/plan.md Phase 5 Ops
/// checklist), backed by Firebase Remote Config so they can change without
/// an app release. Defaults match current hardcoded behavior exactly — until
/// a value is set in the Remote Config console, nothing changes for users.
class FeatureFlags {
  FeatureFlags._internal();
  static final FeatureFlags _instance = FeatureFlags._internal();
  factory FeatureFlags() => _instance;

  static const _fkbMatcherEnabledKey = 'fkb_matcher_enabled';
  static const _aiModelScanKey = 'ai_model_scan';

  FirebaseRemoteConfig? _remoteConfig;

  /// Fetches once and caches for the app session (default min fetch
  /// interval); call at startup. Never throws — a Remote Config outage
  /// falls back to the hardcoded defaults, same as before this existed.
  Future<void> init() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      await remoteConfig.setDefaults({
        _fkbMatcherEnabledKey: true,
        _aiModelScanKey: ApiConfig.groqModel,
      });
      await remoteConfig.fetchAndActivate();
      _remoteConfig = remoteConfig;
    } catch (e) {
      debugPrint('FeatureFlags.init failed, using hardcoded defaults: $e');
    }
  }

  /// Kill switch for the FKB matcher (docs/plan.md Phase 1C). When false,
  /// every scan is left as `source: estimated` without calling matchFood —
  /// use if the matcher or FKB data is misbehaving in production and a fix
  /// needs longer than a redeploy.
  bool get fkbMatcherEnabled =>
      _remoteConfig?.getBool(_fkbMatcherEnabledKey) ?? true;

  /// Groq model id used for vision scan calls (food validation + analysis)
  /// and the health coach. Falls back to the hardcoded ApiConfig.groqModel
  /// default. Changing this has cost/quality implications — verify with
  /// eval/run_mape.mjs before rolling out a new value in the console.
  String get aiModelScan {
    final value = _remoteConfig?.getString(_aiModelScanKey) ?? '';
    return value.isEmpty ? ApiConfig.groqModel : value;
  }
}
