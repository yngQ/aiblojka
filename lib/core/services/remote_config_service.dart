// TODO: Реализовать RemoteConfigService после подключения Firebase
// Сервис будет загружать параметры из Firebase Remote Config:
// - URL Cloudflare Worker (cloudflare_worker_url)
// - Шаблоны промптов (prompt_template_long, prompt_template_short)
// - Kill-switch (generation_enabled)
// - Лимиты (daily_generation_limit)

class RemoteConfigService {
  RemoteConfigService();

  Future<void> initialize() async {
    // TODO: firebase_remote_config инициализация
  }

  String getString(String key, {String defaultValue = ''}) {
    // TODO: вернуть значение из Remote Config
    return defaultValue;
  }

  bool getBool(String key, {bool defaultValue = true}) {
    // TODO: вернуть значение из Remote Config
    return defaultValue;
  }

  int getInt(String key, {int defaultValue = 0}) {
    // TODO: вернуть значение из Remote Config
    return defaultValue;
  }
}
