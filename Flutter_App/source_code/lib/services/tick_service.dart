
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/tick_model.dart';
import 'api_service.dart';
import 'auth_service.dart';
import '../utils/constants.dart';


/// Service gérant les données et les opérations liées aux appareils Tick.
/// Interagit avec [ApiService] pour communiquer avec le backend (Lambdas).
class TickService with ChangeNotifier {
  final ApiService _apiService;
  AuthService _authService; // Référence au service d'authentification

  List<Tick> _ticks = []; // Liste locale des Ticks de l'utilisateur
  bool _isLoading = false; // Indicateur de chargement global pour le service
  String? _error; // Dernier message d'erreur

  // Getters publics
  List<Tick> get ticks => List.unmodifiable(_ticks); // Copie immuable pour l'UI
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Constructeur: Initialise avec les services requis et configure les listeners.
  TickService(this._apiService, this._authService) {
    print("TickService: Initializing...");
    // Écouter les changements d'état d'authentification
    _authService.addListener(_handleAuthChange);
    // Charger les ticks initiaux si l'utilisateur est déjà connecté au démarrage
    if (_authService.isAuthenticated) {
      fetchTicks();
    }
  }

  /// Met à jour la référence [AuthService] (utilisé par ChangeNotifierProxyProvider).
  void updateAuth(AuthService authService) {
    // Éviter mise à jour inutile si la référence est la même
    if (_authService == authService) return;
    print("TickService: Updating AuthService reference.");
    // Supprimer l'ancien listener avant d'ajouter le nouveau
    _authService.removeListener(_handleAuthChange);
    _authService = authService;
    _authService.addListener(_handleAuthChange);
    // Gérer l'état actuel après la mise à jour de la référence
    _handleAuthChange();
  }

  void updateLocalTickStatus(String tickId, TickStatus newStatus) {
    final index = _ticks.indexWhere((t) => t.id == tickId);
    if (index != -1) {
      // Vérifier si le statut change réellement
      if (_ticks[index].status != newStatus) {
        // Crée une copie du Tick avec le nouveau statut
        // Assurer que disableEndTime est remis à null si on réactive
        _ticks[index] = _ticks[index].copyWith(
            status: newStatus,
            // Si le nouveau statut n'est PAS disabled, effacer l'heure de fin
            disableEndTime: newStatus != TickStatus.disabled ? null : _ticks[index].disableEndTime
        );
        print("TickService: Optimistically updated local status for $tickId to $newStatus");
        notifyListeners(); // Notifier l'UI du changement
      }
    } else {
      print("TickService: Cannot update local status, Tick $tickId not found.");
    }
  }



  /// Réagit aux changements d'état d'authentification.
  void _handleAuthChange() {
    print("TickService: Auth state changed. User Authenticated: ${_authService.isAuthenticated}");
    if (_authService.isAuthenticated) {
      // Si l'utilisateur est connecté et que la liste est vide (ou après reconnexion)
      if (_ticks.isEmpty) {
        fetchTicks(); // Charger les Ticks
      }
    } else {
      // Si l'utilisateur est déconnecté, effacer les données locales
      if (_ticks.isNotEmpty || _error != null || _isLoading) {
        print("TickService: Clearing local tick data due to logout.");
        _ticks = [];
        _error = null;
        _isLoading = false; // Stopper tout chargement en cours
        notifyListeners(); // Notifier l'UI de l'effacement
      }
    }
  }

  // --- Méthodes Publiques pour l'UI ---

