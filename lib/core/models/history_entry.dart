import 'dart:convert';

/// A single entry in the generation history.
final class HistoryEntry {
  HistoryEntry({
    required this.imageBase64,
    required this.mimeType,
    required this.format,
    required this.prompt,
    required this.createdAt,
    this.style,
  });

  /// Raw base64-encoded image data (no data-URI prefix).
  final String imageBase64;

  /// MIME type of the image, e.g. `image/png`.
  final String mimeType;

  /// Cover format: `'long'` (YouTube 16:9) or `'short'` (Shorts/TikTok 9:16).
  final String format;

  /// Optional style tag, e.g. `'gaming'`. Null means no style was selected.
  final String? style;

  /// The user's original prompt text (not the full assembled Gemini prompt).
  final String prompt;

  /// Timestamp when this generation was completed.
  final DateTime createdAt;

  /// Decoded image bytes, computed and cached on first access.
  late final imageBytes = base64Decode(imageBase64);

  Map<String, dynamic> toJson() => {
        'imageBase64': imageBase64,
        'mimeType': mimeType,
        'format': format,
        'style': style,
        'prompt': prompt,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        imageBase64: json['imageBase64'] as String,
        mimeType: json['mimeType'] as String,
        format: json['format'] as String,
        style: json['style'] as String?,
        prompt: (json['prompt'] as String?) ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
