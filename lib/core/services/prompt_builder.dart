// TODO: Реализовать PromptBuilder
// Собирает финальный текстовый промпт для Gemini на основе:
// - Шаблона из Remote Config
// - Пользовательского описания
// - Выбранного стиля
// - Формата (long/short)
// Промпты отправляются на английском языке.

class PromptBuilder {
  PromptBuilder();

  // TODO: инжектировать RemoteConfigService для получения шаблонов
  String build({
    required String userDescription,
    required String format,
    String? style,
  }) {
    // TODO: применить шаблон из Remote Config и подставить параметры
    throw UnimplementedError('PromptBuilder.build not implemented');
  }
}
