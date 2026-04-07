import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web/web.dart' as web;

import '../../../core/errors/generation_errors.dart';
import '../../../core/providers/services_providers.dart';
import '../../../core/services/generation_service.dart';
import '../../../core/services/remote_config_service.dart';

part 'generation_provider.g.dart';

enum GenerationFormat { long, short }

@riverpod
class GenerationNotifier extends _$GenerationNotifier {
  @override
  AsyncValue<GenerationResult?> build() {
    final remoteConfig = ref.read(remoteConfigServiceProvider);
    if (remoteConfig.getString(rcKeyWorkerUrl).isEmpty) {
      return AsyncValue.error(
        const WorkerNotConfiguredException(),
        StackTrace.current,
      );
    }
    if (!remoteConfig.getBool(rcKeyGenerationEnabled)) {
      return AsyncValue.error(
        const GenerationDisabledException(),
        StackTrace.current,
      );
    }
    return const AsyncValue.data(null);
  }

  Future<void> generate({
    required String prompt,
    required GenerationFormat format,
    String? style,
    String? referenceImageBase64,
    String? referenceMimeType,
  }) async {
    if (!web.window.navigator.onLine) {
      state = AsyncValue.error(const NetworkException(), StackTrace.current);
      return;
    }

    final remoteConfig = ref.read(remoteConfigServiceProvider);
    // Guards duplicated from build() — the generate button doesn't disable
    // on error state, so we re-check here to prevent actual API calls.
    if (remoteConfig.getString(rcKeyWorkerUrl).isEmpty) {
      state = AsyncValue.error(
        const WorkerNotConfiguredException(),
        StackTrace.current,
      );
      return;
    }
    if (!remoteConfig.getBool(rcKeyGenerationEnabled)) {
      state = AsyncValue.error(
        const GenerationDisabledException(),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    final formatStr = format == GenerationFormat.long ? 'long' : 'short';
    final analytics = ref.read(analyticsServiceProvider);

    unawaited(analytics.logGenerationStarted(format: formatStr, style: style));

    final fullPrompt = ref.read(promptBuilderProvider).build(
          userDescription: prompt,
          format: formatStr,
          style: style,
        );

    final service = ref.read(generationServiceProvider);
    final startTime = DateTime.now();

    try {
      final result = await service.generateCover(
        prompt: fullPrompt,
        format: formatStr,
        style: style,
        referenceImageBase64: referenceImageBase64,
        referenceMimeType: referenceMimeType,
      );
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      unawaited(analytics.logGenerationSuccess(
        format: formatStr,
        style: style,
        durationMs: durationMs,
      ));
      state = AsyncValue.data(result);
    } catch (e, st) {
      final errorType = switch (e) {
        QuotaExceededException() => 'quota_exceeded',
        SafetyBlockException() => 'safety_block',
        NetworkException() => 'network',
        NoImageGeneratedException() => 'no_image',
        ServerException() => 'server',
        GenerationDisabledException() => 'disabled',
        WorkerNotConfiguredException() => 'worker_not_configured',
        _ => 'unknown',
      };
      unawaited(analytics.logGenerationError(errorType: errorType));
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
