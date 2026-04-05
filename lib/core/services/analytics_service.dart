// TODO: Реализовать AnalyticsService после подключения Firebase
// Сервис логирует события в Firebase Analytics:
// - generation_started (format, style)
// - generation_success (format, style, duration_ms)
// - generation_error (error_type)
// - image_downloaded (format)

class AnalyticsService {
  AnalyticsService();

  // TODO: инжектировать FirebaseAnalytics

  Future<void> logGenerationStarted({
    required String format,
    String? style,
  }) async {
    // TODO: FirebaseAnalytics.logEvent
  }

  Future<void> logGenerationSuccess({
    required String format,
    String? style,
    required int durationMs,
  }) async {
    // TODO: FirebaseAnalytics.logEvent
  }

  Future<void> logGenerationError({required String errorType}) async {
    // TODO: FirebaseAnalytics.logEvent
  }

  Future<void> logImageDownloaded({required String format}) async {
    // TODO: FirebaseAnalytics.logEvent
  }
}
