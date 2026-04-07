import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/analytics_service.dart';
import '../services/generation_service.dart';
import '../services/prompt_builder.dart';
import '../services/remote_config_service.dart';

part 'services_providers.g.dart';

/// Shared [http.Client] instance. Kept alive for the app lifetime so it is
/// never closed while an in-flight generation request holds a reference to it.
@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}

/// Singleton [RemoteConfigService]. Overridden in [main] with an
/// already-initialised instance so Remote Config is ready before the first
/// frame is drawn.
@Riverpod(keepAlive: true)
RemoteConfigService remoteConfigService(Ref ref) => RemoteConfigService();

/// [PromptBuilder] wired with [RemoteConfigService].
@Riverpod(keepAlive: true)
PromptBuilder promptBuilder(Ref ref) =>
    PromptBuilder(remoteConfig: ref.watch(remoteConfigServiceProvider));

/// [AnalyticsService] singleton.
@Riverpod(keepAlive: true)
AnalyticsService analyticsService(Ref ref) => AnalyticsService();

/// [GenerationService] wired up with its dependencies.
@Riverpod(keepAlive: true)
GenerationService generationService(Ref ref) => GenerationService(
      remoteConfig: ref.watch(remoteConfigServiceProvider),
      httpClient: ref.watch(httpClientProvider),
    );
