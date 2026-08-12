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
  static const _aiModelVisionKey = 'ai_model_vision';
  static const _aiModelTextKey = 'ai_model_text';
  static const _multiFoodScanEnabledKey = 'multi_food_scan_enabled';

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
        _aiModelVisionKey: ApiConfig.groqModel,
        _aiModelTextKey: ApiConfig.groqModel,
        _multiFoodScanEnabledKey: false,
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

  /// Groq model id used for vision calls (food validation + image analysis
  /// — `VisionAiService`). Falls back to the hardcoded ApiConfig.groqModel
  /// default. Independent from [aiModelText] so vision can move to a
  /// different provider/model without affecting text traffic (docs/
  /// 17_SPLIT_VISION_AI.md).
  String get aiModelVision {
    final value = _remoteConfig?.getString(_aiModelVisionKey) ?? '';
    return value.isEmpty ? ApiConfig.groqModel : value;
  }

  /// Groq model id used for text-only calls (meal plan, insights, health
  /// coach — `GroqService`). Defaults to the same model as [aiModelVision]
  /// today, but can be pointed at a faster/cheaper non-reasoning model via
  /// Remote Config without an app release (docs/17_SPLIT_VISION_AI.md §2.4).
  String get aiModelText {
    final value = _remoteConfig?.getString(_aiModelTextKey) ?? '';
    return value.isEmpty ? ApiConfig.groqModel : value;
  }

  /// Multi-food detection (docs/plan.md Phase 7A). Default OFF — when true,
  /// a single scan can return several distinct food items for the user to
  /// review and select from before anything is saved, instead of always
  /// exactly one.
  bool get multiFoodScanEnabled =>
      _remoteConfig?.getBool(_multiFoodScanEnabledKey) ?? false;
}
