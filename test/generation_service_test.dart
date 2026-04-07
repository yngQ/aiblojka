import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aiblojka/core/errors/generation_errors.dart';
import 'package:aiblojka/core/services/generation_service.dart';
import 'package:aiblojka/core/services/remote_config_service.dart';

http.Client _clientReturning(int statusCode, Map<String, dynamic> body) =>
    MockClient((_) async => http.Response(jsonEncode(body), statusCode));

http.Client _clientReturningRaw(int statusCode, String body) =>
    MockClient((_) async => http.Response(body, statusCode));

RemoteConfigService _rcWithWorkerUrl([String url = 'https://worker.example.com']) =>
    RemoteConfigService.withValues({'cloudflare_worker_url': url});

void main() {
  group('GenerationService', () {
    test('returns GenerationResult on HTTP 200 with valid body', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: _clientReturning(200, {
          'imageBase64': 'aGVsbG8=',
          'mimeType': 'image/png',
        }),
      );

      final result = await service.generateCover(
        prompt: 'sunset',
        format: 'long',
      );

      expect(result.imageBase64, 'aGVsbG8=');
      expect(result.mimeType, 'image/png');
    });

    test('throws WorkerNotConfiguredException when URL is empty', () async {
      final service = GenerationService(
        remoteConfig: RemoteConfigService.withValues({'cloudflare_worker_url': ''}),
        httpClient: MockClient((_) async => throw StateError('should not be called')),
      );

      expect(
        () => service.generateCover(prompt: 'test', format: 'long'),
        throwsA(isA<WorkerNotConfiguredException>()),
      );
    });

    test('throws QuotaExceededException on HTTP 429', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: _clientReturningRaw(429, ''),
      );

      expect(
        () => service.generateCover(prompt: 'test', format: 'long'),
        throwsA(isA<QuotaExceededException>()),
      );
    });

    test('throws SafetyBlockException on HTTP 451', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: _clientReturningRaw(451, ''),
      );

      expect(
        () => service.generateCover(prompt: 'test', format: 'long'),
        throwsA(isA<SafetyBlockException>()),
      );
    });

    test('throws NoImageGeneratedException on HTTP 422', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: _clientReturningRaw(422, ''),
      );

      expect(
        () => service.generateCover(prompt: 'test', format: 'long'),
        throwsA(isA<NoImageGeneratedException>()),
      );
    });

    test('throws ServerException on HTTP 500', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: _clientReturningRaw(500, ''),
      );

      expect(
        () => service.generateCover(prompt: 'test', format: 'long'),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on malformed JSON response', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: _clientReturningRaw(200, 'not json {{'),
      );

      expect(
        () => service.generateCover(prompt: 'test', format: 'long'),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NoImageGeneratedException when imageBase64 is missing', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: _clientReturning(200, {'mimeType': 'image/png'}),
      );

      expect(
        () => service.generateCover(prompt: 'test', format: 'long'),
        throwsA(isA<NoImageGeneratedException>()),
      );
    });

    test('throws ServerException when mimeType is missing', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: _clientReturning(200, {'imageBase64': 'aGVsbG8='}),
      );

      expect(
        () => service.generateCover(prompt: 'test', format: 'long'),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ArgumentError when reference provided without mimeType', () async {
      final service = GenerationService(
        remoteConfig: _rcWithWorkerUrl(),
        httpClient: MockClient((_) async => throw StateError('should not be called')),
      );

      expect(
        () => service.generateCover(
          prompt: 'test',
          format: 'long',
          referenceImageBase64: 'aGVsbG8=',
          referenceMimeType: null,
        ),
        throwsArgumentError,
      );
    });
  });
}
