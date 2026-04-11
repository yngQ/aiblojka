import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

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
const double _kBreakpointNarrow = 360.0;
const double _kCardRadius = 16.0;
const double _kCardPadding = 16.0;
const double _kGlowBlurRadius = 20.0;
const double _kGlowSpreadRadius = 2.0;
const int _kMaxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
const double _kPillRadius = 50.0;
const double _kInputRadius = 28.0;
const double _kHeroOrbSize = 180.0;
const double _kResultGlowBlur = 55.0;
const double _kResultGlowSpread = 8.0;
const double _kGlowMinOpacity = 0.15;
const double _kGlowMaxOpacity = 0.55;
const int _kGlowPulseDurationMs = 1200;
const double _kBlobSize = 200.0;
const int _kMorphDurationMs = 2400;
const int _kRotateDurationMs = 8000;
const double _kHistoryRowHeight = 100.0;
const double _kHistoryThumbRadius = 8.0;
const double _kAspectLong = 16 / 9;
const double _kAspectShort = 9 / 16;
const double _kCloseButtonRadius = 20.0;
const double _kIconButtonRadius = 22.0;

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
    ref.read(generationNotifierProvider.notifier).generate(
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

  void _downloadImage(String imageBase64, String mimeType, String format) {
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
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(generationNotifierProvider);
    final isLoading = generationState.isLoading;
    final stateError = generationState.error;
    final isPermanentlyBlocked = stateError is WorkerNotConfiguredException ||
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
        Expanded(child: _HeroSection(isLoading: isLoading)),
        const SizedBox(height: 8),
        const _AppHeader(),
        const SizedBox(height: 12),
        _StyleSelector(
          selected: _selectedStyle,
          onChanged:
              isLoading ? null : (s) => setState(() => _selectedStyle = s),
        ),
        const SizedBox(height: 12),
        _PromptRow(
          controller: _promptController,
          isLoading: isLoading,
          isBlocked: isPermanentlyBlocked,
          onSend: isLoading ||
                  isPermanentlyBlocked ||
                  _promptController.text.trim().isEmpty
              ? null
              : _generate,
          referenceAttached: _referenceFileName != null,
          onAttach: isLoading || isPermanentlyBlocked
              ? null
              : _referenceFileName != null
                  ? _clearReferenceImage
                  : _pickReferenceImage,
        ),
        const SizedBox(height: 8),
        _FormatToggle(
          selected: _selectedFormat,
          onChanged:
              isLoading ? null : (f) => setState(() => _selectedFormat = f),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          _ErrorCard(error: error),
        ],
        _HistoryStrip(onDownload: _downloadImage),
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
                child: _CloseResultButton(
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
                onPressed: isLoading
                    ? null
                    : () => _downloadImage(
                          result.imageBase64,
                          result.mimeType,
                          _lastFormat.apiString,
                        ),
                icon: const Icon(Icons.download_outlined, size: 18),
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
        _HistoryStrip(onDownload: _downloadImage),
        const SizedBox(height: 16),
      ],
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
    final isNarrow = MediaQuery.sizeOf(context).width < _kBreakpointNarrow;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.accent,
            fontSize: isNarrow ? 22 : 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.appSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _HeroSection — loading-aware (orb idle ↔ morphing blob loading)
// ---------------------------------------------------------------------------

class _HeroSection extends StatefulWidget {
  const _HeroSection({required this.isLoading});

  final bool isLoading;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with TickerProviderStateMixin {
  // Idle: breathing orb
  late final AnimationController _breathController;
  late final Animation<double> _breathScale;

  // Loading: morphing blob
  late final AnimationController _morphController;
  late final AnimationController _rotateController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _breathScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kMorphDurationMs),
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kRotateDurationMs),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kGlowPulseDurationMs),
    );

    _syncAnimations();
  }

  @override
  void didUpdateWidget(_HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    if (widget.isLoading) {
      _breathController.stop();
      _morphController.repeat(reverse: true);
      _rotateController.repeat();
      _glowController.repeat(reverse: true);
    } else {
      _morphController.stop();
      _rotateController.stop();
      _glowController.stop();
      _breathController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _morphController.dispose();
    _rotateController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = constraints.maxHeight;
        final orbSize = min(_kHeroOrbSize * 1.4, availableSize * 0.65);
        final blobSize = min(_kBlobSize * 1.2, availableSize * 0.65);

        return Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: widget.isLoading
                ? _buildBlob(blobSize, l10n)
                : _buildOrb(orbSize),
          ),
        );
      },
    );
  }

  Widget _buildOrb(double size) {
    return AnimatedBuilder(
      key: const ValueKey('orb'),
      animation: _breathScale,
      builder: (context, child) =>
          Transform.scale(scale: _breathScale.value, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.55),
              AppColors.primary.withValues(alpha: 0.35),
              AppColors.background.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 60.0,
              spreadRadius: 10.0,
            ),
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.2),
              blurRadius: 100.0,
              spreadRadius: 0.0,
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome,
          size: size * 0.31,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBlob(double size, AppLocalizations l10n) {
    return Column(
      key: const ValueKey('blob'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge(
            [_morphController, _rotateController, _glowController],
          ),
          builder: (context, _) {
            final t = _morphController.value;
            final glow = _kGlowMinOpacity +
                (_kGlowMaxOpacity - _kGlowMinOpacity) * _glowController.value;

            final r1 = 40.0 + 50.0 * (0.5 + 0.5 * sin(t * pi));
            final r2 = 40.0 + 50.0 * (0.5 + 0.5 * cos(t * pi + 0.8));
            final r3 = 40.0 + 50.0 * (0.5 + 0.5 * sin(t * pi + 1.6));
            final r4 = 40.0 + 50.0 * (0.5 + 0.5 * cos(t * pi + 2.4));

            return Transform.rotate(
              angle: _rotateController.value * 2 * pi * 0.15,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.8),
                      AppColors.accent.withValues(alpha: 0.5),
                      AppColors.background.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r1 / 100 * size),
                    topRight: Radius.circular(r2 / 100 * size),
                    bottomLeft: Radius.circular(r3 / 100 * size),
                    bottomRight: Radius.circular(r4 / 100 * size),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: glow),
                      blurRadius: 60.0,
                      spreadRadius: 20.0,
                    ),
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: glow * 0.5),
                      blurRadius: 100.0,
                      spreadRadius: 5.0,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          l10n.generatingIndicatorLabel,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _FormatToggle + _FormatPill
