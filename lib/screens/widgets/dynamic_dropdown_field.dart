import 'package:flutter/material.dart';

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
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: (value?.isNotEmpty ?? false) ? value : (choices.isNotEmpty ? choices.first : null),
                isExpanded: true,
                dropdownColor: const Color(0xFF0F1422),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
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
