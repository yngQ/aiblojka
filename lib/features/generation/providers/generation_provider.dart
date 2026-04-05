// TODO: Реализовать GenerationNotifier после реализации GenerationService
// Провайдер будет управлять состоянием генерации обложки:
// - idle → loading → success(imageBase64) / error(message)
// Использовать AsyncNotifier с @riverpod кодогенерацией.

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generation_provider.g.dart';

enum GenerationFormat { long, short }

@riverpod
class GenerationNotifier extends _$GenerationNotifier {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  // TODO: реализовать после подключения GenerationService
  Future<void> generate({
    required String prompt,
    required GenerationFormat format,
    String? style,
    String? referenceImageBase64,
  }) async {
    state = const AsyncValue.loading();
    // TODO: вызвать GenerationService.generateCover
    // TODO: обработать typed errors → локализованные сообщения
    state = AsyncValue.error(
      UnimplementedError('generation not implemented'),
      StackTrace.current,
    );
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
