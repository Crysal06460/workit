import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Filtre horizontal scrollable en pills
///
/// Usage :
/// ```dart
/// WiFilterPills(
///   pills: ['Tous', 'En attente', 'En pose', 'Terminés'],
///   selected: _selectedFilter,
///   onSelected: (v) => setState(() => _selectedFilter = v),
///   activeColor: AppColors.primary,
/// )
/// ```
class WiFilterPills extends StatelessWidget {
  final List<String> pills;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color activeColor;

  const WiFilterPills({
    super.key,
    required this.pills,
    required this.selected,
    required this.onSelected,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final label = pills[i];
          final isActive = label == selected;
          return GestureDetector(
            onTap: () => onSelected(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? activeColor : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? activeColor : AppColors.grey200,
                  width: 1.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.grey600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