  /// Récupère la liste des Ticks de l'utilisateur depuis le backend.
  Future<void> fetchTicks() async {
    // Vérifier si l'utilisateur est connecté et si une opération n'est pas déjà en cours
    if (!_checkAuthAndLoading()) return;

    _setLoading(true);
    _clearError(); // Effacer l'erreur précédente

    print("TickService: Fetching ticks from URL: ${ApiConfigURLs.getMyTicksFunctionUrl}");

    try {
      // Appel API via ApiService
      final response = await _apiService.get(ApiConfigURLs.getMyTicksFunctionUrl);

      if (response['success']) {
        final List<dynamic>? tickDataList = response['data'] as List<dynamic>?;
        print("TickService: RAW Tick Data Received: $tickDataList");
        if (tickDataList != null) {
          // Parser les données JSON en objets Tick
          _ticks = tickDataList.map((data) {
            try {
              return Tick.fromJson(data as Map<String, dynamic>);
            } catch (e) {
              print("TickService: Error parsing Tick JSON: $e \nData: $data");
              return null; // Ignorer les données mal formées
            }
          }).whereType<Tick>().toList(); // Filtrer les nulls
          print("TickService: Ticks fetched successfully: ${_ticks.length} ticks loaded.");
        } else {

           print("TickService: Ticks fetch API success but data is null or not a list.");
           _ticks = []; // Assurer que la liste est vide
        }
      } else {
        // L'API a renvoyé une erreur
        _setError(response['error'] ?? ErrorMessages.apiError);
        print("TickService: Error fetching ticks from Lambda: $_error");
      }
    } catch (e) {
      // Erreur de connexion ou autre exception
      print("TickService: Exception fetching ticks: $e");
      _setError(ErrorMessages.connectionFailed);
    } finally {
      _setLoading(false); // Assurer que le chargement s'arrête
    }
  }

