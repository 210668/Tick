import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../utils/constants.dart';



class ApiService {


  Future<String?> getAuthorizationToken() async {
    print("ApiService: Attempting to get Authorization Token...");
    try {

      final session = await Amplify.Auth.fetchAuthSession(
          options: const FetchAuthSessionOptions(forceRefresh: true)
      );
      print("ApiService: Fetched Auth Session. isSignedIn: ${session.isSignedIn}");

      if (session.isSignedIn) {
        final cognitoSession = session as CognitoAuthSession;
        final tokens = cognitoSession.userPoolTokensResult.valueOrNull; // Utiliser valueOrNull pour sécurité

        if (tokens == null) {
            print("ApiService WARN: Cognito User Pool Tokens are null.");
            return null;
        }

        final idToken = tokens.idToken.raw;
        final accessToken = tokens.accessToken.raw;

        print("ApiService: ID Token received: ${idToken != null ? '${idToken.substring(0, 10)}...' : 'null'}");
        print("ApiService: Access Token received: ${accessToken != null ? '${accessToken.substring(0, 10)}...' : 'null'}");

        if (idToken == null) {
            print("ApiService ERROR: ID Token is null within the tokens result.");
            return null;
        }

        return idToken; // Retourner l'ID token

      } else {
        print("ApiService: User is not signed in according to fetchAuthSession.");
        return null;
      }
    } on AuthException catch (e) {
      print("ApiService ERROR: AuthException fetching auth session for token: ${e.runtimeType} - ${e.message} ${e.underlyingException}");
      if (e is SignedOutException) {
         print("ApiService: Caught SignedOutException.");
         return null;
      }
      // Logguer d'autres types spécifiques si besoin
      return null;
    } catch (e, stacktrace) {
      print("ApiService ERROR: Unexpected error fetching auth session: $e");
      print(stacktrace);
      return null;
    }
  }


  /// Construit les en-têtes HTTP standards pour les requêtes API.
  /// Ajout de logs pour le débogage.
  Future<Map<String, String>> _buildHeaders({Map<String, String>? customHeaders}) async {
    final token = await getAuthorizationToken(); // Appelle la méthode mise à jour
    print("ApiService (_buildHeaders): Token retrieved: ${token != null ? '${token.substring(0, 10)}...' : 'null'}");

    final Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',

      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    print("ApiService (_buildHeaders): Final headers being used (Authorization might be redacted): $headers");
    // Pour un débogage plus poussé, logguer spécifiquement si l'auth header est ajouté :
    if (headers.containsKey('Authorization')) {
       print("ApiService (_buildHeaders): Authorization header WAS added.");
    } else {
       print("ApiService (_buildHeaders): Authorization header WAS NOT added (token was likely null).");
    }
    return headers;
  }


  /// Effectue une requête GET vers une URL de fonction Lambda spécifiée.
  ///
  /// [functionUrl]: L'URL complète de la fonction Lambda.
  /// [headers]: En-têtes HTTP personnalisés optionnels.
  /// Retourne une Map: `{'success': true, 'data': <données>}` ou `{'success': false, 'error': <message>}`.
  Future<Map<String, dynamic>> get(String functionUrl, {Map<String, String>? headers}) async {
    // Vérifier si l'URL est vide (sécurité)
    if (functionUrl.isEmpty) {
       print('ApiService GET Error: Function URL is empty.');
       return {'success': false, 'error': ErrorMessages.unknownError};
    }

    final url = Uri.parse(functionUrl);
    final requestHeaders = await _buildHeaders(customHeaders: headers);

    safePrint('API GET Request URL: $url'); // Utilise safePrint pour éviter log excessif en release


    try {
      final response = await http.get(
        url,
        headers: requestHeaders,
      ).timeout(AppDurations.apiTimeout); // Utiliser timeout constant

      return _handleResponse(response, url.toString()); // Passer l'URL pour le log d'erreur

    } on TimeoutException catch (_) {
        print('API GET Timeout for $url');
        return {'success': false, 'error': ErrorMessages.connectionFailed};
    } on http.ClientException catch (e) { // Erreur de connexion/socket
        print('API GET ClientException for $url: $e');
        return {'success': false, 'error': ErrorMessages.connectionFailed};
    } catch (e) { // Autres erreurs (parsing URL, etc.)
      print('API GET Error for $url: $e');
      return {'success': false, 'error': ErrorMessages.unknownError};
    }
  }

