import 'package:flutter/material.dart';

/// Enumération des types d'alertes utilisées dans l'application.
enum AlertType { info, success, warning, error }

/// Contient les configurations de thèmes Light et Dark pour l'application.
class AppTheme {
  // --- Couleurs Primaires et d'Accentuation ---
  static const Color primaryColor = Color(0xFF2196F3); // Bleu principal
  static const Color secondaryColor = Color(0xFF03A9F4); // Bleu clair
  static const Color accentColor = Color(0xFF4CAF50); // Vert pour accents/succès
  static const Color errorColor = Color(0xFFF44336); // Rouge pour erreurs
  static const Color warningColor = Color(0xFFFF9800); // Orange pour avertissements

  // Alias sémantiques (peuvent pointer vers les couleurs ci-dessus)
  static const Color successColor = accentColor;
  static const Color infoColor = primaryColor;

  // --- Couleurs Neutres (Mode Clair) ---
  static const Color backgroundColorLight = Color(0xFFF5F5F5); // Gris très clair pour fond
  static const Color surfaceColorLight = Color(0xFFFFFFFF); // Blanc pour surfaces (cartes, appbar)
  static const Color textPrimaryColorLight = Color(0xFF212121); // Noir/Gris foncé pour texte principal
  static const Color textSecondaryColorLight = Color(0xFF757575); // Gris moyen pour texte secondaire
  static const Color dividerColorLight = Color(0xFFBDBDBD); // Gris clair pour séparateurs

  // --- Couleurs Neutres (Mode Sombre) ---
  static const Color backgroundColorDark = Color(0xFF121212); // Noir/Gris très foncé pour fond
  static const Color surfaceColorDark = Color(0xFF1E1E1E); // Gris foncé pour surfaces (cartes, appbar)
  static const Color textPrimaryColorDark = Color(0xFFFFFFFF); // Blanc pour texte principal
  static const Color textSecondaryColorDark = Color(0xFFB0B0B0); // Gris clair pour texte secondaire
  static const Color dividerColorDark = Color(0xFF3C3C3C); // Gris foncé pour séparateurs

