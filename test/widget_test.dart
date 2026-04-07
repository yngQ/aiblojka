@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:aiblojka/core/providers/services_providers.dart';
import 'package:aiblojka/core/services/analytics_service.dart';
import 'package:aiblojka/core/services/remote_config_service.dart';
import 'package:aiblojka/core/theme/app_theme.dart';
import 'package:aiblojka/features/generation/presentation/generate_page.dart';
import 'package:aiblojka/l10n/app_localizations.dart';

void main() {
  setUp(() => web.window.localStorage.removeItem('aiblojka_history'));

  testWidgets('GeneratePage shows app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteConfigServiceProvider
              .overrideWithValue(RemoteConfigService.withDefaults()),
          analyticsServiceProvider
              .overrideWithValue(AnalyticsService.stub()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GeneratePage(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('AiBlojka'), findsOneWidget);
  });
}
