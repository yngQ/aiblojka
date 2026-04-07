import 'package:flutter_test/flutter_test.dart';

import 'package:aiblojka/core/services/prompt_builder.dart';
import 'package:aiblojka/core/services/remote_config_service.dart';

void main() {
  group('PromptBuilder', () {
    test('replaces {prompt} placeholder with user description', () {
      final rc = RemoteConfigService.withValues({
        'prompt_template_long': 'Make a cover. {prompt} High quality.',
      });
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(
        userDescription: 'a sunset over mountains',
        format: 'long',
      );

      expect(result, 'Make a cover. a sunset over mountains High quality.');
    });

    test('prepends style instruction before user description', () {
      final rc = RemoteConfigService.withValues({
        'prompt_template_long': 'Thumbnail. {prompt} No artifacts.',
        'style_gaming': 'Visual style: neon gaming.',
      });
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(
        userDescription: 'esports match',
        format: 'long',
        style: 'gaming',
      );

      expect(
        result,
        'Thumbnail. Visual style: neon gaming. esports match No artifacts.',
      );
    });

    test('uses short template for short format', () {
      final rc = RemoteConfigService.withValues({
        'prompt_template_short': 'Vertical cover. {prompt}',
      });
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(
        userDescription: 'dance video',
        format: 'short',
      );

      expect(result, 'Vertical cover. dance video');
    });

    test('falls back to raw description when template is empty', () {
      final rc = RemoteConfigService.withValues({
        'prompt_template_long': '',
      });
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(
        userDescription: 'mountain landscape',
        format: 'long',
      );

      expect(result, 'mountain landscape');
    });

    test('ignores style when style key is not in config at all', () {
      final rc = RemoteConfigService.withValues({
        'prompt_template_long': 'Cover. {prompt}',
        // 'style_unknown' does not exist in defaults either
      });
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(
        userDescription: 'travel vlog',
        format: 'long',
        style: 'unknown_style',
      );

      expect(result, 'Cover. travel vlog');
    });

    test('no style: uses default template without prefix', () {
      final rc = RemoteConfigService.withDefaults();
      final builder = PromptBuilder(remoteConfig: rc);

      final result = builder.build(
        userDescription: 'cooking tutorial',
        format: 'long',
      );

      expect(result, contains('cooking tutorial'));
      expect(result, isNot(contains('{prompt}')));
    });
  });
}
