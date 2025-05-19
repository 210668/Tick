import 'package:flutter/material.dart';

/// Un indicateur de chargement circulaire simple et centré.
class LoadingIndicator extends StatelessWidget {
  final double size; // Diamètre du cercle
  final Color? color; // Couleur de l'indicateur (utilise la couleur primaire si null)
  final double strokeWidth; // Épaisseur du trait

  const LoadingIndicator({
    Key? key,
    this.size = 24.0, // Taille par défaut raisonnable
    this.color,
    this.strokeWidth = 3.0, // Épaisseur par défaut
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Center est souvent redondant car le widget parent (ex: ElevatedButton, Center)
    // gère généralement le centrage. Mais il ne nuit pas.
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          // Utilise la couleur fournie, ou la couleur primaire du thème actuel
          valueColor: AlwaysStoppedAnimation<Color>(
              color ?? Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}