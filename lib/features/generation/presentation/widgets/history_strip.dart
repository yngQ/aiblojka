import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/generation_provider.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const double _kHistoryRowHeight = 100.0;
const double _kHistoryThumbRadius = 8.0;
const double _kAspectLong = 16 / 9;
const double _kAspectShort = 9 / 16;

// ---------------------------------------------------------------------------
// HistoryStrip — horizontal thumbnail strip
// ---------------------------------------------------------------------------

class HistoryStrip extends ConsumerWidget {
  const HistoryStrip({super.key, required this.onDownload});

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
            ClearHistoryButton(
              onClear: () => ref.read(historyNotifierProvider.notifier).clear(),
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

              final thumb = HistoryThumb(
                imageBytes: entry.imageBytes,
                width: thumbWidth,
                onTap: () =>
                    onDownload(entry.imageBase64, entry.mimeType, entry.format),
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

// ---------------------------------------------------------------------------
// HistoryThumb — single thumbnail with hover scale
// ---------------------------------------------------------------------------

class HistoryThumb extends StatefulWidget {
  const HistoryThumb({
    super.key,
    required this.imageBytes,
    required this.width,
    required this.onTap,
  });

  final Uint8List imageBytes;
  final double width;
  final VoidCallback onTap;

  @override
  State<HistoryThumb> createState() => _HistoryThumbState();
}

class _HistoryThumbState extends State<HistoryThumb> {
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

// ---------------------------------------------------------------------------
// ClearHistoryButton — clear history text button
// ---------------------------------------------------------------------------

class ClearHistoryButton extends StatefulWidget {
  const ClearHistoryButton({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  State<ClearHistoryButton> createState() => _ClearHistoryButtonState();
}

class _ClearHistoryButtonState extends State<ClearHistoryButton> {
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
