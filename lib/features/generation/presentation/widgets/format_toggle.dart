import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/generation_provider.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const double _kPillRadius = 50.0;

// ---------------------------------------------------------------------------
// FormatToggle + FormatPill
// ---------------------------------------------------------------------------

class FormatToggle extends StatelessWidget {
  const FormatToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final GenerationFormat selected;
  final ValueChanged<GenerationFormat>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FormatPill(
          label: l10n.formatLong,
          isSelected: selected == GenerationFormat.long,
          onTap: onChanged == null
              ? null
              : () => onChanged!(GenerationFormat.long),
        ),
        const SizedBox(width: 8),
        FormatPill(
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

class FormatPill extends StatefulWidget {
  const FormatPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<FormatPill> createState() => FormatPillState();
}

class FormatPillState extends State<FormatPill> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(FormatPill oldWidget) {
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
