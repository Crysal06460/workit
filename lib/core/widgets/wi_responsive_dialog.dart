import 'package:flutter/material.dart';
import '../responsive/responsive_context.dart';
import '../theme/app_layout_tokens.dart';

/// Ouvre un contenu (typiquement un formulaire/wizard) de façon adaptative :
/// plein écran classique sur mobile/tablette (comportement historique
/// inchangé), dialog centré à largeur fixe sur desktop.
Future<T?> showWiAdaptiveModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = AppLayout.dialogWidthForm,
}) {
  if (!context.isDesktop) {
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: builder));
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: builder(dialogContext),
        ),
      ),
    ),
  );
}