  /// Retourne la configuration ThemeData pour le mode clair.
  static ThemeData getLightTheme() {
    final baseTheme = ThemeData.light(useMaterial3: true);
    return baseTheme.copyWith(
      // Schéma de couleurs principal
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColorLight,
        background: backgroundColorLight,
        error: errorColor,
        onPrimary: Colors.white, // Texte sur couleur primaire
        onSecondary: Colors.white, // Texte sur couleur secondaire
        onSurface: textPrimaryColorLight, // Texte sur surfaces claires
        onBackground: textPrimaryColorLight, // Texte sur fond clair
        onError: Colors.white, // Texte sur couleur d'erreur
        brightness: Brightness.light,
      ),
      // Fond général des écrans
      scaffoldBackgroundColor: backgroundColorLight,
      // Style de l'AppBar
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0, // Pas d'ombre par défaut
        backgroundColor: surfaceColorLight, // Fond blanc par défaut
        foregroundColor: textPrimaryColorLight, // Couleur par défaut pour titre/icônes (peut être surchargée)
        titleTextStyle: TextStyle(
          color: textPrimaryColorLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: primaryColor, // Icônes AppBar en bleu par défaut
        ),
      ),
      // Style des boutons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white, // Texte/icône sur le bouton
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor, // Texte/icône et bordure par défaut
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor, // Texte du bouton
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      // Style des cartes
      cardTheme: CardThemeData(
        elevation: 1, // Ombre subtile
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: surfaceColorLight, // Fond de la carte
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0), // Marge par défaut
      ),
      // Style des champs de texte
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100], // Fond légèrement grisé
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder( // Bordure par défaut (utilisée si enabled/focused/error non définies)
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColorLight),
        ),
        enabledBorder: OutlineInputBorder( // Bordure quand le champ est activé mais pas en focus
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColorLight),
        ),
        focusedBorder: OutlineInputBorder( // Bordure quand le champ est en focus
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder( // Bordure en cas d'erreur
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder( // Bordure en cas d'erreur ET focus
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondaryColorLight), // Style du label flottant
        hintStyle: TextStyle(color: Colors.grey[500]), // Style du placeholder

      ),
      // Style des séparateurs
      dividerTheme: const DividerThemeData(
        color: dividerColorLight,
        space: 1,
        thickness: 1,
      ),
      // Style des SnackBars
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating, // Flottant en bas
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

      ),
      // Style des tooltips (info-bulles)
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),

    );
  }

  /// Retourne la configuration ThemeData pour le mode sombre.
  static ThemeData getDarkTheme() {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    return baseTheme.copyWith(
      // Schéma de couleurs principal
      colorScheme: const ColorScheme.dark(
        primary: primaryColor, // Garder le même bleu primaire pour la cohérence?
        secondary: secondaryColor, // Garder le même bleu secondaire?
        surface: surfaceColorDark, // Fond des composants (cartes, appbar)
        background: backgroundColorDark, // Fond général de l'écran
        error: errorColor, // Garder le même rouge
        onPrimary: Colors.white, // Texte sur bleu primaire
        onSecondary: Colors.white, // Texte sur bleu secondaire
        onSurface: textPrimaryColorDark, // Texte sur surfaces sombres (blanc)
        onBackground: textPrimaryColorDark, // Texte sur fond sombre (blanc)
        onError: Colors.black, // Texte sur couleur d'erreur (noir pour contraste)
        brightness: Brightness.dark,
      ),
      // Fond général des écrans
      scaffoldBackgroundColor: backgroundColorDark,
      // Style de l'AppBar
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: surfaceColorDark, // App bar se fond avec la surface
        foregroundColor: textPrimaryColorDark, // Couleur par défaut titre/icônes (blanc)
        titleTextStyle: TextStyle(
          color: textPrimaryColorDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: primaryColor, // Garder icônes bleues pour accent? Ou blanches (textPrimaryColorDark)?
        ),
      ),
      // Style des boutons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor, // Garder le texte/bordure bleu? Ou blanc (textPrimaryColorDark)?
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          side: const BorderSide(color: primaryColor, width: 1.5), // Garder bordure bleue?
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor, // Texte bleu
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      // Style des cartes
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: surfaceColorDark, // Couleur de la carte
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      ),
      // Style des champs de texte
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[850], // Fond des champs texte (légèrement différent de surface)
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColorDark), // Bordure par défaut
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dividerColorDark), // Bordure quand activé
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2), // Bordure focus
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 1.5), // Bordure erreur
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor, width: 2), // Bordure erreur focus
        ),
        labelStyle: TextStyle(color: textSecondaryColorDark), // Label flottant
        hintStyle: TextStyle(color: Colors.grey[600]), // Placeholder
        // helperStyle: TextStyle(color: textSecondaryColorDark),
        // errorStyle: TextStyle(color: errorColor),
      ),
      // Style des séparateurs
      dividerTheme: const DividerThemeData(
        color: dividerColorDark,
        space: 1,
        thickness: 1,
      ),
      // Style des SnackBars
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        // backgroundColor: const Color(0xFFE0E0E0), // Fond clair pour contraste sur fond sombre
        // contentTextStyle: const TextStyle(color: Colors.black), // Texte sombre
        // actionTextColor: primaryColor, // Action en bleu
      ),
      // Style des tooltips
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.black, fontSize: 12),
      ),
      // Adapter les styles de texte si nécessaire pour le thème sombre
      textTheme: baseTheme.textTheme.apply(
        bodyColor: textPrimaryColorDark, // Couleur par défaut du texte
        displayColor: textPrimaryColorDark,
      ).copyWith(
          // Ex: Rendre les titres un peu plus clairs si besoin
          // titleLarge: baseTheme.textTheme.titleLarge?.copyWith(color: Colors.white.withOpacity(0.9)),
          ),
    );
  }

  /// Retourne la couleur associée à un type d'alerte.
  ///
  /// Peut être ajustée pour le mode sombre si nécessaire via `isDark`.
  static Color getAlertColor(AlertType type, {bool isDark = false}) {
    // Actuellement, les couleurs sont les mêmes en light/dark, mais on pourrait les différencier ici.
    switch (type) {
      case AlertType.error:
        return errorColor;
      case AlertType.warning:
        return warningColor;
      case AlertType.success:
        return successColor;
      case AlertType.info:
      default:
        return primaryColor; // Ou `infoColor`
    }
  }
}