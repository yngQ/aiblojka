import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const double _kIconButtonRadius = 22.0;

/// Attachment icon button with hover scale animation.
class AttachButton extends StatefulWidget {
  const AttachButton({
    super.key,
    required this.referenceAttached,
    required this.onAttach,
  });

  final bool referenceAttached;
  final VoidCallback? onAttach;

  @override
  State<AttachButton> createState() => _AttachButtonState();
}

class _AttachButtonState extends State<AttachButton> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(AttachButton oldWidget) {
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
