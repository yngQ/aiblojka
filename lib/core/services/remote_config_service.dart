import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

// Remote Config key constants — shared across the app to avoid magic strings.
const rcKeyWorkerUrl = 'cloudflare_worker_url';
const rcKeyGenerationEnabled = 'generation_enabled';
// Style instruction keys follow the pattern: rcStyleKeyPrefix + styleValue
// (e.g. 'gaming' → 'style_gaming'). Keep GenerationStyle enum values in sync.
const rcStyleKeyPrefix = 'style_';

const _kDefaults = <String, dynamic>{
  rcKeyWorkerUrl: '',
  rcKeyGenerationEnabled: true,
  '${rcStyleKeyPrefix}gaming':
      'Visual style: vibrant gaming aesthetic, neon highlights, dynamic and intense atmosphere.',
  '${rcStyleKeyPrefix}vlog':
      'Visual style: bright, warm, and friendly personal vlog look, natural and inviting.',
  '${rcStyleKeyPrefix}education':
      'Visual style: clean, professional, and informative educational style, trustworthy.',
  '${rcStyleKeyPrefix}business':
      'Visual style: modern corporate business aesthetic, polished and professional.',
  '${rcStyleKeyPrefix}entertainment':
      'Visual style: bold colors, eye-catching entertainment style, fun and engaging.',
};

class RemoteConfigService {
  RemoteConfigService()
      : _rc = FirebaseRemoteConfig.instance,
        _overrides = const {};

  /// Creates a [RemoteConfigService] that uses compile-time defaults and never
  /// touches Firebase. Use this in widget tests to avoid requiring Firebase
  /// initialization.
  @visibleForTesting
  RemoteConfigService.withDefaults()
      : _rc = null,
        _overrides = const {};

  /// Creates a [RemoteConfigService] with custom values merged on top of
  /// compile-time defaults. Use this in unit tests to inject specific config.
  @visibleForTesting
  RemoteConfigService.withValues(Map<String, dynamic> overrides)
      : _rc = null,
        _overrides = Map.unmodifiable(overrides);

  final FirebaseRemoteConfig? _rc;
  final Map<String, dynamic> _overrides;

  Future<void> initialize() async {
    if (_rc == null) return;
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Kill-switch changes take up to 1 hour to reach active sessions.
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await _rc.setDefaults(_kDefaults);
    try {
      await _rc.fetchAndActivate();
    } catch (e) {
      // Use cached or default values if fetch fails (network error, config issue, etc.)
      debugPrint('RemoteConfigService: fetchAndActivate failed: $e');
    }
  }

  /// Returns the string value for [key].
  /// In production, Firebase handles defaults via [setDefaults] called in
  /// [initialize]. When [_rc] is null (test stub), falls back to the
  /// compile-time [_kDefaults] map.
  String getString(String key) =>
      _rc?.getString(key) ??
      (_overrides[key] as String? ?? _kDefaults[key] as String? ?? '');

  bool getBool(String key) =>
      _rc?.getBool(key) ??
      (_overrides[key] as bool? ?? _kDefaults[key] as bool? ?? false);

  int getInt(String key) =>
      _rc?.getInt(key) ??
      (_overrides[key] as int? ?? _kDefaults[key] as int? ?? 0);
}
