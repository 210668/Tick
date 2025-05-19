import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../models/tick_model.dart';



/// Contient les configurations liées à l'API backend.
class ApiConfigURLs {
  /// URL de la fonction Lambda pour enregistrer le token FCM de l'appareil.

  static const String registerDeviceTokenFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour récupérer les Ticks de l'utilisateur.
    static const String getMyTicksFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour demander la localisation d'un Tick.
    static const String requestLocationFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour associer un nouveau Tick.
    static const String associateTickFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour récupérer l'historique d'un Tick.
    static const String getTickHistoryFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour dissocier un Tick.
    static const String removeTickFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour mettre à jour les paramètres d'un Tick (nom, etc.).
  static const String updateTickSettingsFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour faire sonner un Tick.
    static const String ringTickFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour désactiver temporairement un Tick.
  static const String disableTickFunctionUrl = 'YOUR_FUNCTION_URL';

  /// URL de la fonction Lambda pour sortir le Tick du mode veille
  static const String reactivateTickFunctionUrl= 'YOUR_FUNCTION_URL';
}


/// Messages d'erreur standardisés affichés à l'utilisateur.
class ErrorMessages {
  // Erreurs réseau et serveur
  static const String connectionFailed = 'Impossible de se connecter au serveur. Vérifiez votre connexion internet.';
  static const String networkError = 'Erreur de réseau, veuillez réessayer.';
  static const String apiError = 'Erreur de communication avec le serveur.';
  static const String unknownError = 'Une erreur inconnue est survenue.';

  // Erreurs d'authentification (certains sont gérés par Amplify)
  static const String invalidCredentials = 'Email ou mot de passe incorrect.';
  static const String emailInUse = 'Cette adresse email est déjà utilisée.';
  static const String userNotConfirmed = 'Veuillez confirmer votre compte avant de vous connecter.';

  // Erreurs Bluetooth et Association
  static const String deviceNotFound = 'Aucun appareil Tick compatible trouvé à proximité.';
  static const String bluetoothScanError = 'Erreur lors de la recherche Bluetooth.';
  static const String associationFailed = 'Échec de l\'association du Tick.';
  static const String bluetoothNotEnabled = 'Veuillez activer le Bluetooth.';
  static const String bleNotSupported = 'Le Bluetooth Low Energy n\'est pas supporté sur cet appareil.';

  // Erreurs de permissions
  static const String permissionDenied = 'Permission nécessaire refusée.';
  static const String permissionDeniedLocation = 'La permission de localisation est requise.';
  static const String permissionDeniedBluetooth = 'Les permissions Bluetooth sont requises.';
  static const String permissionDeniedForever = 'Permission refusée définitivement.';
  static const String permissionDeniedLocationExplain = 'Permission de localisation refusée définitivement. Veuillez l\'activer manuellement dans les paramètres de l\'application pour utiliser cette fonctionnalité.';
  static const String locationServiceDisabled = 'Le service de localisation doit être activé.';
  static const String unauthorizedAccess = 'Accès refusé.';

  // Erreurs de formulaire
  static const String invalidInput = 'Veuillez vérifier les informations saisies.';
}


/// Textes utilisés dans l'interface utilisateur.
class AppTexts {
  static const String appName = 'MyTick';
  static const String welcome = 'Bienvenue';
  static const String tagline = 'Ne perdez plus jamais vos objets';
  static const String description = 'Localisez vos appareils Tick en temps réel et recevez des alertes instantanées.';

  // --- Boutons Communs ---
  static const String login = 'Se connecter';
  static const String register = 'Créer un compte';
  static const String continueWithoutAccount = 'Continuer sans compte';
  static const String logout = 'Se déconnecter';
  static const String save = 'Enregistrer';
  static const String cancel = 'Annuler';
  static const String confirm = 'Confirmer';
  static const String next = 'Suivant';
  static const String back = 'Retour';
  static const String retry = 'Réessayer';
  static const String close = 'Fermer';
  static const String add = 'Ajouter';
  static const String delete = 'Supprimer';
  static const String edit = 'Modifier';
  static const String error = 'Erreur';
  static const String done = 'Terminé';

  // --- Authentification ---
  static const String forgotPassword = 'Mot de passe oublié ?';
  static const String noAccount = 'Pas encore de compte ?';
  static const String alreadyAccount = 'Déjà un compte ?';
  static const String passwordRecovery = 'Récupération de mot de passe';
  static const String passwordRecoveryInstructions = 'Entrez votre email pour recevoir les instructions de réinitialisation.';
  static const String sendRecoveryLink = 'Envoyer le lien';
  static const String recoveryLinkSent = 'Email de réinitialisation envoyé.';
  static const String confirmAccount = "Confirmer l'inscription";
  static const String confirmationCode = "Code de confirmation";
  static const String resendCode = "Renvoyer le code";
  static const String codeSentTo = "Un code de confirmation a été envoyé à :";
  static const String enterConfirmationCode = "Entrez le code à 6 chiffres";
  static const String checkEmailForCode = "Vérifiez votre email pour le code";
  static const String resetPassword = "Réinitialiser Mot de Passe";
  static const String newPassword = "Nouveau mot de passe";
  static const String enterResetCode = "Code de réinitialisation";

