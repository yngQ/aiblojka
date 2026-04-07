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
      // RC key convention: style value must match the suffix of 'style_<value>'
      // (e.g. style='gaming' → key 'style_gaming'). Keep style enum values and
      // RC keys in sync.
      final instruction = remoteConfig.getString('style_$style');
      if (instruction.isNotEmpty) stylePrefix = '$instruction ';
    }

    // If Remote Config fetch failed and defaults weren't loaded, fall back to
    // the raw user description so Gemini still receives a meaningful prompt.
    if (template.isEmpty) return '$stylePrefix$userDescription';

    return template.replaceFirst('{prompt}', '$stylePrefix$userDescription');
  }
}