  /// Effectue une requête POST vers une URL de fonction Lambda spécifiée.
  ///
  /// [functionUrl]: L'URL complète de la fonction Lambda.
  /// [body]: Le corps de la requête (sera encodé en JSON).
  /// [headers]: En-têtes HTTP personnalisés optionnels.
  /// Retourne une Map: `{'success': true, 'data': <données>}` ou `{'success': false, 'error': <message>}`.
  Future<Map<String, dynamic>> post(String functionUrl, Map<String, dynamic> body, {Map<String, String>? headers}) async {
     if (functionUrl.isEmpty) {
       print('ApiService POST Error: Function URL is empty.');
       return {'success': false, 'error': ErrorMessages.unknownError};
     }

     final url = Uri.parse(functionUrl);
     final requestHeaders = await _buildHeaders(customHeaders: headers);
     final requestBody = jsonEncode(body); // Encoder le corps en JSON

     safePrint('API POST Request URL: $url');

     safePrint('API POST Body: $requestBody'); // Log du corps

     try {
       final response = await http.post(
         url,
         headers: requestHeaders,
         body: requestBody,
       ).timeout(AppDurations.apiTimeout);

       return _handleResponse(response, url.toString());

     } on TimeoutException catch (_) {
         print('API POST Timeout for $url');
         return {'success': false, 'error': ErrorMessages.connectionFailed};
     } on http.ClientException catch (e) {
         print('API POST ClientException for $url: $e');
         return {'success': false, 'error': ErrorMessages.connectionFailed};
     } catch (e) {
       print('API POST Error for $url: $e');
       return {'success': false, 'error': ErrorMessages.unknownError};
     }
  }

  /// Effectue une requête PUT vers une URL de fonction Lambda spécifiée.
  ///
  /// [functionUrl]: L'URL complète de la fonction Lambda.
  /// [body]: Le corps de la requête (sera encodé en JSON).
  /// [headers]: En-têtes HTTP personnalisés optionnels.
  /// Retourne une Map: `{'success': true, 'data': <données>}` ou `{'success': false, 'error': <message>}`.
  Future<Map<String, dynamic>> put(String functionUrl, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    if (functionUrl.isEmpty) {
      print('ApiService PUT Error: Function URL is empty.');
      return {'success': false, 'error': ErrorMessages.unknownError};
    }

    final url = Uri.parse(functionUrl);
    final requestHeaders = await _buildHeaders(customHeaders: headers);
    final requestBody = jsonEncode(body);

    safePrint('API PUT Request URL: $url');

    safePrint('API PUT Body: $requestBody');

    try {
      final response = await http.put(
        url,
        headers: requestHeaders,
        body: requestBody,
      ).timeout(AppDurations.apiTimeout);

      return _handleResponse(response, url.toString());

    } on TimeoutException catch (_) {
        print('API PUT Timeout for $url');
        return {'success': false, 'error': ErrorMessages.connectionFailed};
    } on http.ClientException catch (e) {
        print('API PUT ClientException for $url: $e');
        return {'success': false, 'error': ErrorMessages.connectionFailed};
    } catch (e) {
      print('API PUT Error for $url: $e');
      return {'success': false, 'error': ErrorMessages.unknownError};
    }
  }

