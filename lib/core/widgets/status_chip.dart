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
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
