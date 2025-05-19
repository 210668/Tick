import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'notification_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../models/user.dart';
import '../utils/constants.dart';


/// Service gérant l'authentification utilisateur via AWS Cognito avec Amplify.
class AuthService with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  bool _needsConfirmation = false; // Flag pour l'étape de confirmation
  String? _pendingUsername; // Stocke l'username pour confirm/reset
  NotificationService? _notificationService; // Référence au service de notification

  // Stream pour écouter les événements d'authentification Amplify
  StreamSubscription<AuthHubEvent>? _hubSubscription;

  // Getters publics
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  bool get needsConfirmation => _needsConfirmation;
  String? get pendingUsername => _pendingUsername;

  /// Constructeur: lance l'initialisation et écoute les événements Hub.
  AuthService() {
    print("AuthService: Initializing...");
    _listenToAuthEvents(); // Démarrer l'écoute des événements
    _initializeAuthStatus(); // Vérifier l'état initial
  }

  /// Injecte NotificationService (appelé par Provider dans main.dart).
  void setNotificationService(NotificationService service) {
       _notificationService = service;
       print("AuthService: NotificationService injected.");
       // Initialiser le service de notification maintenant si l'utilisateur est déjà connecté
       // et que le service de notif n'a pas encore été initialisé.
       if (isAuthenticated && _notificationService != null && !_notificationService!.isInitialized) {
          print("AuthService: User already authenticated, initializing NotificationService.");
          _notificationService!.initialize().then((_) {
              // Après initialisation, tenter d'enregistrer le token si disponible
              _notificationService!.registerCurrentToken();
          });
       }
    }

  /// Écoute les événements d'authentification d'Amplify Hub.
  void _listenToAuthEvents() {
    _hubSubscription = Amplify.Hub.listen(HubChannel.Auth, (AuthHubEvent event) {
      safePrint('Auth Hub Event: ${event.type}'); // Utiliser safePrint
      switch (event.type) {
        case AuthHubEventType.signedIn:
          // L'utilisateur s'est connecté avec succès
          _fetchCurrentUser(setInitialized: true); // Récupérer détails utilisateur
          break;
        case AuthHubEventType.signedOut:
        case AuthHubEventType.sessionExpired:
        case AuthHubEventType.userDeleted:
          // L'utilisateur s'est déconnecté, la session a expiré ou compte supprimé
          _clearUserState(); // Effacer les données utilisateur
          _isInitialized = true; // Marquer comme initialisé même après déconnexion
          notifyListeners(); // Notifier l'UI du changement d'état
          break;

      }
    });
  }

  /// Vérifie l'état d'authentification initial au démarrage.
  Future<void> _initializeAuthStatus() async {
    if (_isInitialized) return;
    _setLoading(true);

    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        print("AuthService Initial Check: User is signed in.");
        await _fetchCurrentUser(setInitialized: false);
      } else {
        print("AuthService Initial Check: No active session.");
        _clearUserState();
      }
    } on Exception catch (e) {
      print("AuthService Initial Check Error: $e");
      _setError("Erreur lors de la vérification de la session.");
      _clearUserState();
    } finally {
      _isInitialized = true;
      _setLoading(false);
    }
  }

  /// Récupère les détails de l'utilisateur connecté, met à jour l'état et gère l'init/registration du token notif.
  Future<void> _fetchCurrentUser({bool setInitialized = true}) async {

    if (_isLoading && _currentUser != null) return;

    _setLoading(true);
    _clearError();

    try {
      final cognitoUser = await Amplify.Auth.getCurrentUser();
      final attributes = await Amplify.Auth.fetchUserAttributes();

      String displayName = '';
      String email = '';
      for (final attribute in attributes) {
        if (attribute.userAttributeKey == CognitoUserAttributeKey.name) {
          displayName = attribute.value;
        } else if (attribute.userAttributeKey == CognitoUserAttributeKey.email) {
          email = attribute.value;
        }
      }

      _updateCurrentUser(User(
        uid: cognitoUser.userId,
        email: email,
        displayName: displayName.isNotEmpty ? displayName : 'Utilisateur',
      ));

      _needsConfirmation = false;
      _pendingUsername = null;

      print("AuthService: Current user details fetched: ID=${cognitoUser.userId}");

      // --- Gestion Notifications ---
      // S'assurer que le NotificationService est injecté et initialisé
      if (_notificationService != null) {
         // Initialiser le service de notif s'il ne l'est pas déjà

         await _notificationService!.initialize();
         // Explicitement demander l'enregistrement du token actuel après fetch user
         await _notificationService!.registerCurrentToken();
      } else {
         print("AuthService WARNING: NotificationService is null during _fetchCurrentUser. Cannot initialize or register token.");
      }
      // --- Fin Gestion Notifications ---

    } on AuthException catch (e) {
      print("AuthService: Error fetching current user (Amplify): ${e.message}");
      if (e is SignedOutException) {
        _clearUserState();
      } else {
        _setError("Impossible de récupérer les informations utilisateur.");
        _clearUserState();
      }
    } catch (e) {
      print("AuthService: Error fetching current user (Other): $e");
      _setError(ErrorMessages.unknownError);
      _clearUserState();
    } finally {
      if (setInitialized) _isInitialized = true;
      _setLoading(false);
    }
  }

  /// Réinitialise l'état utilisateur (déconnexion locale).
  void _clearUserState() {
    if (_currentUser != null || _needsConfirmation || _pendingUsername != null) {
        _currentUser = null;
        _needsConfirmation = false;
        _pendingUsername = null;
        print("AuthService: User state cleared.");
        notifyListeners();
    }
  }

  // --- Méthodes d'Authentification Publiques ---
  /// Tente de connecter l'utilisateur avec email et mot de passe.
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();
    _needsConfirmation = false; // Réinitialiser le flag de confirmation

    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        print("AuthService: Login successful for $email.");
        // Le listener Hub appellera _fetchCurrentUser pour mettre à jour _currentUser et gérer les notifs
        _pendingUsername = null; // Effacer username en attente
        return true;
      } else {
        print("AuthService: Login status unexpected: ${result.nextStep.signInStep}");
        _setError("Statut de connexion inattendu.");
        _setLoading(false);
        return false;
      }
    } on AuthException catch (e) {
      print("AuthService: Login AuthException: ${e.message}");
      _handleAuthError(e, contextUsername: email); // Gérer l'erreur spécifique
      _setLoading(false);
      return false;
    } catch (e) {
      print("AuthService: Login Generic Exception: $e");
      _setError(ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }

  /// Tente d'inscrire un nouvel utilisateur.
  Future<bool> register(String email, String password, String name) async {
    _setLoading(true);
    _clearError();
    _needsConfirmation = false;

    try {
      final userAttributes = {
        CognitoUserAttributeKey.email: email,
        CognitoUserAttributeKey.name: name,
      };

      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(userAttributes: userAttributes),
      );

      if (result.isSignUpComplete) {
        print("AuthService: Sign up complete for $email (auto-verified).");
        _pendingUsername = null;
        _setLoading(false);
        return true;
      } else if (result.nextStep.signUpStep == AuthSignUpStep.confirmSignUp) {
        print("AuthService: Sign up requires confirmation for $email. Delivery: ${result.nextStep.codeDeliveryDetails}");
        _needsConfirmation = true;
        _pendingUsername = email;
        _setLoading(false);
        return true;
      } else {
        print("AuthService: Sign up status unexpected: ${result.nextStep.signUpStep}");
        _setError("Statut d'inscription inattendu.");
        _setLoading(false);
        return false;
      }

    } on AuthException catch (e) {
      print("AuthService: Register AuthException: ${e.message}");
      _handleAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      print("AuthService: Register Generic Exception: $e");
      _setError(ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }

  /// Confirme l'inscription avec le code reçu.
  Future<bool> confirmSignUp(String username, String confirmationCode) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: username,
        confirmationCode: confirmationCode,
      );

      if (result.isSignUpComplete) {
        print("AuthService: Sign up confirmed successfully for $username.");
        _needsConfirmation = false;
        _pendingUsername = null;
        _setLoading(false);
        return true;
      } else {
        print("AuthService: Confirmation status unexpected: ${result.nextStep.signUpStep}");
        _setError("Statut de confirmation inattendu.");
        _setLoading(false);
        return false;
      }
    } on AuthException catch (e) {
      print("AuthService: Confirm SignUp AuthException: ${e.message}");
      _handleAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      print("AuthService: Confirm SignUp Generic Exception: $e");
      _setError(ErrorMessages.unknownError);
      _setLoading(false);
      return false;
    }
  }

  /// Renvoie le code de confirmation pour un utilisateur non confirmé.
  Future<bool> resendConfirmationCode(String username) async {
    _setLoading(true);
    _clearError();

    try {
      await Amplify.Auth.resendSignUpCode(username: username);
      print("AuthService: Confirmation code resent successfully for $username.");
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      print("AuthService: Resend Code AuthException: ${e.message}");
      _handleAuthError(e);
       if (e is InvalidParameterException && e.message.contains('confirmed user')) {
           _needsConfirmation = false;
           _pendingUsername = null;
       }
      _setLoading(false);
      return false;
    } catch (e) {
      print("AuthService: Resend Code Generic Exception: $e");
      _setError(ErrorMessages.unknownError);
      _setLoading(false);
      return false;
    }
  }
    /// Lance le processus de réinitialisation de mot de passe pour un email donné.
  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await Amplify.Auth.resetPassword(username: email);
      if (result.nextStep.updateStep == AuthResetPasswordStep.confirmResetPasswordWithCode) {
        print("AuthService: Password reset code sent to: ${result.nextStep.codeDeliveryDetails?.destination}");
        _pendingUsername = email;
        _setLoading(false);
        return true;
      } else {
        print("AuthService: Password reset status unexpected: ${result.nextStep.updateStep}");
        _setError("Statut de réinitialisation inattendu.");
        _setLoading(false);
        return false;
      }
    } on AuthException catch (e) {
      print("AuthService: Reset Password AuthException: ${e.message}");
      _handleAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      print("AuthService: Reset Password Generic Exception: $e");
      _setError(ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }

  /// Confirme la réinitialisation du mot de passe avec le code et le nouveau mot de passe.
  Future<bool> confirmPasswordReset(String username, String newPassword, String confirmationCode) async {
    _setLoading(true);
    _clearError();

    try {
      await Amplify.Auth.confirmResetPassword(
        username: username,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      print("AuthService: Password reset confirmed successfully for $username.");
      _pendingUsername = null;
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      print("AuthService: Confirm Password Reset AuthException: ${e.message}");
      _handleAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      print("AuthService: Confirm Password Reset Generic Exception: $e");
      _setError(ErrorMessages.unknownError);
      _setLoading(false);
      return false;
    }
  }

  /// Met à jour l'attribut 'name' de l'utilisateur Cognito.
  Future<bool> updateUserName(String newName) async {
    if (_currentUser == null) {
      _setError("Utilisateur non connecté.");
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      final attributes = [
        AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.name,
          value: newName,
        ),
      ];
      await Amplify.Auth.updateUserAttributes(attributes: attributes);
      print("AuthService: User attribute 'name' update requested successfully.");

      _updateCurrentUser(_currentUser!.copyWith(displayName: newName));
      _setLoading(false);
      return true;

    } on AuthException catch (e) {
      print("AuthService: Update User Name AuthException: ${e.message}");
      _handleAuthError(e);
      _setLoading(false);
      return false;
    } catch (e) {
      print("AuthService: Update User Name Generic Exception: $e");
      _setError(ErrorMessages.unknownError);
      _setLoading(false);
      return false;
    }
  }


  /// Déconnecte l'utilisateur actuel et tente de désenregistrer le token de notification.
  Future<void> logout() async {
    _setLoading(true);
    _clearError();
    try {
      // Tenter de désenregistrer le token avant la déconnexion Amplify
      if (_notificationService != null) {
        await _notificationService!.unregisterTokenFromBackend();
      } else {
        print("AuthService WARNING: NotificationService is null during logout. Cannot unregister token.");
      }

      // Procéder à la déconnexion Amplify
      await Amplify.Auth.signOut();
      print("AuthService: Logout successful via Amplify.");
      // Le listener Hub (`_listenToAuthEvents`) gérera la mise à jour de l'état local (_clearUserState, notifyListeners).
    } on AuthException catch (e) {
      print('AuthService: Error during Amplify logout: ${e.message}');
      _setError("Erreur lors de la déconnexion.");
      // Forcer la réinitialisation de l'état local même si l'API Amplify échoue
      _clearUserState();
    } catch (e) {
      print('AuthService: Generic error during logout: $e');
       _setError("Erreur inconnue lors de la déconnexion.");
      _clearUserState(); // Forcer aussi la réinitialisation ici
    }
    finally {
      _setLoading(false); // Assurer que le chargement s'arrête
    }
  }

  // --- Méthodes internes de gestion d'état ---
  void _setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? errorMessage) {
    String? finalMessage = errorMessage;
    if (errorMessage != null) {
        final messageIndex = errorMessage.indexOf('message:');
        final bracketIndex = errorMessage.indexOf(']');
        if (messageIndex != -1) finalMessage = errorMessage.substring(messageIndex + 8).trim();
        else if (bracketIndex != -1) finalMessage = errorMessage.substring(bracketIndex + 1).trim();
        if (finalMessage?.startsWith('{') == true) finalMessage = "Erreur de communication serveur.";
    }
    if (_error == finalMessage) return;
    _error = finalMessage;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _updateCurrentUser(User? user) {
    if (_currentUser == user) return;
    _currentUser = user;
    notifyListeners();
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    print("[AuthService.changePassword] Attempting to change password...");
    if (!isAuthenticated) {
      print("[AuthService.changePassword] Error: User not authenticated.");
      _setError("Utilisateur non connecté.");
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      print("[AuthService.changePassword] Calling Amplify.Auth.updatePassword...");
      // Appelle la fonction Amplify pour mettre à jour le mot de passe
      await Amplify.Auth.updatePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      print("[AuthService.changePassword] Amplify call successful.");
      print("[AuthService.changePassword] Setting loading to false and returning true.");
      _setLoading(false);
      return true; // Succès

    } on AuthException catch (e) {
      print("[AuthService.changePassword] Caught AuthException!");
      print("  -> Exception Type: ${e.runtimeType}");
      print("  -> Exception Message: ${e.message}");
      print("  -> Underlying Exception: ${e.underlyingException}");

      // Gérer les erreurs spécifiques possibles
      if (e is amplify_core.AuthNotAuthorizedException) {
        print("[AuthService.changePassword] Handling core.AuthNotAuthorizedException...");
        print("[AuthService.changePassword] Setting error: ${ErrorMessages.invalidCredentials}");
        _setError(ErrorMessages.invalidCredentials);
      } else if (e is InvalidPasswordException) { // Vient de auth_cognito normalement
        print("[AuthService.changePassword] Handling InvalidPasswordException...");
        print("[AuthService.changePassword] Setting error: Criteria not met");
        _setError("Le nouveau mot de passe ne respecte pas les critères requis.");
      } else if (e is LimitExceededException) {
        print("[AuthService.changePassword] Handling core.LimitExceededException...");
        print("[AuthService.changePassword] Setting error: Too many attempts");
        _setError("Trop de tentatives. Veuillez réessayer plus tard.");
      } else {
        print("[AuthService.changePassword] Handling with _handleAuthError...");
        _handleAuthError(e); // Utilise le helper existant pour d'autres erreurs
      }
      print("[AuthService.changePassword] Setting loading to false and returning false (AuthException).");
      _setLoading(false);
      return false; // Échec

    } catch (e, stacktrace) { // Attrape les erreurs génériques aussi
      print("[AuthService.changePassword] Caught Generic Exception!");
      print("  -> Exception Type: ${e.runtimeType}");
      print("  -> Exception: $e");
      print("  -> Stacktrace: $stacktrace");
      print("[AuthService.changePassword] Setting error: ${ErrorMessages.unknownError}");
      _setError(ErrorMessages.unknownError);
      print("[AuthService.changePassword] Setting loading to false and returning false (Generic Exception).");
      _setLoading(false);
      return false; // Échec
    }
  }

  void _handleAuthError(AuthException e, {String? contextUsername}) {
     if (e is UserNotFoundException || e is NotAuthorizedServiceException) {
        _setError(ErrorMessages.invalidCredentials);
     } else if (e is UserNotConfirmedException) {
        _setError(ErrorMessages.userNotConfirmed);
        _needsConfirmation = true;
        _pendingUsername = contextUsername;
     } else if (e is UsernameExistsException) {
        _setError(ErrorMessages.emailInUse);
     } else if (e is InvalidPasswordException) {
        _setError("Le mot de passe ne respecte pas les critères requis.");
     } else if (e is CodeMismatchException) {
        _setError("Code de confirmation invalide.");
     } else if (e is ExpiredCodeException) {
        _setError("Le code de confirmation a expiré. Veuillez en demander un nouveau.");
     } else if (e is AliasExistsException) {
        _setError("Cet email est déjà associé à un autre compte confirmé.");
        _needsConfirmation = false;
        _pendingUsername = null;
     } else if (e is LimitExceededException) {
         _setError("Trop de tentatives. Veuillez réessayer plus tard.");
     } else if (e is InvalidParameterException && e.message.contains('confirmed user')) {
         _setError("Cet utilisateur est déjà confirmé.");
     } else if (e is SignedOutException) {
         _setError("Vous avez été déconnecté.");
         _clearUserState();
     } else {
        _setError(e.message);
     }
  }

  /// Nettoie les ressources (listener Hub) lors de la destruction du service.
  @override
  void dispose() {
    print("AuthService: Disposing...");
    _hubSubscription?.cancel(); // Annuler l'abonnement aux événements Hub
    super.dispose();
  }
}