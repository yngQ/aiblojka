import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/generation/presentation/generate_page.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: подключить google-services после настройки Firebase
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'placeholder',
        appId: 'placeholder',
        messagingSenderId: 'placeholder',
        projectId: 'placeholder',
      ),
    );
  } catch (_) {
    // Firebase недоступен в dev-режиме без реального конфига — продолжаем.
  }

  runApp(const ProviderScope(child: AiBlojkaApp()));
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
