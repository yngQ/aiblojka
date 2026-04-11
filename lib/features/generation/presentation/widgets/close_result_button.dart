import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const _kCloseButtonRadius = 20.0;

class CloseResultButton extends StatefulWidget {
  const CloseResultButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<CloseResultButton> createState() => _CloseResultButtonState();
}

class _CloseResultButtonState extends State<CloseResultButton> {
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
