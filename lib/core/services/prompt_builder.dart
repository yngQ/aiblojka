import 'remote_config_service.dart';

const _kTemplateLongKey = 'prompt_template_long';
const _kTemplateShortKey = 'prompt_template_short';

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
        format == 'long' ? _kTemplateLongKey : _kTemplateShortKey;
    final template = remoteConfig.getString(templateKey);

    String stylePrefix = '';
    if (style != null && style.isNotEmpty) {
      final instruction = remoteConfig.getString('style_$style');
      if (instruction.isNotEmpty) stylePrefix = '$instruction ';
    }

    return template.replaceFirst('{prompt}', '$stylePrefix$userDescription');
  }
}
