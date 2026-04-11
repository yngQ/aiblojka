import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

const _kBreakpointNarrow = 360.0;

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

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
