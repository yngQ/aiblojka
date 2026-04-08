import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService() : _analytics = FirebaseAnalytics.instance;

  /// No-op analytics for widget tests — avoids requiring Firebase
  /// initialization.
  @visibleForTesting
  AnalyticsService.stub() : _analytics = null;

  final FirebaseAnalytics? _analytics;

  Future<void> logGenerationStarted({
    required String format,
    String? style,
  }) async {
    if (_analytics == null) return;
    final params = <String, Object>{'format': format};
    if (style != null) params['style'] = style;
    await _analytics.logEvent(name: 'generation_started', parameters: params);
  }

  Future<void> logGenerationSuccess({
    required String format,
    String? style,
    required int durationMs,
  }) async {
    if (_analytics == null) return;
    final params = <String, Object>{
      'format': format,
      'duration_ms': durationMs,
    };
    if (style != null) params['style'] = style;
    await _analytics.logEvent(name: 'generation_success', parameters: params);
  }

  Future<void> logGenerationError({required String errorType}) async {
    if (_analytics == null) return;
    await _analytics.logEvent(
      name: 'generation_error',
      parameters: {'error_type': errorType},
    );
  }

  Future<void> logImageDownloaded({required String format}) async {
    if (_analytics == null) return;
    await _analytics.logEvent(
      name: 'image_downloaded',
      parameters: {'format': format},
    );
  }

  Future<void> logReferenceImageUploaded() async {
    if (_analytics == null) return;
    await _analytics.logEvent(name: 'reference_image_uploaded');
  }
}
