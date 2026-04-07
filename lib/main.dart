import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/services_providers.dart';
import 'core/services/remote_config_service.dart';
import 'core/theme/app_theme.dart';
import 'features/generation/presentation/generate_page.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final remoteConfigService = RemoteConfigService();
  await remoteConfigService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        remoteConfigServiceProvider.overrideWithValue(remoteConfigService),
      ],
      child: const AiBlojkaApp(),
    ),
  );
}

class AiBlojkaApp extends StatelessWidget {
  const AiBlojkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AiBlojka',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: const GeneratePage(),
    );
  }
}
