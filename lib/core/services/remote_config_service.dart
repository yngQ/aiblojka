import 'package:firebase_remote_config/firebase_remote_config.dart';

const _kDefaults = <String, dynamic>{
  'cloudflare_worker_url': 'http://localhost:8787',
  'generation_enabled': true,
  'prompt_template_long':
      'Create a professional YouTube video thumbnail at 1920x1080 pixels (16:9 landscape). '
      '{prompt} '
      'High resolution, photorealistic quality, no text unless explicitly requested, no visible artifacts.',
  'prompt_template_short':
      'Create a vertical video cover at 1080x1920 pixels (9:16 portrait) '
      'suitable for TikTok, YouTube Shorts, and Instagram Reels. '
      '{prompt} '
      'High resolution, photorealistic quality, no text unless explicitly requested, no visible artifacts.',
  'style_gaming':
      'Visual style: vibrant gaming aesthetic, neon highlights, dynamic and intense atmosphere.',
  'style_vlog':
      'Visual style: bright, warm, and friendly personal vlog look, natural and inviting.',
  'style_education':
      'Visual style: clean, professional, and informative educational style, trustworthy.',
  'style_business':
      'Visual style: modern corporate business aesthetic, polished and professional.',
  'style_entertainment':
      'Visual style: bold colors, eye-catching entertainment style, fun and engaging.',
};

class RemoteConfigService {
  RemoteConfigService();

  FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await _rc.setDefaults(_kDefaults);
    try {
      await _rc.fetchAndActivate();
    } catch (_) {
      // Use cached or default values if the network fetch fails.
    }
  }

  String getString(String key, {String defaultValue = ''}) {
    final value = _rc.getString(key);
    return value.isNotEmpty ? value : defaultValue;
  }

  bool getBool(String key) => _rc.getBool(key);

  int getInt(String key) => _rc.getInt(key);
}
