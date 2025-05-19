import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';


/// Un [IconButton] qui permet de basculer entre les modes de thème (Clair/Sombre/Système).
class ThemeToggleButton extends StatelessWidget {
  /// Callback optionnel exécuté après le changement de thème.
  final VoidCallback? onToggle;

  const ThemeToggleButton({
    Key? key,
    this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final themeService = context.watch<ThemeService>();
    final bool isCurrentlyDark = themeService.isDarkMode(context);
    final String tooltipMessage;
    final IconData iconData;

    // Déterminer l'icône et le tooltip en fonction du mode actuel effectif
    if (isCurrentlyDark) {
      iconData = Icons.light_mode_outlined; // Icône pour passer en mode clair
      tooltipMessage = 'Passer au thème clair';
    } else {
      iconData = Icons.dark_mode_outlined; // Icône pour passer en mode sombre
      tooltipMessage = 'Passer au thème sombre';
    }


    return IconButton(
      icon: Icon(iconData),
      tooltip: tooltipMessage,
      onPressed: () {
        // Appeler la méthode pour basculer le thème dans le service
        themeService.toggleThemeMode(context);
        // Exécuter le callback si fourni
        onToggle?.call();
      },
    );
  }
}