  // --- Formulaires ---
  static const String email = 'Adresse Email';
  static const String password = 'Mot de passe';
  static const String confirmPassword = 'Confirmer le mot de passe';
  static const String name = 'Nom complet';
  static const String firstName = 'Prénom';
  static const String lastName = 'Nom';
  static const String tickName = 'Nom du Tick';
  static const String tickNameHint = 'Ex: Clés, Sac à dos, Vélo...';

  // --- Validation Formulaires ---
  static const String requiredField = 'Ce champ est requis';
  static const String invalidEmail = 'Adresse email invalide';
  static const String passwordTooShort = 'Le mot de passe doit faire au moins 8 caractères';
  static const String passwordsDoNotMatch = 'Les mots de passe ne correspondent pas';
  static const String invalidCode = 'Code invalide';

  // --- Écrans & Sections ---
  static const String myTicks = 'Mes Ticks';
  static const String addTick = 'Ajouter un Tick';
  static const String tickDetails = 'Détails du Tick';
  static const String noTicksAvailable = 'Aucun Tick associé';
  static const String addFirstTick = 'Ajoutez votre premier Tick pour commencer';
  static const String map = 'Carte';
  static const String settings = 'Paramètres';
  static const String profile = 'Profil';
  static const String history_map_page = 'Alertes';
  static const String history = 'Historique des alertes';
  static const String alerts = 'Alertes récentes';
  static const String information = 'Informations';
  static const String general = 'Général';
  static const String features = 'Fonctionnalités';
  static const String dangerZone = 'Zone de Danger';
  static const String appearance = 'Apparence';
  static const String notifications = 'Notifications';
  static const String security = 'Sécurité';

  // --- Association Tick ---
  static const String associateNewTick = 'Associer un nouveau Tick';
  static const String associationSteps = 'Suivez les étapes pour connecter votre appareil.';
  static const String step1_Naming = '1. Nommez votre Tick';
  static const String step2_Scanning = '2. Recherche du Tick';
  static const String step3_Sending = '3. Association';
  static const String step4_Done = '4. Terminé';
  static const String enableBluetoothPrompt = 'Le Bluetooth est nécessaire pour trouver votre Tick.';
  static const String enableBluetoothButton = 'Activer le Bluetooth';
  static const String bluetoothEnabled = 'Bluetooth activé';
  static const String activateTickPrompt = 'Assurez-vous que votre Tick est allumé et à proximité.';
  static const String searchTickButton = 'Rechercher mon Tick';
  static const String searchingTick = 'Recherche du Tick en cours...';
  static const String connectingTick = 'Connexion au Tick...';
  static const String tickFound = 'Tick trouvé !';
  static const String tickMacAddress = 'Adresse MAC';
  static const String associatingTick = 'Association en cours...';
  static const String associateTickButton = 'Associer ce Tick';
  static const String tickAssociatedSuccess = 'Tick associé avec succès !';
  static const String tickIdExtracted = 'ID du Tick détecté';

  // --- Détails Tick & Carte ---
  static const String currentStatus = 'État actuel';
  static const String lastPosition = 'Dernière position';
  static const String battery = 'Batterie';
  static const String lastUpdate = 'Dernière MàJ';
  static const String locate = 'Localiser';
  static const String ring = 'Faire sonner';
  static const String centerOnTick = 'Centrer sur le Tick';
  static const String centerOnMe = 'Centrer sur ma position';
  static const String fetchingLocation = 'Récupération de la position...';
  static const String ringingTick = 'Sonnerie en cours...';
  static const String updating = 'Mise à jour...';
  static const String errorFetchingLocation = 'Erreur de localisation';
  static const String locationUpdated = 'Position mise à jour';
  static const String locationRequestSent = 'Demande de localisation envoyée...';
  static const String noLocationAvailable = 'Position non disponible';
  static const String tryToLocate = 'Tenter de localiser';
  static const String ringingTickCommandSent = 'Commande de sonnerie envoyée.';
  static const String ringingTickError = 'Erreur lors de la sonnerie.';

  // --- Paramètres Tick ---
  static const String tickSettings = 'Paramètres du Tick';
  static const String changeName = 'Changer le nom';
  static const String soundSettings = 'Paramètres de sonnerie';
  static const String disableDevice = "Désactiver l'appareil";
  static const String reactivateDevice = "Réactiver l'appareil";
  static const String disableDuration = 'Durée de désactivation';
  static const String untilReactivation = "Jusqu'à réactivation";
  static const String unlinkDevice = 'Dissocier cet appareil';
  static const String unlinkDeviceConfirm = 'Êtes-vous sûr de vouloir désassocier ce Tick ? Cette action est irréversible.';
  static const String unlinkSuccess = 'Tick dissocié avec succès.';
  static const String featureComingSoon = 'Fonctionnalité bientôt disponible';
  static const String soundSection = 'Sonnerie';
  static const String selectAlarmSound = 'Sélectionner la sonnerie';
  static const String preview = 'Écouter';
  static const String noSoundSelected = 'Aucune sélectionnée';

