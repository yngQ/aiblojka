import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const double _kIconButtonRadius = 22.0;

/// Circular send/loading indicator button with hover glow effect.
class SendButton extends StatefulWidget {
  const SendButton({
    super.key,
    required this.isLoading,
    required this.isEnabled,
    required this.onSend,
  });

  final bool isLoading;
  final bool isEnabled;
  final VoidCallback? onSend;

  @override
  State<SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<SendButton> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(SendButton oldWidget) {
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
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
