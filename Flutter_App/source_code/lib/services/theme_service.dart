import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';


/// Service pour gérer le thème de l'application (Clair, Sombre, Système).
class ThemeService with ChangeNotifier {


  ThemeMode _themeMode = ThemeMode.system; // Thème par défaut

  // Getter public pour le mode actuel
  ThemeMode get themeMode => _themeMode;

  /// Constructeur: peut charger le thème persisté au démarrage.
  ThemeService() {

  }



  /// Vérifie si le mode sombre est actuellement actif, en tenant compte du mode système.
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      // Utiliser platformBrightnessOf pour obtenir la luminosité système actuelle
      // Cela est plus fiable que MediaQuery pendant certaines phases du build.
      var brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;

      return brightness == Brightness.dark;
    }
    // Si le mode est explicitement Dark
    return _themeMode == ThemeMode.dark;
  }

  /// Met à jour le mode de thème de l'application.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return; // Pas de changement
    _themeMode = mode;
    print("ThemeService: Theme mode set to $_themeMode");

    notifyListeners(); // Notifier l'UI du changement
  }

  /// Bascule entre les modes de thème disponibles (Clair <-> Sombre).
  /// Ignore le mode Système pour une bascule simple.
  void toggleThemeMode(BuildContext context) {
    // Détermine le mode actuel effectif (clair ou sombre)
    bool isCurrentlyDark = isDarkMode(context);
    // Bascule vers le mode opposé explicite
    setThemeMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);


  }

  /// Retourne le nom lisible du mode de thème actuel.
  String getThemeModeName() {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
      default:
        return 'Système';
    }
  }
}
