import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const double _kPillRadius = 50.0;

// ---------------------------------------------------------------------------
// StyleSelector + StyleChip
// ---------------------------------------------------------------------------

class StyleSelector extends StatelessWidget {
  const StyleSelector({
    super.key,
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
            child: StyleChip(
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

class StyleChip extends StatefulWidget {
  const StyleChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<StyleChip> createState() => _StyleChipState();
}

class _StyleChipState extends State<StyleChip> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(StyleChip oldWidget) {
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
                boxShadow:
                    _isHovered && widget.onTap != null && !widget.isSelected
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
