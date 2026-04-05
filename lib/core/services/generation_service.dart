// TODO: Реализовать GenerationService
// Сервис отправляет POST-запрос на Cloudflare Worker:
// POST {workerUrl}
// Body: { "prompt": "...", "format": "long|short", "referenceImageBase64": "..." }
// Response: { "imageBase64": "...", "mimeType": "image/png" }
//
// Обрабатывать ошибки:
// - 429 → errorLimitExceeded
// - 451 → errorSafetyBlock
// - 5xx → errorServer
// - NetworkException → errorNetwork

class GenerationService {
  GenerationService();

  // TODO: инжектировать http.Client и RemoteConfigService
  Future<String> generateCover({
    required String prompt,
    required String format,
    String? referenceImageBase64,
  }) async {
    // TODO: реализовать HTTP-вызов к Cloudflare Worker
    throw UnimplementedError('GenerationService.generateCover not implemented');
  }
}