// ---------------------------------------------------------------------------

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({required this.selected, required this.onChanged});

  final GenerationFormat selected;
  final ValueChanged<GenerationFormat>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FormatPill(
          label: l10n.formatLong,
          isSelected: selected == GenerationFormat.long,
          onTap: onChanged == null
              ? null
              : () => onChanged!(GenerationFormat.long),
        ),
        const SizedBox(width: 8),
        _FormatPill(
          label: l10n.formatShort,
          isSelected: selected == GenerationFormat.short,
          onTap: onChanged == null
              ? null
              : () => onChanged!(GenerationFormat.short),
        ),
      ],
    );
  }
}

class _FormatPill extends StatefulWidget {
  const _FormatPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<_FormatPill> createState() => _FormatPillState();
}

class _FormatPillState extends State<_FormatPill> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(_FormatPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onTap != null && widget.onTap == null) {
      setState(() => _isHovered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(_kPillRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : _isHovered && widget.onTap != null
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(_kPillRadius),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.primary
                    : _isHovered && widget.onTap != null
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.disabled,
                width: widget.isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: widget.isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
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
  const _StyleSelector({required this.selected, required this.onChanged});

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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: styles.asMap().entries.map((e) {
          final index = e.key;
          final entry = e.value;
          return Padding(
            padding: EdgeInsets.only(
              right: index < styles.length - 1 ? 8.0 : 0.0,
            ),
            child: _StyleChip(
              label: entry.$2,
              isSelected: selected == entry.$1,
              onTap: onChanged == null ? null : () => onChanged!(entry.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StyleChip extends StatefulWidget {
  const _StyleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<_StyleChip> createState() => _StyleChipState();
}

class _StyleChipState extends State<_StyleChip> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(_StyleChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onTap != null && widget.onTap == null) {
      setState(() => _isHovered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && widget.onTap != null ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(_kPillRadius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(_kPillRadius),
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.primary
                      : _isHovered && widget.onTap != null
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.disabled,
                  width: widget.isSelected ? 1.5 : 1,
                ),
                boxShadow: _isHovered && widget.onTap != null && !widget.isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? AppColors.background
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PromptRow — pill input with attachment icon + embedded send button
// ---------------------------------------------------------------------------

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.controller,
    required this.isLoading,
    required this.isBlocked,
    required this.onSend,
    required this.referenceAttached,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool isLoading;
  /// True when generation is permanently disabled (kill-switch / worker not configured).
  /// Combined with [isLoading] to derive text field editability.
  final bool isBlocked;
  final VoidCallback? onSend;
  final bool referenceAttached;
  final VoidCallback? onAttach;

  static const int _kMaxPromptLength = 2000;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTextFieldEnabled = !isLoading && !isBlocked;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, textValue, _) {
        final charCount = textValue.text.length;
        final isOverLimit = charCount >= _kMaxPromptLength;
        final canSend = onSend != null && !isOverLimit;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(_kInputRadius),
            border: Border.all(
              color: (isLoading || canSend)
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.disabled,
              width: 1.0,
            ),
            boxShadow: (isLoading || canSend)
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      blurRadius: _kGlowBlurRadius,
                      spreadRadius: _kGlowSpreadRadius,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Attachment button
                  _AttachButton(
                    referenceAttached: referenceAttached,
                    onAttach: onAttach,
                  ),
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: isTextFieldEnabled,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: _kMaxPromptLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.promptHint,
                        hintStyle: const TextStyle(
                          color: AppColors.disabled,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                  // Send button
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: _SendButton(
                      isLoading: isLoading,
                      isEnabled: canSend,
                      onSend: canSend ? onSend : null,
                    ),
                  ),
                ],
              ),
              // Character counter
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$charCount/$_kMaxPromptLength',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _AttachButton — attachment icon with hover scale, inside _PromptRow
// ---------------------------------------------------------------------------

class _AttachButton extends StatefulWidget {
  const _AttachButton({
    required this.referenceAttached,
    required this.onAttach,
  });

  final bool referenceAttached;
  final VoidCallback? onAttach;

  @override
  State<_AttachButton> createState() => _AttachButtonState();
}

class _AttachButtonState extends State<_AttachButton> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(_AttachButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onAttach != null && widget.onAttach == null) {
      setState(() => _isHovered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onAttach != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && widget.onAttach != null ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_kIconButtonRadius),
          child: InkWell(
            onTap: widget.onAttach,
            borderRadius: BorderRadius.circular(_kIconButtonRadius),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                widget.referenceAttached
                    ? Icons.attachment
                    : Icons.add_photo_alternate_outlined,
                color: widget.referenceAttached
                    ? AppColors.accent
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SendButton — circular send / loading indicator with hover
// ---------------------------------------------------------------------------

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.isLoading,
    required this.isEnabled,
    required this.onSend,
  });

  final bool isLoading;
  final bool isEnabled;
  final VoidCallback? onSend;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(_SendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = oldWidget.isLoading || oldWidget.isEnabled;
    final isActive = widget.isLoading || widget.isEnabled;
    if (wasActive && !isActive) {
      setState(() => _isHovered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isLoading || widget.isEnabled;
    return MouseRegion(
      cursor:
          active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && active ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.disabled,
            borderRadius: BorderRadius.circular(_kIconButtonRadius),
            boxShadow: _isHovered && active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_kIconButtonRadius),
            child: InkWell(
              onTap: widget.onSend,
              borderRadius: BorderRadius.circular(_kIconButtonRadius),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward,
                        color: AppColors.background,
                        size: 20,
                      ),
              ),
            ),
          ),
        ),
      ),
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
        NoImageGeneratedException() => l10n.errorNoImage,
        GenerationDisabledException() => l10n.errorGenerationDisabled,
        WorkerNotConfiguredException() => l10n.errorWorkerNotConfigured,
        ServerException() => l10n.errorServer,
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
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CloseResultButton — X button overlaid on result image top-right corner
// ---------------------------------------------------------------------------

class _CloseResultButton extends StatefulWidget {
  const _CloseResultButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloseResultButton> createState() => _CloseResultButtonState();
}

class _CloseResultButtonState extends State<_CloseResultButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_kCloseButtonRadius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(_kCloseButtonRadius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(_kCloseButtonRadius),
                border: Border.all(
                  color: _isHovered
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.disabled.withValues(alpha: 0.5),
                ),
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HistoryStrip — compact horizontal thumbnail row
// ---------------------------------------------------------------------------

class _HistoryStrip extends ConsumerWidget {
  const _HistoryStrip({required this.onDownload});

  final void Function(String imageBase64, String mimeType, String format)
      onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyNotifierProvider);
    if (entries.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              l10n.historySectionTitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            _ClearHistoryButton(
              onClear: () =>
                  ref.read(historyNotifierProvider.notifier).clear(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _kHistoryRowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isLong = entry.format == GenerationFormat.long.apiString;
              final thumbWidth = isLong
                  ? _kHistoryRowHeight * _kAspectLong
                  : _kHistoryRowHeight * _kAspectShort;

              final thumb = _HistoryThumb(
                imageBytes: entry.imageBytes,
                width: thumbWidth,
                onTap: () => onDownload(entry.imageBase64, entry.mimeType, entry.format),
              );

              return Padding(
                padding: EdgeInsets.only(
                  right: index < entries.length - 1 ? 8 : 0,
                ),
                child: entry.prompt.isEmpty
                    ? thumb
                    : Tooltip(
                        message: entry.prompt,
                        preferBelow: false,
                        child: thumb,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryThumb extends StatefulWidget {
  const _HistoryThumb({
    required this.imageBytes,
    required this.width,
    required this.onTap,
  });

  final Uint8List imageBytes;
  final double width;
  final VoidCallback onTap;

  @override
  State<_HistoryThumb> createState() => _HistoryThumbState();
}

class _HistoryThumbState extends State<_HistoryThumb> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kHistoryThumbRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(_kHistoryThumbRadius),
              child: SizedBox(
                width: widget.width,
                height: _kHistoryRowHeight,
                child: Image.memory(
                  widget.imageBytes,
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
        ),
      ),
    );
  }
}

class _ClearHistoryButton extends StatefulWidget {
  const _ClearHistoryButton({required this.onClear});

  final VoidCallback onClear;

  @override
  State<_ClearHistoryButton> createState() => _ClearHistoryButtonState();
}

class _ClearHistoryButtonState extends State<_ClearHistoryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: widget.onClear,
          borderRadius: BorderRadius.circular(4),
          child: AnimatedOpacity(
            opacity: _isHovered ? 1.0 : 0.6,
            duration: const Duration(milliseconds: 150),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
          ),
        ),
      ),
    );
  }
}
