@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aiblojka/features/generation/presentation/generate_page.dart';
import 'package:aiblojka/core/theme/app_theme.dart';

void main() {
  testWidgets('GeneratePage renders AiBlojka title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const GeneratePage(),
        ),
      ),
    );

    expect(find.text('AiBlojka'), findsOneWidget);
  });
}
