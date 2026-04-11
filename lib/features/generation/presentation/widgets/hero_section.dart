import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// HeroSection constants
// ---------------------------------------------------------------------------

const double _kHeroOrbSize = 180.0;
const double _kBlobSize = 200.0;
const int _kMorphDurationMs = 2400;
const int _kRotateDurationMs = 8000;
const int _kGlowPulseDurationMs = 1200;
const double _kGlowMinOpacity = 0.15;
const double _kGlowMaxOpacity = 0.55;

// ---------------------------------------------------------------------------
// HeroSection — loading-aware (orb idle ↔ morphing blob loading)
// ---------------------------------------------------------------------------

class HeroSection extends StatefulWidget {
  const HeroSection({super.key, required this.isLoading});

  final bool isLoading;

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection>
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
  void didUpdateWidget(HeroSection oldWidget) {
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
          animation: Listenable.merge([
            _morphController,
            _rotateController,
            _glowController,
          ]),
          builder: (context, _) {
            final t = _morphController.value;
            final glow =
                _kGlowMinOpacity +
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
