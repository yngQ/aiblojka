import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  Future<void> logGenerationStarted({
    required String format,
    String? style,
  }) async {
    await _analytics.logEvent(
      name: 'generation_started',
      parameters: {
        'format': format,
        if (style != null) 'style': style,
      },
    );
  }

  Future<void> logGenerationSuccess({
    required String format,
    String? style,
    required int durationMs,
  }) async {
    await _analytics.logEvent(
      name: 'generation_success',
      parameters: {
        'format': format,
        if (style != null) 'style': style,
        'duration_ms': durationMs,
      },
    );
  }

  Future<void> logGenerationError({required String errorType}) async {
    await _analytics.logEvent(
      name: 'generation_error',
      parameters: {'error_type': errorType},
    );
  }

  Future<void> logImageDownloaded({required String format}) async {
    await _analytics.logEvent(
      name: 'image_downloaded',
      parameters: {'format': format},
    );
  }
}
