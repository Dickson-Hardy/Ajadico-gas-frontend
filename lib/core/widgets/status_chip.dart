import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ChipType { ok, warn, bad, bank, draft }

class StatusChip extends StatelessWidget {
  final String label;
  final ChipType type;

  const StatusChip({
    super.key,
    required this.label,
    this.type = ChipType.draft,
  });

  Color _getBackgroundColor() {
    switch (type) {
      case ChipType.ok:
        return AppColors.ok;
      case ChipType.warn:
        return AppColors.warn;
      case ChipType.bad:
        return AppColors.bad;
      case ChipType.bank:
        return AppColors.bank;
      case ChipType.draft:
        return AppColors.draft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = dark
        ? switch (type) {
            ChipType.ok => const Color(0xFF7EDBBC),
            ChipType.warn => const Color(0xFFF3C77A),
            ChipType.bad => const Color(0xFFF5A29B),
            ChipType.bank => const Color(0xFF93C5FD),
            ChipType.draft => const Color(0xFFB4C3BE),
          }
        : _getBackgroundColor();
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: dark ? 0.13 : 0.08),
          border: Border.all(color: tone.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tone,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
