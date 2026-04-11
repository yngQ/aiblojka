import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'attach_button.dart';
import 'send_button.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const double _kInputRadius = 28.0;
const double _kGlowBlurRadius = 20.0;
const double _kGlowSpreadRadius = 2.0;
const int _kMaxPromptLength = 2000;

// ---------------------------------------------------------------------------
// PromptRow — pill input with attachment icon + embedded send button
// ---------------------------------------------------------------------------

class PromptRow extends StatelessWidget {
  const PromptRow({
    super.key,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTextFieldEnabled = !isLoading && !isBlocked;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, textValue, _) {
        final charCount = textValue.text.length;
        final isOverLimit = charCount >= _kMaxPromptLength;
        final hasText = textValue.text.trim().isNotEmpty;
        final canSend = onSend != null && hasText && !isOverLimit;

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
                  AttachButton(
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
                    child: SendButton(
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
