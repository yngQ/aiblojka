import 'remote_config_service.dart';

/// Assembles a full Gemini prompt from a Remote Config template,
/// the user's free-text description, and an optional style instruction.
///
/// Template format (stored in Remote Config):
///   "...{prompt}..." where `{prompt}` is replaced by style + user text.
class PromptBuilder {
  PromptBuilder({required this.remoteConfig});

  final RemoteConfigService remoteConfig;

  String build({
    required String userDescription,
    required String format,
    String? style,
  }) {
    final templateKey =
        format == 'long' ? rcKeyTemplateLong : rcKeyTemplateShort;
    final template = remoteConfig.getString(templateKey);

    String stylePrefix = '';
    if (style != null && style.isNotEmpty) {
      final instruction =
          remoteConfig.getString('$rcStyleKeyPrefix$style');
      if (instruction.isNotEmpty) stylePrefix = '$instruction ';
    }

    // If Remote Config fetch failed and defaults weren't loaded, fall back to
    // the raw user description so Gemini still receives a meaningful prompt.
    if (template.isEmpty) return '$stylePrefix$userDescription';

    return template.replaceFirst('{prompt}', '$stylePrefix$userDescription');
  }
}
