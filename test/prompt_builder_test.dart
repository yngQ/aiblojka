import 'package:flutter_test/flutter_test.dart';

import 'package:aiblojka/core/services/prompt_builder.dart';
import 'package:aiblojka/core/services/remote_config_service.dart';

void main() {
  group('PromptBuilder', () {
    test('returns raw description when no style is given', () {
      final rc = RemoteConfigService.withDefaults();
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(userDescription: 'a sunset over mountains');

      expect(result, 'a sunset over mountains');
    });

    test('prepends style instruction before user description', () {
      final rc = RemoteConfigService.withValues({
        'style_gaming': 'Visual style: neon gaming.',
      });
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(
        userDescription: 'esports match',
        style: 'gaming',
      );

      expect(result, 'Visual style: neon gaming. esports match');
    });

    test('ignores style when key is not in config', () {
      final rc = RemoteConfigService.withValues({});
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(
        userDescription: 'travel vlog',
        style: 'unknown_style',
      );

      expect(result, 'travel vlog');
    });

    test('ignores style when style is null', () {
      final rc = RemoteConfigService.withValues({
        'style_gaming': 'Visual style: neon gaming.',
      });
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(userDescription: 'cooking tutorial');

      expect(result, 'cooking tutorial');
    });
  });
}
