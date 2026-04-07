import 'dart:async';
import 'dart:convert';

import 'package:web/web.dart' as web;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/generation_errors.dart';
import '../../../core/providers/services_providers.dart';
import '../../../core/services/generation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/generation_provider.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const double _kContentMaxWidth = 600.0;
const double _kBreakpointWide = 720.0;
const double _kCardRadius = 16.0;
const double _kCardPadding = 16.0;
const double _kSectionSpacing = 16.0;
const double _kGlowBlurRadius = 20.0;
const double _kGlowSpreadRadius = 2.0;
const int _kMaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
const int _kPromptMinLines = 3;

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
  String? _selectedStyle; // null means "no style"

  // Reference image state
  String? _referenceBase64;
  String? _referenceMimeType;
  String? _referenceFileName;
  bool _referenceError = false;

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
  }

  void _onPromptChanged() => setState(() {});

  @override
  void dispose() {
    _promptController.removeListener(_onPromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickReferenceImage() async {
    setState(() => _referenceError = false);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null || bytes.length > _kMaxFileSizeBytes) {
      setState(() => _referenceError = true);
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
      setState(() => _referenceError = true);
      return;
    }

    setState(() {
      _referenceBase64 = base64Encode(bytes);
      _referenceMimeType = mime;
      _referenceFileName = file.name;
      _referenceError = false;
    });
  }

  void _clearReferenceImage() {
    setState(() {
      _referenceBase64 = null;
      _referenceMimeType = null;
      _referenceFileName = null;
      _referenceError = false;
    });
  }

  void _generate() {
    if (_promptController.text.trim().isEmpty) return;
    ref.read(generationNotifierProvider.notifier).generate(
          prompt: _promptController.text.trim(),
          format: _selectedFormat,
          style: _selectedStyle,
          referenceImageBase64: _referenceBase64,
          referenceMimeType: _referenceMimeType,
        );
  }

  void _reset() {
    ref.read(generationNotifierProvider.notifier).reset();
  }

  void _downloadImage(String imageBase64, String mimeType) {
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
      ref.read(analyticsServiceProvider).logImageDownloaded(
            format: _selectedFormat.apiString,
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(generationNotifierProvider);
    final isLoading = generationState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _kBreakpointWide;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 0 : 16,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _AppHeader(),
                        const SizedBox(height: 24),
                        _FormatSelector(
                          selected: _selectedFormat,
                          onChanged: isLoading
                              ? null
                              : (f) => setState(() => _selectedFormat = f),
                        ),
                        const SizedBox(height: _kSectionSpacing),
                        _StyleSelector(
                          selected: _selectedStyle,
                          onChanged: isLoading
                              ? null
                              : (s) => setState(() => _selectedStyle = s),
                        ),
                        const SizedBox(height: _kSectionSpacing),
                        _PromptField(
                          controller: _promptController,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: _kSectionSpacing),
                        _ReferenceImagePicker(
                          fileName: _referenceFileName,
                          hasError: _referenceError,
                          enabled: !isLoading,
                          onPick: _pickReferenceImage,
                          onClear: _clearReferenceImage,
                        ),
                        const SizedBox(height: 24),
                        _GenerateButton(
                          isLoading: isLoading,
                          onPressed: isLoading ||
                                  _promptController.text.trim().isEmpty
                              ? null
                              : _generate,
                        ),
                        const SizedBox(height: 24),
                        if (isLoading) const _GeneratingIndicator(),
                        generationState.when(
                          data: (result) {
                            if (result == null) return const SizedBox.shrink();
                            return _ResultSection(
                              result: result,
                              onDownload: () => _downloadImage(
                                result.imageBase64,
                                result.mimeType,
                              ),
                              onRegenerate: _reset,
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (e, _) => _ErrorCard(error: e),
                        ),
                        _HistorySection(onDownload: _downloadImage),
                        const SizedBox(height: 24),
                      ],
                    ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AppHeader
// ---------------------------------------------------------------------------

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.appTitle,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FormatSelector
// ---------------------------------------------------------------------------

class _FormatSelector extends StatelessWidget {
  const _FormatSelector({
    required this.selected,
    required this.onChanged,
  });

  final GenerationFormat selected;
  final ValueChanged<GenerationFormat>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      child: Row(
        children: [
          _FormatOption(
            selected: selected == GenerationFormat.long,
            title: l10n.formatLong,
            subtitle: l10n.formatLongSubtitle,
            onTap: onChanged == null
                ? null
                : () => onChanged!(GenerationFormat.long),
          ),
          const SizedBox(width: 12),
          _FormatOption(
            selected: selected == GenerationFormat.short,
            title: l10n.formatShort,
            subtitle: l10n.formatShortSubtitle,
            onTap: onChanged == null
                ? null
                : () => onChanged!(GenerationFormat.short),
          ),
        ],
      ),
    );
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.disabled;
    final titleColor =
        selected ? AppColors.textPrimary : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StyleSelector
// ---------------------------------------------------------------------------

class _StyleSelector extends StatelessWidget {
  const _StyleSelector({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final styles = <(String?, String)>[
      (null, l10n.noStyleOption),
      ('gaming', l10n.styleGaming),
      ('vlog', l10n.styleVlog),
      ('education', l10n.styleEducation),
      ('business', l10n.styleBusiness),
      ('entertainment', l10n.styleEntertainment),
    ];

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.styleLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: styles
                .map(
                  (entry) => _StyleChip(
                    label: entry.$2,
                    isSelected: selected == entry.$1,
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(entry.$1),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.disabled,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.background : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PromptField
// ---------------------------------------------------------------------------

class _PromptField extends StatelessWidget {
  const _PromptField({
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        minLines: _kPromptMinLines,
        maxLines: null,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: l10n.promptLabel,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintText: l10n.promptHint,
          hintStyle: const TextStyle(color: AppColors.disabled, fontSize: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ReferenceImagePicker
// ---------------------------------------------------------------------------

class _ReferenceImagePicker extends StatelessWidget {
  const _ReferenceImagePicker({
    required this.fileName,
    required this.hasError,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String? fileName;
  final bool hasError;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.referenceLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          if (fileName != null)
            Row(
              children: [
                const Icon(Icons.image_outlined,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 18),
                  onPressed: enabled ? onClear : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: enabled ? onPick : null,
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: Text(l10n.referenceButton),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.disabled),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          if (hasError) ...[
            const SizedBox(height: 8),
            Text(
              l10n.errorFileSize,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GenerateButton
// ---------------------------------------------------------------------------

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = onPressed != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: _kGlowBlurRadius,
                  spreadRadius: _kGlowSpreadRadius,
                ),
              ]
            : [],
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled ? AppColors.primary : AppColors.disabled,
            foregroundColor: isEnabled ? AppColors.background : AppColors.textSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            isLoading ? l10n.generatingLabel : l10n.generateButton,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GeneratingIndicator
// ---------------------------------------------------------------------------

const double _kGlowMinOpacity = 0.15;
const double _kGlowMaxOpacity = 0.55;
const int _kGlowPulseDurationMs = 1200;
const double _kGlowIndicatorBlur = 24.0;
const double _kGlowIndicatorSpread = 4.0;

class _GeneratingIndicator extends StatefulWidget {
  const _GeneratingIndicator();

  @override
  State<_GeneratingIndicator> createState() => _GeneratingIndicatorState();
}

class _GeneratingIndicatorState extends State<_GeneratingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kGlowPulseDurationMs),
    )..repeat(reverse: true);

    _glowOpacity = Tween<double>(
      begin: _kGlowMinOpacity,
      end: _kGlowMaxOpacity,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _glowOpacity,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(_kCardRadius),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: _glowOpacity.value),
                blurRadius: _kGlowIndicatorBlur,
                spreadRadius: _kGlowIndicatorSpread,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Center(
        child: Text(
          l10n.generatingIndicatorLabel,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ResultSection
// ---------------------------------------------------------------------------

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.result,
    required this.onDownload,
    required this.onRegenerate,
  });

  final GenerationResult result;
  final VoidCallback onDownload;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Image.memory(
            result.imageBytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.downloadButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
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
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.regenerateButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorCard
// ---------------------------------------------------------------------------

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final Object error;

  String _errorMessage(AppLocalizations l10n) => switch (error) {
        QuotaExceededException() => l10n.errorLimitExceeded,
        SafetyBlockException() => l10n.errorSafetyBlock,
        NetworkException() => l10n.errorNetwork,
        GenerationDisabledException() => l10n.errorGenerationDisabled,
        WorkerNotConfiguredException() => l10n.errorWorkerNotConfigured,
        ServerException() || NoImageGeneratedException() => l10n.errorServer,
        _ => l10n.errorServer,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(_kCardPadding),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage(l10n),
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HistorySection
// ---------------------------------------------------------------------------

const double _kHistoryRowHeight = 100.0;
const double _kHistoryThumbRadiuus = 8.0;
// Aspect ratios for cover formats
const double _kAspectLong = 16 / 9; // → thumb width ≈ 177 at 100 h (capped)
const double _kAspectShort = 9 / 16; // → thumb width ≈ 56 at 100 h

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.onDownload});

  final void Function(String imageBase64, String mimeType) onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyNotifierProvider);
    if (entries.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _kSectionSpacing),
        Row(
          children: [
            Text(
              l10n.historySectionTitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  ref.read(historyNotifierProvider.notifier).clear(),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.historyClearButton,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _kHistoryRowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isLong = entry.format == 'long';
              final thumbWidth = isLong
                  ? _kHistoryRowHeight * _kAspectLong
                  : _kHistoryRowHeight * _kAspectShort;
              return Padding(
                padding: EdgeInsets.only(right: index < entries.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => onDownload(entry.imageBase64, entry.mimeType),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_kHistoryThumbRadiuus),
                    child: SizedBox(
                      width: thumbWidth,
                      height: _kHistoryRowHeight,
                      child: Image.memory(
                        entry.imageBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.surface,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.disabled,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionCard — shared card container
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_kCardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_kCardRadius),
      ),
      child: child,
    );
  }
}
