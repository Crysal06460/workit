import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Grand bouton d'action principal (pleine largeur)
///
/// Usage :
/// ```dart
/// WiCtaButton(
///   label: 'Ajouter un devis',
///   icon: Icons.add,
///   onTap: _openAddDevisSheet,
/// )
/// ```
class WiCtaButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;

  /// Pleine largeur par défaut (comportement mobile historique). Passer
  /// `false` pour un bouton de largeur naturelle (ex: top bar desktop).
  final bool fullWidth;

  const WiCtaButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: fullWidth ? 0 : 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
