import 'remote_config_service.dart';

/// Assembles the user concept sent to the Cloudflare Worker.
///
/// The Worker constructs the full generation prompt internally
/// (format instruction + quality requirements). This builder only
/// prepends the optional style instruction from Remote Config.
class PromptBuilder {
  PromptBuilder({required this.remoteConfig});

  final RemoteConfigService remoteConfig;

  String build({
    required String userDescription,
    String? style,
  }) {
    String stylePrefix = '';
    if (style != null && style.isNotEmpty) {
      final instruction = remoteConfig.getString('$rcStyleKeyPrefix$style');
      if (instruction.isNotEmpty) stylePrefix = '$instruction ';
    }
    return '$stylePrefix$userDescription';
  }
}
