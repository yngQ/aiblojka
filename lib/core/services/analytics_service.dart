import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService() : _analytics = FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  Future<void> logGenerationStarted({
    required String format,
    String? style,
  }) async {
    final params = <String, Object>{'format': format};
    if (style != null) params['style'] = style;
    await _analytics.logEvent(name: 'generation_started', parameters: params);
  }

  Future<void> logGenerationSuccess({
    required String format,
    String? style,
    required int durationMs,
  }) async {
    final params = <String, Object>{
      'format': format,
      'duration_ms': durationMs,
    };
    if (style != null) params['style'] = style;
    await _analytics.logEvent(name: 'generation_success', parameters: params);
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
