import 'package:flutter/material.dart';

/// Enveloppe un écran poussé (Agenda, Réglages...) pour permettre de revenir
/// en arrière en glissant vers la droite depuis le bord gauche de l'écran —
/// en plus du bouton retour natif de l'AppBar. Le geste ne démarre que si le
/// doigt touche d'abord une bande étroite près du bord gauche (`edgeWidth`),
/// pour ne pas entrer en conflit avec le glisser-déposer horizontal de
/// l'agenda (drag-and-drop des chantiers) qui, lui, démarre toujours plus
/// loin dans la grille.
class WiSwipeBack extends StatefulWidget {
  const WiSwipeBack({super.key, required this.child, this.edgeWidth = 60});

  final Widget child;
  final double edgeWidth;

  @override
  State<WiSwipeBack> createState() => _WiSwipeBackState();
}

class _WiSwipeBackState extends State<WiSwipeBack> {
  bool _trackingFromEdge = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        _trackingFromEdge = details.globalPosition.dx <= widget.edgeWidth;
      },
      onHorizontalDragEnd: (details) {
        if (!_trackingFromEdge) return;
        _trackingFromEdge = false;
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 200) {
          Navigator.of(context).maybePop();
        }
      },
      child: widget.child,
    );
  }
}
