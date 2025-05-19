import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../utils/constants.dart';



/// Fonction Top-Level pour gérer les messages en arrière-plan (requis par firebase_messaging)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {


  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');
  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification?.title} / ${message.notification?.body}');
  }
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final ApiService _apiService; // Pour envoyer le token au backend
  final AuthService _authService; // Pour obtenir le userId

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  String? _currentToken;
  // Flag pour éviter d'envoyer le token plusieurs fois inutilement par session
  bool _tokenSentThisSession = false;

  NotificationService(this._apiService, this._authService);

  Future<void> initialize() async {
    // Éviter ré-initialisation ou initialisation sur le Web
    if (_isInitialized || kIsWeb) return;
    _isInitialized = true; // Marquer comme initialisé tôt pour éviter appels multiples
    print("NotificationService: Initializing...");

    // --- Demande de permissions ---
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true, announcement: false, badge: true, carPlay: false,
      criticalAlert: false, provisional: false, sound: true,
    );
    print('NotificationService: User granted permission: ${settings.authorizationStatus}');
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      print('NotificationService: Notification permission not granted. Stopping init.');
      return; // Ne pas continuer si les permissions sont refusées
    }

    // --- Obtention et envoi du token initial ---
    try {
       _currentToken = await _firebaseMessaging.getToken();
       print('NotificationService: Device Token (via getToken): $_currentToken');
       if (_currentToken != null && _authService.isAuthenticated) {
           // Envoyer le token initial si connecté
           await registerCurrentToken(); // Utiliser la méthode helper
       }
    } catch (e) {
       print('NotificationService: Error getting initial token: $e');
    }

    // --- Écoute des rafraîchissements de token ---
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('NotificationService: Token refreshed: $newToken');
      _currentToken = newToken;
      _tokenSentThisSession = false; // Permettre l'envoi du nouveau token
      if (_authService.isAuthenticated) {
        registerCurrentToken(); // Utiliser la méthode helper
      }
    }).onError((err) {
       print('NotificationService: Error onTokenRefresh: $err');
    });

    // --- Configuration des handlers de messages ---
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('NotificationService: Foreground Message received!');
      _handleForegroundMessage(message); // Externaliser la logique
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('NotificationService: Notification tapped! (App opened)');
      _handleMessageOpenedApp(message); // Externaliser la logique
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
       print('NotificationService: App launched from terminated state via notification!');
       _handleMessageOpenedApp(initialMessage); // Gérer comme un tap normal
    }

    print("NotificationService: Initialization complete.");
  }

  /// Helper pour déclencher l'envoi du token actuel si disponible et pas déjà envoyé.
  Future<void> registerCurrentToken() async {
      if (_currentToken != null && !_tokenSentThisSession) {
          print("NotificationService: Triggering token send to backend.");
          await _sendTokenToBackend(_currentToken!);
      } else if (_currentToken == null) {
          print("NotificationService: Cannot register token, current token is null.");
      } else {
          print("NotificationService: Token already sent this session, skipping.");
      }
  }


  /// Envoie le token de l'appareil au backend pour enregistrement.
  Future<void> _sendTokenToBackend(String token) async {
    // Vérifier l'authentification juste avant l'envoi
    if (!_authService.isAuthenticated) {
       print("NotificationService: Cannot send token, user not authenticated.");
       return;
    }
    // Vérifier si l'URL est configurée correctement
    if (ApiConfigURLs.registerDeviceTokenFunctionUrl.isEmpty || ApiConfigURLs.registerDeviceTokenFunctionUrl.startsWith('YOUR_')) {
       print("NotificationService: ERROR - Register Device Token URL not configured in constants.dart.");

       return;
    }

    // Déterminer la plateforme
    final String platform = defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS
                           ? 'APNS' // Standard pour Apple Push Notification Service
                           : 'GCM';  // Standard pour Google Cloud Messaging (utilisé par FCM sur Android)

    print("NotificationService: Sending token to backend ($platform)... Token: ${token.substring(0,10)}...");
    try {
      // Utiliser l'URL configurée dans constants.dart
      final response = await _apiService.post(
        ApiConfigURLs.registerDeviceTokenFunctionUrl,
        {
          'deviceToken': token,
          'platform': platform,
          // L'userID est ajouté côté backend à partir du token d'authentification
        },
      );
      if (response['success']) {
         print("NotificationService: Token registered successfully with backend.");
         _tokenSentThisSession = true; // Marquer comme envoyé pour cette session
      } else {
         print("NotificationService: Failed to register token with backend: ${response['error']}");
         // Ne pas marquer comme envoyé si échec, pour réessayer plus tard
      }
    } catch (e) {
       print("NotificationService: Exception sending token to backend: $e");
       // Ne pas marquer comme envoyé si échec
    }
  }

  // --- Logique de gestion des messages reçus (peut être étendue) ---
  void _handleForegroundMessage(RemoteMessage message) {
     // Afficher un SnackBar ou une notification locale
     // Mettre à jour l'état de l'application si nécessaire (ex: TickService)
     if (message.notification != null) {
       print("FG Message: ${message.notification?.title} - ${message.notification?.body}");

     }
     if(message.data.isNotEmpty) {
        print("FG Message Data: ${message.data}");
        // Traiter les données ici (ex: mettre à jour TickService)
     }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
     // Naviguer vers l'écran approprié
     final tickId = message.data['tickId'];
     if (tickId != null) {
        print("Navigate to map for tick: $tickId");

     }
  }


  Future<void> unregisterTokenFromBackend() async {
     if (_currentToken == null) return;
     if (!_authService.isAuthenticated) return; // Assurer que l'utilisateur est connecté


     const String unregisterEndpointUrl = ''; // Définir l'URL de désenregistrement
      if (unregisterEndpointUrl.isEmpty) {
         print("NotificationService: Unregister endpoint URL not configured.");
         return;
      }
      print("NotificationService: Unregistering token from backend...");
      try {

        await _apiService.delete('$unregisterEndpointUrl?deviceToken=$_currentToken');
        print("NotificationService: Unregister request sent successfully.");
        _tokenSentThisSession = false;
      } catch (e) {
        print("NotificationService: Exception unregistering token: $e");
      }
  }
}