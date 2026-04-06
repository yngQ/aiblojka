import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web/web.dart' as web;

import '../../../core/errors/generation_errors.dart';
import '../../../core/providers/services_providers.dart';
import '../../../core/services/generation_service.dart';

part 'generation_provider.g.dart';

enum GenerationFormat { long, short }

@riverpod
class GenerationNotifier extends _$GenerationNotifier {
  @override
  AsyncValue<GenerationResult?> build() => const AsyncValue.data(null);

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

    state = const AsyncValue.loading();

    final service = ref.read(generationServiceProvider);
    final formatStr = format == GenerationFormat.long ? 'long' : 'short';

    try {
      final result = await service.generateCover(
        prompt: prompt,
        format: formatStr,
        style: style,
        referenceImageBase64: referenceImageBase64,
        referenceMimeType: referenceMimeType,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
