import 'package:flutter/material.dart';

import '../../../../core/errors/generation_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

const _kCardPadding = 16.0;
const _kCardRadius = 16.0;

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.error});

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