  /// Effectue une requête DELETE vers une URL de fonction Lambda spécifiée.
  /// Note: Le corps est généralement ignoré pour DELETE. Passer les ID via l'URL (query params).
  ///
  /// [functionUrl]: L'URL complète de la fonction Lambda (peut inclure des query params).
  /// [headers]: En-têtes HTTP personnalisés optionnels.
  /// Retourne une Map: `{'success': true, 'data': <données>}` ou `{'success': false, 'error': <message>}`.
  Future<Map<String, dynamic>> delete(String functionUrl, {Map<String, String>? headers}) async {
     if (functionUrl.isEmpty) {
       print('ApiService DELETE Error: Function URL is empty.');
       return {'success': false, 'error': ErrorMessages.unknownError};
     }

     final url = Uri.parse(functionUrl);
     final requestHeaders = await _buildHeaders(customHeaders: headers);

     safePrint('API DELETE Request URL: $url');


     try {
       final response = await http.delete(
         url,
         headers: requestHeaders,
       ).timeout(AppDurations.apiTimeout);

       return _handleResponse(response, url.toString());

     } on TimeoutException catch (_) {
         print('API DELETE Timeout for $url');
         return {'success': false, 'error': ErrorMessages.connectionFailed};
     } on http.ClientException catch (e) {
         print('API DELETE ClientException for $url: $e');
         return {'success': false, 'error': ErrorMessages.connectionFailed};
     } catch (e) {
       print('API DELETE Error for $url: $e');
       return {'success': false, 'error': ErrorMessages.unknownError};
     }
  }

  /// Gère la réponse HTTP, parse le JSON et retourne une Map standardisée.
  Map<String, dynamic> _handleResponse(http.Response response, String requestUrl) {
    final statusCode = response.statusCode;
    final responseBody = response.body; // Corps de la réponse brute

    safePrint('API Response Status Code: $statusCode for $requestUrl');
    // Log du corps complet seulement en debug, peut contenir des infos sensibles
    // safePrint('API Response Body: $responseBody');

    if (statusCode >= 200 && statusCode < 300) { // Succès HTTP
      try {

        final dynamic decodedBody = responseBody.isNotEmpty ? jsonDecode(responseBody) : {};


        // On gère le cas où 'data' manque ou si la réponse est directement les données.
        final dynamic data = (decodedBody is Map && decodedBody.containsKey('data'))
                             ? decodedBody['data']
                             : decodedBody;

        // Retourner succès avec les données extraites
        return {'success': true, 'data': data};

      } catch (e) { // Erreur de parsing JSON
        print("API Response JSON Decode Error (Status: $statusCode) for $requestUrl: $e \nBody: $responseBody");
        return {'success': false, 'error': 'Format de réponse serveur invalide.'};
      }
    } else { // Erreur HTTP (4xx, 5xx)
      String errorMessage = ErrorMessages.unknownError; // Message par défaut
      try {
        // Tenter de lire un message d'erreur depuis le corps JSON
        final decodedBody = jsonDecode(responseBody);
        if (decodedBody is Map<String, dynamic>) {
          // Chercher des clés communes pour les messages d'erreur
          errorMessage = decodedBody['error'] ?? decodedBody['message'] ?? decodedBody['detail'] ?? errorMessage;
        } else if (decodedBody is String && decodedBody.isNotEmpty) {
          errorMessage = decodedBody; // Si le corps est juste une chaîne d'erreur
        }
      } catch (e) {
        // Si le corps n'est pas du JSON valide, garder le message par défaut ou utiliser le corps brut (si court)
        print("API Response Error Body Decode Failed (Status: $statusCode) for $requestUrl: $e");
        if (responseBody.isNotEmpty && responseBody.length < 100) {
           errorMessage = responseBody; // Utiliser le corps brut si court et non JSON
        }
      }

      // Raffiner le message d'erreur basé sur le code de statut HTTP si pas déjà spécifique
      if (errorMessage == ErrorMessages.unknownError || errorMessage.isEmpty) {
        switch (statusCode) {
           case 400: errorMessage = 'Requête invalide.'; break;
           case 401: errorMessage = 'Authentification requise ou invalide.'; break; // Non autorisé (token)
           case 403: errorMessage = 'Accès refusé.'; break; // Autorisé mais interdit (permissions IAM?)
           case 404: errorMessage = 'Ressource non trouvée.'; break; // Fonction Lambda introuvable
           case 500:
           case 502:
           case 503:
           case 504: errorMessage = ErrorMessages.connectionFailed; break; // Erreurs serveur/Lambda
           default: errorMessage = 'Erreur serveur ($statusCode)';
        }
      }
      print("API Error Response (Status $statusCode) for $requestUrl: $errorMessage");
      return {'success': false, 'error': errorMessage};
    }
  }
}