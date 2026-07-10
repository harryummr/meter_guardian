import 'package:flutter/material.dart';
import '../services/calculation_service.dart';
import '../utils/theme.dart';

class StatusBadge extends StatelessWidget {
  final SlabStatus status;
  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case SlabStatus.safe:
        return AppColors.safe;
      case SlabStatus.warning:
        return AppColors.warning;
      case SlabStatus.danger:
        return AppColors.danger;
    }
  }

  String get _label {
    switch (status) {
      case SlabStatus.safe:
        return 'Safe';
      case SlabStatus.warning:
        return 'Warning';
      case SlabStatus.danger:
        return 'Danger';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(_label, style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
