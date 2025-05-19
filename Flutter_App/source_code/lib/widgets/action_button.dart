import 'package:flutter/material.dart';
import 'loading_indicator.dart';

/// Un bouton d'action vertical simple avec une icône et un label.
/// Utilise InkWell pour un effet visuel léger au clic.
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed; // Rendre optionnel pour gérer l'état désactivé
  final Color? color; // Couleur pour l'icône et potentiellement le texte
  final bool isLoading; // Affiche un indicateur de chargement à la place de l'icône
  final bool isDisabled; // Désactive le bouton visuellement et fonctionnellement
  final double size; // Taille de l'icône

  const ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    this.onPressed, // Null si désactivé
    this.color,
    this.isLoading = false,
    this.isDisabled = false,
    this.size = 28.0, // Taille par défaut
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Déterminer si le bouton est effectivement inactif
    final bool isInactive = isDisabled || isLoading || onPressed == null;

    // Couleur effective pour l'icône et le texte
    final Color effectiveColor = isInactive
        ? theme.disabledColor // Couleur désactivée standard
        // Utilise la couleur fournie ou la couleur primaire du thème
        : color ?? theme.colorScheme.primary;

    return InkWell(
      // Désactiver l'effet InkWell si inactif
      onTap: isInactive ? null : onPressed,
      borderRadius: BorderRadius.circular(8), // Rayon pour l'effet d'encre
      // Ajouter un peu de transparence si désactivé
      child: Opacity(
        opacity: isInactive ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Padding autour
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Affiche soit l'indicateur de chargement, soit l'icône
              if (isLoading)
                SizedBox(
                  width: size,
                  height: size,
                  // Utiliser LoadingIndicator pour la cohérence
                  child: LoadingIndicator(size: size * 0.8, color: effectiveColor, strokeWidth: 2.5),
                )
              else
                Icon(
                  icon,
                  size: size,
                  color: effectiveColor,
                ),
              const SizedBox(height: 6), // Espace entre icône et texte
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: effectiveColor, // Utilise la même couleur que l'icône
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis, // Gère les textes longs
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// --- Variante ActionIconButton

/// Un bouton standard (Elevated ou Outlined) avec une icône et un label.
/// Gère les états `isLoading` et `isDisabled`.
class ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor; // Pour ElevatedButton
  final Color? foregroundColor; // Pour texte/icône des deux types
  final Color? borderColor; // Pour OutlinedButton
  final bool isLoading;
  final bool isOutlined;
  final bool isDisabled;

  const ActionIconButton({
    Key? key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDisabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isInactive = isDisabled || isLoading || onPressed == null;

    // Déterminer les couleurs effectives en fonction de l'état et du type
    final Color effectiveForegroundColor = isInactive
        ? theme.disabledColor
        : foregroundColor ?? (isOutlined ? theme.colorScheme.primary : Colors.white);

    final Color effectiveBackgroundColor = isInactive
        ? theme.disabledColor.withOpacity(0.12) // Fond désactivé standard
        : backgroundColor ?? theme.colorScheme.primary;

    final Color effectiveBorderColor = isInactive
        ? theme.disabledColor.withOpacity(0.12)
        : borderColor ?? theme.colorScheme.primary;

    // Widget pour l'icône ou l'indicateur de chargement
    final iconWidget = isLoading
        ? SizedBox(
            width: 18, // Taille cohérente avec la police du bouton
            height: 18,
            child: LoadingIndicator(size: 18, color: effectiveForegroundColor, strokeWidth: 2),
          )
        : Icon(icon, size: 18, color: effectiveForegroundColor);

    // Construire le bouton Outlined ou Elevated
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: isInactive ? null : onPressed,
        icon: iconWidget,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveForegroundColor,
          // Gérer la couleur de la bordure pour l'état désactivé
          side: BorderSide(color: effectiveBorderColor),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ).copyWith(
          // Utiliser MaterialStateProperty pour gérer la couleur de bordure désactivée
          side: MaterialStateProperty.resolveWith<BorderSide?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.disabled)) {
                return BorderSide(color: theme.disabledColor.withOpacity(0.12));
              }
              return BorderSide(color: effectiveBorderColor); // Bordure normale
            },
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: isInactive ? null : onPressed,
        icon: iconWidget,
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveForegroundColor,
          disabledBackgroundColor: theme.disabledColor.withOpacity(0.12), // Fond désactivé
          disabledForegroundColor: theme.disabledColor, // Texte/icône désactivé
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        ),
      );
    }
  }
}
