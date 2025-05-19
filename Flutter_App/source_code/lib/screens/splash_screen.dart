import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/loading_indicator.dart';

/// Écran de démarrage affiché au lancement de l'application.
/// Vérifie l'état d'authentification et redirige l'utilisateur.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuthenticationState());
  }

  /// Vérifie si l'utilisateur est connecté via [AuthService] et navigue.
  Future<void> _checkAuthenticationState() async {
    // Attendre que le service d'authentification soit prêt
    final authService = Provider.of<AuthService>(context, listen: false);

    // Boucle d'attente
    while (!authService.isInitialized) {
      print("SplashScreen: Waiting for AuthService initialization...");
      await Future.delayed(AppDurations.shortDelay); // Attendre 500ms
      if (!mounted) return; // Quitter si le widget est démonté pendant l'attente
    }

    print("SplashScreen: AuthService initialized. Auth State: ${authService.isAuthenticated}");

    // Naviguer vers la page appropriée en fonction de l'état d'authentification
    if (authService.isAuthenticated) {
      // Utilisateur connecté -> Aller à la liste des Ticks
      Navigator.pushReplacementNamed(context, Routes.tickList);
    } else {
      // Utilisateur non connecté -> Aller à la page de bienvenue/login
      Navigator.pushReplacementNamed(context, Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Accès au thème actuel
    final bool isDarkMode = theme.brightness == Brightness.dark; // Vérifie si le mode sombre est actif
    // Détermine le chemin d'accès au logo en fonction du thème
    final String logoAssetPath = isDarkMode
        ? 'assets/icon/icon_foreground_dark_mode.png'
        : 'assets/icon/icon_foreground.png';

    // Afficher un logo et un indicateur de chargement pendant la vérification.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Utiliser Hero pour une transition douce depuis l'icône de l'app (si configuré)
            Hero(
              tag: 'logo', // Maintient le tag Hero pour la transition depuis SplashScreen
              child: Image.asset(
                logoAssetPath, // Utilise le chemin d'accès déterminé
                height: 150, // Taille ajustée
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 100),
              ),
            ),
            const SizedBox(height: 40),
            const LoadingIndicator(size: 30),
            const SizedBox(height: 16),
            Text(
              AppTexts.loading, // "Chargement..."
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}