  /// Associe un nouveau Tick au compte de l'utilisateur.
  /// [nickname]: Nom donné par l'utilisateur.
  /// [extractedTickId]: ID unique du Tick extrait lors du scan BLE.
  Future<bool> associateTick(String nickname, String extractedTickId) async {
    if (!_checkAuthAndLoading()) return false;

    _setLoading(true);
    _clearError();

    try {
      // Corps de la requête pour la Lambda d'association
      final body = {
        'tickName': nickname,
        'tickId': extractedTickId, // ID unique du matériel
        // L'ID utilisateur est extrait du token JWT par la Lambda
      };

      print("TickService: Associating tick via URL: ${ApiConfigURLs.associateTickFunctionUrl}");
      final response = await _apiService.post(ApiConfigURLs.associateTickFunctionUrl, body);

      if (response['success']) {
        print("TickService: Tick associated successfully via Lambda. Response: ${response['data']}");

        // 1. Parser les données du nouveau Tick retournées par la Lambda
        final dynamic newTickData = response['data'];
        if (newTickData is Map<String, dynamic>) {
          try {
            final newTick = Tick.fromJson(newTickData);
            // 2. Ajouter le nouveau Tick à la liste locale
            _ticks.add(newTick);

             _ticks.sort((a, b) => a.name.compareTo(b.name));
            print("TickService: New tick '${newTick.name}' added locally.");
            _setLoading(false); // Mettre fin au chargement
            notifyListeners(); // Notifier l'UI de l'ajout
            return true;
          } catch (e) {
             print("TickService: Error parsing new tick data after association: $e \nData: $newTickData");
             _setError("Erreur lors de la lecture des données du nouveau Tick.");
             _setLoading(false);
             return false; // Échec du parsing des données retournées
          }
        } else {
           print("TickService: Association API success but returned data is not a valid Tick map. Response: $newTickData");

           _setError("Réponse invalide du serveur après association.");
           _setLoading(false);
           return false;
        }

      } else {
        _setError(response['error'] ?? ErrorMessages.associationFailed);
        print("TickService: Failed to associate tick. API Error: $_error");
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("TickService: Exception associating tick: $e");
      _setError(ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> temporaryDisableTick(String tickId, Duration duration) async {
    if (!_checkAuthAndLoading()) return false;
    if (duration.inMinutes <= 0) {
      _setError("La durée de désactivation doit être positive.");
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Vérifier si l'URL est configurée
      if (ApiConfigURLs.disableTickFunctionUrl.isEmpty) {
        throw Exception("Temporary Disable URL not configured in constants.dart");
      }

      // Préparer le corps de la requête attendu par la Lambda
      final body = {
        'tickId': tickId,
        'duration': duration.inMinutes.toString(), // Envoyer la durée en minutes comme chaîne
      };
      print("TickService: Calling temporaryDisable Function URL: ${ApiConfigURLs.disableTickFunctionUrl}");

      // Appeler ApiService.post
      final response = await _apiService.post(ApiConfigURLs.disableTickFunctionUrl, body);

      if (response['success']) {
        DateTime? parsedEndTime;
        final dynamic responseData = response['data'];

        if (responseData is Map<String, dynamic>) {
          String? endTimeString = responseData['disableEndTime'] as String?;
          if (endTimeString != null) {
            // Essayer de parser directement
            parsedEndTime = DateTime.tryParse(endTimeString);


            if (parsedEndTime == null && endTimeString.endsWith('Z')) {
              print("TickService: Retrying parsing disableEndTime after removing trailing 'Z'. Original: $endTimeString");
              endTimeString = endTimeString.substring(0, endTimeString.length - 1);
              parsedEndTime = DateTime.tryParse(endTimeString);
            }
          }
        }

        if (parsedEndTime == null) {
          print("TickService WARN: Could not parse disableEndTime from API response. Response Data: $responseData");

        } else {
          print("TickService INFO: Successfully parsed disableEndTime: $parsedEndTime");
        }

// Mettre à jour l'état local du Tick avec le nouveau statut ET l'heure de fin parsée
        final index = _ticks.indexWhere((t) => t.id == tickId);
        if (index != -1) {
          _ticks[index] = _ticks[index].copyWith(
            status: TickStatus.disabled,
            disableEndTime: parsedEndTime,
          );
          print("TickService: Updated local Tick $tickId with status: disabled, endTime: $parsedEndTime");
          notifyListeners(); // Notifier l'UI
        }


        _setLoading(false);
        return true;
      } else {
        _setError((response['error'] as String?) ?? "Erreur lors de la demande de désactivation");
        print("TickService: Temporary disable failed. API Error: $_error");
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("TickService: Exception during temporary disable request for $tickId: $e");
      _setError(e is Exception ? e.toString() : ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }

  Future<bool> disableTickPermanently(String tickId) async {
    if (!_checkAuthAndLoading()) return false;
    _setLoading(true);
    _clearError();

    try {
      if (ApiConfigURLs.disableTickFunctionUrl.isEmpty) { // Réutilise l'URL disable/temp
        throw Exception("Temporary Disable URL not configured in constants.dart");
      }

      final body = {'tickId': tickId};
      print("TickService: Calling temporaryDisable Function URL for PERMANENT disable: ${ApiConfigURLs.disableTickFunctionUrl}");
      final response = await _apiService.post(ApiConfigURLs.disableTickFunctionUrl, body);

      if (response['success']) {
        print("TickService: Permanent disable command sent successfully for $tickId.");
        final index = _ticks.indexWhere((t) => t.id == tickId);
        if (index != -1) {
          _ticks[index] = _ticks[index].copyWith(status: TickStatus.disabled, disableEndTime: null); // <-- Mettre à null
          notifyListeners();
        }
        _setLoading(false);
        return true;
      } else {
        _setError((response['error'] as String?) ?? "Erreur lors de la désactivation");
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("TickService: Exception during permanent disable request for $tickId: $e");
      _setError(e is Exception ? e.toString() : ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }

  /// Demande la réactivation d'un Tick.
  Future<bool> reactivateTick(String tickId) async {
    if (!_checkAuthAndLoading()) return false;
    _setLoading(true);
    _clearError();

    try {
      if (ApiConfigURLs.reactivateTickFunctionUrl.isEmpty) {
        throw Exception("Reactivate Tick URL not configured in constants.dart");
      }
      final body = {'tickId': tickId};
      print("TickService: Calling reactivateTick Function URL: ${ApiConfigURLs.reactivateTickFunctionUrl}");
      final response = await _apiService.post(ApiConfigURLs.reactivateTickFunctionUrl, body);

      if (response['success']) {
        print("TickService: Reactivate command sent successfully for $tickId.");
        final indexReactivate = _ticks.indexWhere((t) => t.id == tickId);
        if (indexReactivate != -1) {
          _ticks[indexReactivate] = _ticks[indexReactivate].copyWith(status: TickStatus.active, disableEndTime: null); // <-- Mettre à null
          notifyListeners();
        }
        _setLoading(false);
        return true;
      } else {
        _setError((response['error'] as String?) ?? "Erreur lors de la réactivation");
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("TickService: Exception during reactivate request for $tickId: $e");
      _setError(e is Exception ? e.toString() : ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }



  /// Récupère l'historique d'un Tick spécifique.
  /// Retourne la réponse brute de l'API pour que l'UI (HistoryPage) la parse.
  Future<Map<String, dynamic>> getTickHistory(String tickId) async {
    if (!_authService.isAuthenticated) {
      return {'success': false, 'error': "Utilisateur non authentifié"};
    }

    try {
      if (ApiConfigURLs.getTickHistoryFunctionUrl.isEmpty) throw Exception("Get Tick History URL not configured");
       final urlWithParam = Uri.parse(ApiConfigURLs.getTickHistoryFunctionUrl).replace(
          queryParameters: {'tickId': tickId}
       ).toString();
       print("TickService: Getting history for $tickId from URL: $urlWithParam");
       // Appeler l'API
       final response = await _apiService.get(urlWithParam);
       return response; // Retourner la réponse brute (contient success/data ou success/error)
    } catch (e) {
        print("TickService: Exception getting tick history: $e");
        return {'success': false, 'error': e is Exception ? e.toString() : ErrorMessages.connectionFailed};
    }
  }


  /// Demande une mise à jour de localisation pour un Tick spécifique.
  /// Retourne `true` si la *demande* a été envoyée avec succès au backend.
  Future<bool> requestTickLocation(String tickId) async {
    if (!_checkAuthAndLoading()) return false;

    _setLoading(true);
    _clearError();

    try {
      if (ApiConfigURLs.requestLocationFunctionUrl.isEmpty) throw Exception("Request Location URL not configured");
      final body = {'tickId': tickId};
      print("TickService: Requesting location for $tickId via URL: ${ApiConfigURLs.requestLocationFunctionUrl}");
      final response = await _apiService.post(ApiConfigURLs.requestLocationFunctionUrl, body);

      if (response['success']) {
        print("TickService: Location request sent successfully for $tickId. Lambda response: ${response['data']}");
        // La position réelle sera mise à jour via un autre mécanisme
        _setLoading(false);
        return true;
      } else {
        _setError(response['error'] ?? "Erreur lors de la demande de localisation");
        print("TickService: Failed location request for $tickId. API Error: $_error");
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("TickService: Exception requesting location for $tickId: $e");
      _setError(e is Exception ? e.toString() : ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }

  /// Demande à faire sonner un Tick avec le son sélectionné.
  Future<bool> ringTick(String tickId) async {
    if (!_checkAuthAndLoading()) return false;

    // Récupérer le Tick pour obtenir le son sélectionné
    final tick = getTickById(tickId);
    if (tick == null) {
      _setError("Tick non trouvé pour la sonnerie.");
      notifyListeners();
      return false;
    }
    // Utiliser le son sélectionné ou un son par défaut (ex: 1)
    final int soundIndex = tick.selectedAlarmSoundIndex ?? 1;

    _setLoading(true);
    _clearError();

    try {
       if (ApiConfigURLs.ringTickFunctionUrl.isEmpty || ApiConfigURLs.ringTickFunctionUrl.startsWith('YOUR_')) {
           throw Exception("Ring Tick URL not configured");
       }
       // Corps de la requête incluant l'index du son
       final body = {
           'tickId': tickId,
           'soundIndex': soundIndex, // Utilise la valeur récupérée ou par défaut
       };
       print("TickService: Ringing tick $tickId with sound $soundIndex via URL: ${ApiConfigURLs.ringTickFunctionUrl}");

       // Appel API Réel
       final response = await _apiService.post(ApiConfigURLs.ringTickFunctionUrl, body);

       if ((response['success'] as bool? ?? false)) {
          print("TickService: Ring command sent for $tickId (Sound $soundIndex). Response: ${response['data']}");
          _setLoading(false);
          // Message succès affiché par l'UI (MapPage) si besoin
          return true;
       } else {
          _setError((response['error'] as String?) ?? AppTexts.ringingTickError);
          _setLoading(false);
          return false;
       }
    } catch (e) {
      print("TickService: Exception ringing tick $tickId: $e");
      _setError(e is Exception ? e.toString() : AppTexts.ringingTickError);
      _setLoading(false);
      return false;
    }
  }

  /// Met à jour les paramètres d'un Tick (nom et/ou index du son d'alarme).
  Future<bool> updateTickSettings(
      String tickId, {
      String? name, // Nom optionnel
      int? alarmSoundIndex, // Index du son optionnel
  }) async {
    // Vérifier l'authentification
    if (!_authService.isAuthenticated) {
      print("TickService: Operation prevented. User not authenticated.");
      _setError(ErrorMessages.unauthorizedAccess);
      notifyListeners();
      return false;
    }
    // Vérifier qu'au moins un paramètre est fourni
    if (name == null && alarmSoundIndex == null) {
      print("TickService: updateTickSettings called without any parameters to update.");
      return true; // Aucune mise à jour nécessaire
    }

    // Valider le nom si fourni
    if (name != null && name.trim().isEmpty) {
      _setError("Le nom ne peut pas être vide.");
      notifyListeners();
      return false;
    }
    // Valider l'index du son si fourni (doit exister dans AppSounds)
    if (alarmSoundIndex != null && !AppSounds.alarmSounds.containsKey(alarmSoundIndex)) {
      _setError("Son sélectionné invalide.");
      notifyListeners();
      return false;
    }

    // Trouver l'index du Tick dans la liste locale
    final index = _ticks.indexWhere((t) => t.id == tickId);
    if (index == -1) {
      print("TickService: Cannot update settings, Tick $tickId not found locally.");
      _setError("Tick non trouvé.");
      notifyListeners();
      return false;
    }

    // Cas 1: Seulement l'index du son est mis à jour (PAS D'APPEL API)
    if (name == null && alarmSoundIndex != null) {
      print("TickService: Updating ONLY local alarm sound index for $tickId to $alarmSoundIndex.");
      // Créer une copie mise à jour SANS appel API
      _ticks[index] = _ticks[index].copyWith(selectedAlarmSoundIndex: alarmSoundIndex);
      notifyListeners(); // Notifier l'UI du changement local
      _clearError(); // Effacer les erreurs précédentes
      return true; // Succès de la mise à jour locale
    }

    // Cas 2: Le nom (et potentiellement l'index du son) est mis à jour (APPEL API REQUIS)
    if (_isLoading) { // Vérifier si déjà en cours (pour éviter double appel API)
        print("TickService: Operation skipped, another operation is in progress.");
        return false;
    }
    _setLoading(true);
    _clearError();

    try {
      if (ApiConfigURLs.updateTickSettingsFunctionUrl.isEmpty || ApiConfigURLs.updateTickSettingsFunctionUrl.startsWith('YOUR_')) {
        throw Exception("Update Tick Settings URL not configured in constants.dart");
      }

      // Préparer le corps de la requête - Inclure tous les champs modifiés
      final body = <String, dynamic>{'tickId': tickId};
      if (name != null) body['name'] = name.trim();
      // Inclure l'index du son DANS L'APPEL API si les deux sont fournis
      if (name != null && alarmSoundIndex != null) body['alarmSoundIndex'] = alarmSoundIndex;
      // Si seulement le nom est fourni, 'alarmSoundIndex' ne sera pas dans le body

      print("TickService: Updating settings (API) for $tickId via URL: ${ApiConfigURLs.updateTickSettingsFunctionUrl} with body: $body");

      // Appel API (PUT ou POST selon votre Lambda)
      final response = await _apiService.put(ApiConfigURLs.updateTickSettingsFunctionUrl, body);

      if (response['success']) {
        print("TickService: Tick settings updated successfully (API) for $tickId. Response: ${response['data']}");

        // Mettre à jour l'objet Tick localement avec les nouvelles valeurs
        // Il est préférable de lire les valeurs retournées par l'API si elles existent
        final updatedNameFromApi = response['data']?['name'] as String? ?? name?.trim();
        // L'API ne retourne peut-être pas l'index du son si seul le nom est changé,
        // donc on prend la valeur passée à la fonction si le nom était modifié.
        final finalAlarmIndex = (name != null && alarmSoundIndex != null)
                                ? (response['data']?['alarmSoundIndex'] as int? ?? alarmSoundIndex)
                                : _ticks[index].selectedAlarmSoundIndex;

        _ticks[index] = _ticks[index].copyWith(
            name: updatedNameFromApi,
            selectedAlarmSoundIndex: finalAlarmIndex,
        );
        notifyListeners();
        _setLoading(false);
        return true;

      } else {
        _setError((response['error'] as String?) ?? AppTexts.updateError);
        print("TickService: Update tick settings failed (API). API Error: $_error");
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("TickService: Exception updating tick settings (API) for $tickId: $e");
      _setError(e is Exception ? e.toString() : ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }


  /// Désassocie un Tick du compte utilisateur.
  /// Retourne `true` si l'opération a réussi côté backend et localement.
  Future<bool> unlinkTick(String tickId) async {
    if (!_checkAuthAndLoading()) return false;
    _setLoading(true);
    _clearError();

    try {
      if (ApiConfigURLs.removeTickFunctionUrl.isEmpty) {
          throw Exception("Remove Tick URL not configured");
      }

      // Construire l'URL avec le paramètre tickId pour la requête DELETE
      final urlWithParam = Uri.parse(ApiConfigURLs.removeTickFunctionUrl).replace(
          queryParameters: {'tickId': tickId}
      ).toString();
      print("TickService: Unlinking tick $tickId via DELETE URL: $urlWithParam");

      // Appel API via ApiService.delete
      final response = await _apiService.delete(urlWithParam);

      if (response['success']) {
        print("TickService: Tick unlinked successfully via Lambda: $tickId");
        // Supprimer le Tick de la liste locale immédiatement
        final initialLength = _ticks.length;
        _ticks.removeWhere((tick) => tick.id == tickId);
        // Notifier seulement si un élément a effectivement été supprimé
        if (_ticks.length < initialLength) {
          notifyListeners();
        } else {
          print("TickService: WARNING - Unlinked tick $tickId was not found in local list.");
        }
        _setLoading(false);
        return true;
      } else {
        // Gérer l'erreur renvoyée par la Lambda
        _setError(response['error'] ?? "Erreur lors de la désassociation");
        print("TickService: Failed to unlink tick $tickId. API Error: $_error");
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // Gérer les exceptions (connexion, parsing URL, etc.)
      print("TickService: Exception unlinking tick $tickId: $e");
      _setError(e is Exception ? e.toString() : ErrorMessages.connectionFailed);
      _setLoading(false);
      return false;
    }
  }


  // --- Méthodes Utilitaires Internes ---

  /// Retourne un Tick de la liste locale par son ID, ou `null` si non trouvé.
  Tick? getTickById(String id) {
    try {
      // Utilise firstWhere pour trouver l'élément. Lance une exception si non trouvé.
      return _ticks.firstWhere((tick) => tick.id == id);
    } catch (e) {
      // L'exception StateError est lancée par firstWhere si aucun élément ne correspond.
      return null; // Retourne null si non trouvé
    }

  }

  /// Met à jour les données d'un Tick dans la liste locale.
  /// Utile pour appliquer des mises à jour reçues (ex: via MQTT ou après une action).
  void updateTickDataLocally(Tick updatedTick) {
    final index = _ticks.indexWhere((t) => t.id == updatedTick.id);
    if (index != -1) {
      // Vérifier si les données ont réellement changé pour éviter notif inutile
      if (_ticks[index] != updatedTick) {
         _ticks[index] = updatedTick;
         print("TickService: Tick data updated locally for ${updatedTick.id}");
         notifyListeners();
      }
    } else {
      // Si le Tick n'existait pas (cas rare, ex: reçu via MQTT avant fetch), l'ajouter
      print("TickService: Adding new tick locally ${updatedTick.id} via updateTickDataLocally.");
      _ticks.add(updatedTick);

      notifyListeners();
    }
  }

  /// Vérifie si l'utilisateur est authentifié et si une opération est déjà en cours.
  /// Retourne `false` et gère l'erreur si l'une des conditions n'est pas remplie.
  bool _checkAuthAndLoading() {
    if (!_authService.isAuthenticated) {
      print("TickService: Operation prevented. User not authenticated.");
      _setError(ErrorMessages.unauthorizedAccess); // Utiliser une erreur appropriée
      notifyListeners(); // Notifier l'erreur
      return false;
    }
    if (_isLoading) {
      print("TickService: Operation skipped, another operation is in progress.");
      // Ne pas définir d'erreur ici, c'est juste une opération ignorée
      return false;
    }
    return true;
  }

  /// Met à jour l'état de chargement et notifie les listeners.
  void _setLoading(bool loading) {
    if (_isLoading == loading) return; // Éviter notifications inutiles
    _isLoading = loading;
    notifyListeners();
  }

  /// Définit un message d'erreur et notifie les listeners.
void _setError(String? message) {
  if (_error == message) return;
  _error = message;
  notifyListeners();
}

  /// Efface le message d'erreur actuel et notifie si nécessaire.
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners(); // Notifier seulement si l'erreur est effacée
    }
  }

  /// Libère les ressources (listener d'authentification).
  @override
  void dispose() {
    print("TickService: Disposing...");
    _authService.removeListener(_handleAuthChange); // Très important !
    super.dispose();
  }
}