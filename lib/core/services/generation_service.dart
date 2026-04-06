import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/generation_errors.dart';
import 'remote_config_service.dart';

const _kDefaultWorkerUrl = 'http://localhost:8787';
const _kWorkerUrlKey = 'cloudflare_worker_url';
const _kRequestTimeout = Duration(seconds: 60);

/// The result of a successful cover-generation call.
final class GenerationResult {
  GenerationResult({
    required this.imageBase64,
    required this.mimeType,
  });

  /// Raw base64-encoded image data (no data-URI prefix).
  final String imageBase64;

  /// MIME type of the image, e.g. `image/png`.
  final String mimeType;

  /// Decoded image bytes, computed and cached on first access.
  late final imageBytes = base64Decode(imageBase64);
}

/// Service responsible for sending generation requests to the Cloudflare Worker
/// proxy and mapping HTTP responses to typed [GenerationResult] or
/// [GenerationException] values.
class GenerationService {
  GenerationService({
    required this.remoteConfig,
    required this.httpClient,
  });

  final RemoteConfigService remoteConfig;
  final http.Client httpClient;

  /// Sends a cover-generation request to the Cloudflare Worker.
  ///
  /// Throws a [GenerationException] subclass on any failure:
  /// - [QuotaExceededException] on HTTP 429
  /// - [SafetyBlockException] on HTTP 451
  /// - [NoImageGeneratedException] on HTTP 422
  /// - [ServerException] on HTTP 5xx or 502
  /// - [NetworkException] on socket/timeout errors
  Future<GenerationResult> generateCover({
    required String prompt,
    required String format,
    String? style,
    String? referenceImageBase64,
    String? referenceMimeType,
  }) async {
    final workerUrl = remoteConfig.getString(
      _kWorkerUrlKey,
      defaultValue: _kDefaultWorkerUrl,
    );

    final bool hasReference =
        referenceImageBase64 != null && referenceImageBase64.isNotEmpty;

    if (hasReference && (referenceMimeType == null || referenceMimeType.isEmpty)) {
      throw ArgumentError.value(
        referenceMimeType,
        'referenceMimeType',
        'referenceMimeType is required when referenceImageBase64 is provided.',
      );
    }

    final body = <String, dynamic>{
      'prompt': prompt,
      'format': format,
      if (style != null && style.isNotEmpty) 'style': style,
    };
    if (hasReference) {
      body['referenceImageBase64'] = referenceImageBase64;
      body['referenceMimeType'] = referenceMimeType;
    }

    final http.Response response;
    try {
      response = await httpClient
          .post(
            Uri.parse(workerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_kRequestTimeout);
    } on TimeoutException {
      throw const NetworkException('Request timed out. Please try again.');
    } on http.ClientException {
      throw const NetworkException();
    }

    return _handleResponse(response);
  }

  GenerationResult _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode == 200) {
      return _parseSuccess(response.body);
    }

    if (statusCode == 429) {
      throw const QuotaExceededException();
    }

    if (statusCode == 451) {
      throw const SafetyBlockException();
    }

    if (statusCode == 422) {
      throw const NoImageGeneratedException();
    }

    // 502, 503 and any other 5xx.
    throw const ServerException();
  }

  GenerationResult _parseSuccess(String body) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const ServerException('Unexpected response format from the server.');
    }

    final imageBase64 = json['imageBase64'] is String ? json['imageBase64'] as String : null;
    final mimeType = json['mimeType'] is String ? json['mimeType'] as String : null;

    if (imageBase64 == null || imageBase64.isEmpty) {
      throw const NoImageGeneratedException();
    }
    if (mimeType == null || mimeType.isEmpty) {
      throw const ServerException('Response is missing mimeType field.');
    }

    return GenerationResult(imageBase64: imageBase64, mimeType: mimeType);
  }
}
