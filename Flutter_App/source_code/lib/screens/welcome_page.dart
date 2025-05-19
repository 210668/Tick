

import 'package:flutter/material.dart';
import '../utils/constants.dart';


/// Page d'accueil affichée aux utilisateurs non connectés.
/// Propose la connexion ou l'inscription.
class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Accès au thème actuel
    final bool isDarkMode = theme.brightness == Brightness.dark; // Vérifie si le mode sombre est actif

    // Détermine le chemin d'accès au logo en fonction du thème
    final String logoAssetPath = isDarkMode
        ? 'assets/icon/icon_foreground_dark_mode.png' // Chemin pour le mode sombre
        : 'assets/icon/icon_foreground.png';       // Chemin pour le mode clair

    return Scaffold(
      body: SafeArea( // Assure que le contenu ne déborde pas sur les zones système
        child: Container(
          width: double.infinity, // Prend toute la largeur
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement les éléments principaux
            children: <Widget>[
              const Spacer(flex: 2), // Pousse le contenu vers le centre

              // Logo avec animation Hero, utilisant le chemin d'accès dynamique
              Hero(
                tag: 'logo', // Maintient le tag Hero pour la transition depuis SplashScreen
                child: Image.asset(
                  logoAssetPath, // Utilise le chemin d'accès déterminé
                  height: 150, // Taille ajustée
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 100),
                ),
              ),
              const SizedBox(height: 40),

              // Texte d'introduction
              Text(
                AppTexts.tagline,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppTexts.description,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3), // Plus d'espace avant les boutons

              // Boutons d'action
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.login),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  minimumSize: const Size(double.infinity, 50), // Prend toute la largeur
                ),
                child: const Text(
                  AppTexts.login,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.register),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  minimumSize: const Size(double.infinity, 50), // Prend toute la largeur
                ),
                child: const Text(
                  AppTexts.register,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 24), // Espace en bas
            ],
          ),
        ),
      ),
    );
  }
}