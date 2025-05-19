import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';

/// Un widget [Card] stylisé pour afficher des alertes ou informations.
/// Peut être utilisé dans des listes (ex: historique) ou seul.
class AlertCard extends StatelessWidget {
  final String title;
  final String message;
  final AlertType type;
  final DateTime? time; // Pour afficher le temps écoulé
  final VoidCallback? onTap; // Action au clic sur la carte
  final VoidCallback? onDismiss; // Action si la carte est dismissible

  const AlertCard({
    Key? key,
    required this.title,
    required this.message,
    this.type = AlertType.info,
    this.time,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    // Obtenir la couleur et l'icône basées sur le type d'alerte
    final Color color = AppTheme.getAlertColor(type, isDark: isDark);
    final IconData iconData = _getIconForType(type);

    // Contenu interne de la carte (ListTile pour une structure standard)
    final cardContent = ListTile(
      leading: Icon(iconData, color: color, size: 28), // Icône à gauche
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Text(message, style: theme.textTheme.bodyMedium),
          // Afficher le temps écoulé si fourni
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _formatTimeAgo(time!), // Utilise le helper de formatage
                style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ),
        ],
      ),
      onTap: onTap, // Action au clic
      // Bouton 'Fermer' si une action onDismiss est fournie
      trailing: onDismiss != null
          ? IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: AppTexts.close,
              onPressed: onDismiss,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              padding: EdgeInsets.zero, // Réduire padding du IconButton
              constraints: const BoxConstraints(), // Réduire contraintes taille
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    );

    // La carte elle-même, utilisant la CardTheme globale
    final cardWidget = Card(
      clipBehavior: Clip.antiAlias, // Pour l'effet InkWell
      child: InkWell( // Effet visuel au clic
        onTap: onTap,
        child: cardContent,
      ),
    );

    // Si onDismiss est fourni, rendre la carte dismissible
    if (onDismiss != null) {
      return Dismissible(
        // Clé unique basée sur le titre et le temps (ou ID si disponible)
        key: Key(title + (time?.toIso8601String() ?? UniqueKey().toString())),
        // Apparence lors du glissement
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.8), // Fond rouge pour suppression
            borderRadius: BorderRadius.circular(12), // Doit correspondre à CardTheme.shape
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        direction: DismissDirection.endToStart, // Glisser vers la gauche pour supprimer
        onDismissed: (_) => onDismiss!(), // Appeler la callback
        child: cardWidget,
      );
    }

    // Sinon, retourner simplement la carte
    return cardWidget;
  }

  /// Retourne l'icône appropriée pour un [AlertType].
  IconData _getIconForType(AlertType type) {
    switch (type) {
      case AlertType.success: return Icons.check_circle_outline;
      case AlertType.warning: return Icons.warning_amber_rounded;
      case AlertType.error: return Icons.error_outline;
      case AlertType.info:
      default: return Icons.info_outline;
    }
  }

  /// Formatte un [DateTime] en une chaîne de caractères relative ("il y a 5 min", "hier", etc.).
  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    // Utiliser la localisation française pour les formats
    final timeFormat = DateFormat('HH:mm', 'fr_FR');
    final dateFormat = DateFormat('dd/MM/yy', 'fr_FR');
    final dateTimeFormat = DateFormat('dd MMM à HH:mm', 'fr_FR'); // Format plus lisible
    final weekdayFormat = DateFormat('EEE', 'fr_FR'); // Jour abrégé

    if (difference.inSeconds < 60) {
      return "à l'instant";
    } else if (difference.inMinutes < 60) {
      return "il y a ${difference.inMinutes} min";
    } else if (difference.inHours < now.hour) {
      return "auj. à ${timeFormat.format(time)}";
    } else if (difference.inHours < 24 + now.hour) {
      return "hier à ${timeFormat.format(time)}";
    } else if (difference.inDays < 7) {
      return "${weekdayFormat.format(time)} à ${timeFormat.format(time)}";
    } else {
      return dateTimeFormat.format(time); // Format date et heure pour plus ancien
    }
  }
}


/// Helper pour afficher des messages SnackBar personnalisés et stylisés.
class CustomSnackBar {

  /// Affiche un SnackBar avec un style basé sur [AlertType].
  static void show(
    BuildContext context, {
    required String message,
    AlertType type = AlertType.info,
    Duration duration = AppDurations.snackbarDuration,
    SnackBarAction? action,
  }) {
    // Cacher le SnackBar précédent s'il y en a un
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // Obtenir la couleur de fond et l'icône basées sur le type
    final Color backgroundColor = AppTheme.getAlertColor(type, isDark: isDark);
    final IconData iconData = _getIconForType(type); // Utilise le helper interne
    // Choisir la couleur du texte pour un bon contraste
    final Color textColor = ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
                           ? Colors.white
                           : Colors.black;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(iconData, color: textColor.withOpacity(0.8)), // Icône légèrement transparente
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action, // Utilise SnackBarAction standard
        behavior: SnackBarBehavior.floating, // Style flottant
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Coins arrondis
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Marges pour flottant
      ),
    );
  }

  /// Raccourci pour afficher un message d'erreur standard.
  static void showError(BuildContext context, String? errorMessage, {SnackBarAction? action}) {
    show(
      context,
      message: errorMessage ?? ErrorMessages.unknownError,
      type: AlertType.error,
      action: action,
       duration: const Duration(seconds: 6), // Erreurs affichées plus longtemps
    );
  }

  /// Raccourci pour afficher un message de succès standard.
  static void showSuccess(BuildContext context, String message, {SnackBarAction? action}) {
    show(
      context,
      message: message,
      type: AlertType.success,
      action: action,
    );
  }

  /// Retourne l'icône appropriée pour un [AlertType].
  /// (Dupliqué de AlertCard pour indépendance, pourrait être dans un utilitaire commun).
  static IconData _getIconForType(AlertType type) {
    switch (type) {
      case AlertType.success: return Icons.check_circle_outline;
      case AlertType.warning: return Icons.warning_amber_rounded;
      case AlertType.error: return Icons.error_outline;
      case AlertType.info:
      default: return Icons.info_outline;
    }
  }
}