  // --- Autres ---
  static const String loading = 'Chargement...';
  static const String noHistoryAvailable = 'Aucun historique disponible';
  static const String loadingHistoryError = 'Erreur de chargement de l\'historique';
  static const String featureNotAvailableOnPlatform = 'Fonctionnalité non disponible sur cette plateforme.';
  static const String openSettings = 'Ouvrir les paramètres';
  static const String unknownUser = 'Utilisateur inconnu';
  static const String notConnected = 'Non connecté';
  static const String updateSuccess = 'Mise à jour réussie.';
  static const String updateError = 'Erreur lors de la mise à jour.';
}

/// Routes nommées pour la navigation GoRouter/Navigator 2.0.
class Routes {
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String confirmSignUp = '/confirm';
  static const String passwordRecovery = '/password-recovery';
  static const String tickList = '/ticks';
  static const String tickMap = '/ticks/map';
  static const String addTick = '/ticks/add';
  static const String tickSettings = 'tick_settings_page';
  static const String tickHistory = '/ticks/history';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String changePassword = '/profile/change-password';
  static const String helpSupport = '/settings/help';
  static const String aboutApp = '/settings/about';
  static const String privacyPolicy = '/settings/privacy';
  static const String termsOfService = '/settings/terms';
}


/// Configuration spécifique au Bluetooth.
class BluetoothConfig {
  /// UUID du service principal exposé par les Ticks ESP32 en BLE.
  /// Doit correspondre exactement à celui défini dans le firmware ESP32.
  static const String tickServiceUuid = "7a8274fc-0723-44da-ad07-2293d5a5212a";

  /// Préfixe attendu pour le nom des appareils Tick diffusé en BLE.
  /// Le format attendu est "Tick-ID_UNIQUE_DU_TICK".
  static const String tickNamePrefix = "Tick-";

  /// Durée maximale (en secondes) pour un scan Bluetooth.
  static const int scanTimeoutSeconds = 15;
}


/// Couleurs spécifiques liées à la logique métier (statut, batterie).
class AppColors {
  /// Retourne la couleur associée à un statut [TickStatus].
  /// Prend en compte le [BuildContext] pour adapter au thème clair/sombre si nécessaire.
  static Color getStatusColor(TickStatus status, BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case TickStatus.active: return AppTheme.successColor;
      case TickStatus.inactive:
        return isDark ? AppTheme.textSecondaryColorDark : AppTheme.textSecondaryColorLight;
      case TickStatus.lowBattery: return AppTheme.warningColor;
      case TickStatus.moving: return AppTheme.primaryColor;
      case TickStatus.theftAlert: return AppTheme.errorColor;
      case TickStatus.disabled: return AppTheme.errorColor;
      case TickStatus.unknown:
      default: return Colors.grey;
    }
  }

  /// Retourne la couleur associée à un niveau de batterie.
  static Color getBatteryColor(int? level) {
    // Utilise les couleurs sémantiques définies dans AppTheme
    if (level == null) return Colors.grey;
    if (level > 60) return AppTheme.successColor; // Vert si > 60%
    if (level > 20) return AppTheme.warningColor; // Orange si > 20%
    return AppTheme.errorColor; // Rouge si <= 20%
  }
}

/// Durées standard utilisées dans l'application (animations, timeouts).
class AppDurations {
  static const Duration shortFade = Duration(milliseconds: 200);
  static const Duration mediumFade = Duration(milliseconds: 400);
  static const Duration longFade = Duration(milliseconds: 600);
  static const Duration snackbarDuration = Duration(seconds: 4);
  static const Duration apiTimeout = Duration(seconds: 20);
  static const Duration shortDelay = Duration(milliseconds: 500);
  static const Duration mediumDelay = Duration(seconds: 1);
  static const Duration longDelay = Duration(seconds: 3);
}

class AppSounds {
    static const Map<int, String> alarmSounds = {
        1: 'Classique',
        2: 'Klaxons',
        3: 'Klaxons bruyants',
        4: 'Klaxons rapides',
        5: 'Alarme',
        6: 'Bruyant',
        7: 'Nucléaire',
        8: 'Suspect',
        9: 'Valeureux',
    };

    /// Retourne le chemin d'accès au fichier son dans les assets.
    static String getSoundPath(int index) {
        return 'sounds/$index.wav';
    }
}

class MqttConfig {
   static const String awsIotEndpoint = 'apflqqfc1rv3u-ats.iot.eu-north-1.amazonaws.com';
   static const String awsRegion = 'eu-north-1';
   static const int port = 443;
   static String getClientId(String userId) => 'flutter_app_${userId}_${DateTime.now().millisecondsSinceEpoch}'; // Assure l'unicité
}