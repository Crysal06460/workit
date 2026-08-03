import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class DynamicDropdownField extends StatelessWidget {
  const DynamicDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    this.onChanged,
    this.required = false,
  });

  final String label;
  final String? value;
  final List<String> choices;
  final ValueChanged<String?>? onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(color: AppColors.grey600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: (value?.isNotEmpty ?? false) ? value : (choices.isNotEmpty ? choices.first : null),
                isExpanded: true,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.grey900),
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.grey500),
                items: choices.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
