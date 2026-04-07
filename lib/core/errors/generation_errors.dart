/// Typed exceptions for the generation pipeline.
///
/// All errors that can originate from [GenerationService] are modelled here
/// as a sealed class hierarchy so call-sites can exhaustively switch over them.
sealed class GenerationException implements Exception {
  const GenerationException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// HTTP 429 — Gemini quota exhausted.
final class QuotaExceededException extends GenerationException {
  const QuotaExceededException([
    super.message = 'Daily generation limit reached. Please try again tomorrow.',
  ]);
}

/// HTTP 451 — Content-policy / safety filter blocked the request.
final class SafetyBlockException extends GenerationException {
  const SafetyBlockException([
    super.message =
        'The request was blocked by the content safety filter. Please modify your description and try again.',
  ]);
}

/// HTTP 5xx / 502 — Upstream (Gemini or Worker) returned a server error.
final class ServerException extends GenerationException {
  const ServerException([
    super.message = 'The AI service returned an error. Please try again later.',
  ]);
}

/// HTTP 422 — Gemini did not produce an image part.
final class NoImageGeneratedException extends GenerationException {
  const NoImageGeneratedException([
    super.message =
        'The AI model did not generate an image. Please modify your description and try again.',
  ]);
}

/// No HTTP response — socket error, timeout, or other network failure.
final class NetworkException extends GenerationException {
  const NetworkException([
    super.message = 'Network error. Please check your connection and try again.',
  ]);
}

/// Generation is disabled via Remote Config kill switch.
final class GenerationDisabledException extends GenerationException {
  const GenerationDisabledException([
    super.message = 'Generation is currently disabled. Please try again later.',
  ]);
}

/// Cloudflare Worker URL is not configured in Remote Config.
final class WorkerNotConfiguredException extends GenerationException {
  const WorkerNotConfiguredException([
    super.message = 'Worker URL is not configured. Set cloudflare_worker_url in Remote Config.',
  ]);
}
