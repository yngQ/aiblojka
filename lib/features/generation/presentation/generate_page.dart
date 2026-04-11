import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/errors/generation_errors.dart';
import '../../../core/providers/services_providers.dart';
import '../../../core/services/generation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/generation_provider.dart';
import 'widgets/app_header.dart';
import 'widgets/close_result_button.dart';
import 'widgets/error_card.dart';
import 'widgets/format_toggle.dart';
import 'widgets/hero_section.dart';
import 'widgets/history_strip.dart';
import 'widgets/prompt_row.dart';
import 'widgets/style_selector.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const double _kContentMaxWidth = 600.0;
const double _kCardRadius = 16.0;
const int _kMaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
const double _kResultGlowBlur = 55.0;
const double _kResultGlowSpread = 8.0;

// ---------------------------------------------------------------------------
// GeneratePage — root screen
// ---------------------------------------------------------------------------

class GeneratePage extends ConsumerStatefulWidget {
  const GeneratePage({super.key});

  @override
  ConsumerState<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends ConsumerState<GeneratePage> {
  final _promptController = TextEditingController();

  GenerationFormat _selectedFormat = GenerationFormat.long;
  String? _selectedStyle;

  // Reference image state
  String? _referenceBase64;
  String? _referenceMimeType;
  String? _referenceFileName;

  // Last generation params for regeneration
  String _lastPrompt = '';
  GenerationFormat _lastFormat = GenerationFormat.long;
  String? _lastStyle;
  String? _lastReferenceBase64;
  String? _lastReferenceMimeType;
  String? _lastReferenceFileName;

  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickReferenceImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorFileSize),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (bytes.length > _kMaxFileSizeBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorFileSize),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ext = (file.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };

    if (mime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorFileSize),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _referenceBase64 = base64Encode(bytes);
      _referenceMimeType = mime;
      _referenceFileName = file.name;
    });
    unawaited(ref.read(analyticsServiceProvider).logReferenceImageUploaded());
  }

  void _clearReferenceImage() {
    setState(() {
      _referenceBase64 = null;
      _referenceMimeType = null;
      _referenceFileName = null;
    });
  }

  void _dispatch({
    required String prompt,
    required GenerationFormat format,
    String? style,
    String? referenceBase64,
    String? referenceMimeType,
  }) {
    ref
        .read(generationNotifierProvider.notifier)
        .generate(
          prompt: prompt,
          format: format,
          style: style,
          referenceImageBase64: referenceBase64,
          referenceMimeType: referenceMimeType,
        );
  }

  void _generate() {
    if (_promptController.text.trim().isEmpty) return;
    // Save for potential regeneration
    _lastPrompt = _promptController.text.trim();
    _lastFormat = _selectedFormat;
    _lastStyle = _selectedStyle;
    _lastReferenceBase64 = _referenceBase64;
    _lastReferenceMimeType = _referenceMimeType;
    _lastReferenceFileName = _referenceFileName;

    _dispatch(
      prompt: _lastPrompt,
      format: _lastFormat,
      style: _lastStyle,
      referenceBase64: _lastReferenceBase64,
      referenceMimeType: _lastReferenceMimeType,
    );
  }

  void _regenerate() {
    if (_lastPrompt.isEmpty) return;
    _promptController.text = _lastPrompt;
    setState(() {
      _selectedFormat = _lastFormat;
      _selectedStyle = _lastStyle;
      _referenceBase64 = _lastReferenceBase64;
      _referenceMimeType = _lastReferenceMimeType;
      _referenceFileName = _lastReferenceFileName;
    });
    _dispatch(
      prompt: _lastPrompt,
      format: _lastFormat,
      style: _lastStyle,
      referenceBase64: _lastReferenceBase64,
      referenceMimeType: _lastReferenceMimeType,
    );
  }

  Future<void> _downloadImage(String imageBase64, String mimeType, String format) async {
    setState(() => _isDownloading = true);
    try {
      final ext = switch (mimeType) {
        'image/jpeg' => 'jpg',
        'image/webp' => 'webp',
        _ => 'png',
      };
      final dataUri = 'data:$mimeType;base64,$imageBase64';
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = dataUri;
      anchor.download = 'cover.$ext';
      anchor.click();

      unawaited(
        ref.read(analyticsServiceProvider).logImageDownloaded(format: format),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(generationNotifierProvider);
    final isLoading = generationState.isLoading;
    final stateError = generationState.error;
    final isPermanentlyBlocked =
        stateError is WorkerNotConfiguredException ||
        stateError is GenerationDisabledException;
    final hasPreviousResult = generationState.valueOrNull != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = min(constraints.maxWidth, _kContentMaxWidth);
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: hasPreviousResult
                        ? _buildResultView(
                            generationState.value!,
                            isLoading: isLoading,
                          )
                        : _buildGenerateView(
                            isLoading,
                            stateError,
                            isPermanentlyBlocked,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGenerateView(
    bool isLoading,
    Object? error,
    bool isPermanentlyBlocked,
  ) {
    return Column(
      key: const ValueKey('generate'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Expanded(child: HeroSection(isLoading: isLoading)),
        const SizedBox(height: 8),
        const AppHeader(),
        const SizedBox(height: 12),
        StyleSelector(
          selected: _selectedStyle,
          onChanged: isLoading
              ? null
              : (s) => setState(() => _selectedStyle = s),
        ),
        const SizedBox(height: 12),
        PromptRow(
          controller: _promptController,
          isLoading: isLoading,
          isBlocked: isPermanentlyBlocked,
          onSend: isLoading || isPermanentlyBlocked ? null : _generate,
          referenceAttached: _referenceFileName != null,
          onAttach: isLoading || isPermanentlyBlocked
              ? null
              : _referenceFileName != null
              ? _clearReferenceImage
              : _pickReferenceImage,
        ),
        const SizedBox(height: 8),
        FormatToggle(
          selected: _selectedFormat,
          onChanged: isLoading
              ? null
              : (f) => setState(() => _selectedFormat = f),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          ErrorCard(error: error),
        ],
        HistoryStrip(onDownload: _downloadImage),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResultView(GenerationResult result, {required bool isLoading}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const ValueKey('result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: Stack(
            children: [
              // Image with optional loading overlay
              Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14, right: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(_kCardRadius),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.55),
                              blurRadius: _kResultGlowBlur,
                              spreadRadius: _kResultGlowSpread,
                            ),
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.25),
                              blurRadius: _kResultGlowBlur + 25,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_kCardRadius),
                          child: Image.memory(
                            result.imageBytes,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Loading overlay during regeneration
                  if (isLoading) ...[
                    Positioned.fill(
                      child: Container(
                        color: AppColors.background.withValues(alpha: 0.7),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.generatingIndicatorLabel,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: CloseResultButton(
                  onTap: () =>
                      ref.read(generationNotifierProvider.notifier).reset(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading || _isDownloading
                    ? null
                    : () => _downloadImage(
                        result.imageBase64,
                        result.mimeType,
                        _lastFormat.apiString,
                      ),
                icon: _isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.downloadButton),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : _regenerate,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.regenerateButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        HistoryStrip(onDownload: _downloadImage),
        const SizedBox(height: 16),
      ],
    );
  }
}
