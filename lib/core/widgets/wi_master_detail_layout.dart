import 'package:flutter/material.dart';
import '../responsive/responsive_context.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout_tokens.dart';

/// Layout maître-détail générique pour desktop : liste à largeur fixe à
/// gauche, panneau détail étendu à droite. Sur mobile/tablette, seul
/// `master` est rendu — l'écran appelant garde son propre mécanisme de
/// détail (bottom sheet, navigation), inchangé.
class WiMasterDetailLayout extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final Widget emptyDetailPlaceholder;

  const WiMasterDetailLayout({
    super.key,
    required this.master,
    this.detail,
    this.emptyDetailPlaceholder = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktop) return master;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: AppLayout.masterPaneWidth, child: master),
        const VerticalDivider(width: 1, color: AppColors.grey200),
        Expanded(
          child: detail ?? Center(child: emptyDetailPlaceholder),
        ),
      ],
    );
  }
}
