import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:location/location.dart' as loc;
import 'package:flutter/services.dart';
import '../utils/constants.dart';

// Alias pour les types d'état et de permission pour améliorer la lisibilité
typedef BluetoothState = blue.BluetoothAdapterState;
typedef LocationPermissionStatus = loc.PermissionStatus;
typedef HandlerPermissionStatus = ph.PermissionStatus;

/// Service gérant la logique Bluetooth Low Energy (BLE), y compris l'état de l'adaptateur,
/// la gestion des permissions et le scan des appareils Tick.
class BluetoothService with ChangeNotifier {
  // Service de localisation (utilisé pour vérifier/demander service et permission)
  final loc.Location _location = loc.Location();

  // État interne du service
  BluetoothState _state = BluetoothState.unknown;
  bool _isScanning = false;
  bool _isInitialized = false;
  String? _scanError; // Stocke la dernière erreur liée au scan ou aux permissions
  blue.ScanResult? _foundTickResult; // Dernier résultat de scan correspondant à un Tick
  String? _extractedTickId; // ID extrait du nom du Tick trouvé

  // Abonnements aux streams FlutterBluePlus (gérés en interne)
  StreamSubscription<BluetoothState>? _adapterStateSubscription;
  StreamSubscription<List<blue.ScanResult>>? _scanResultsSubscription;

  // Getters publics pour accéder à l'état
  BluetoothState get state => _state;
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  String? get scanError => _scanError;
  blue.ScanResult? get foundTickResult => _foundTickResult;
  String? get extractedTickId => _extractedTickId;
  /// Indique si le BLE est supporté sur la plateforme actuelle.
  bool get isBleSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  // --- Initialisation ---

  BluetoothService() {
    // L'initialisation réelle est déclenchée après la création via Provider
  }

  /// Initialise le service Bluetooth. Doit être appelé une fois.
  /// Configure l'écoute de l'état de l'adaptateur et met à jour l'état initial.
  Future<void> initialize() async {
    // Éviter ré-initialisation ou initialisation sur plateforme non supportée
    if (_isInitialized) return;
    if (!isBleSupported) {
      print("BluetoothService: BLE not supported. Skipping initialization.");
      _state = BluetoothState.unavailable;
      _isInitialized = true;
      notifyListeners(); // Notifier l'état 'unavailable'
      return;
    }
    print("BluetoothService: Initializing...");

    // Écouter les changements d'état de l'adaptateur Bluetooth
    _adapterStateSubscription = blue.FlutterBluePlus.adapterState.listen(
      _onAdapterStateChanged, // Callback défini ci-dessous
      onError: (e) => print("BluetoothService: Error listening to adapter state: $e"),
    );

    // Obtenir l'état initial de manière asynchrone
    await _updateInitialAdapterState();

    _isInitialized = true;
    print("BluetoothService: Initialization complete. Initial State: $_state");
  }

  /// Callback appelé lorsque l'état de l'adaptateur Bluetooth change.
  void _onAdapterStateChanged(BluetoothState newState) {
    print("BluetoothService: Adapter state changed to -> $newState");

    // Gérer le cas où les permissions sont refusées puis le BT éteint
    // On veut conserver l'état 'unauthorized' comme prioritaire.
    if (_state == BluetoothState.unauthorized && newState == BluetoothState.off) {
       print("BluetoothService: Keeping state as 'unauthorized' despite BT turning off.");

    } else {
      _state = newState;
    }

    // Si le Bluetooth est éteint, arrêter toute opération en cours
    if (newState != BluetoothState.on) {
      if (_isScanning) {
        stopScan(); // Arrête le scan et met _isScanning à false
      }
       // Effacer les résultats précédents si l'adaptateur n'est plus prêt
      _resetScanResultState(notify: false); // Ne pas notifier ici, notifyListeners() est appelé à la fin
    }
    notifyListeners(); // Notifier l'UI du changement d'état
  }

  /// Met à jour l'_state interne avec le premier état stable de l'adaptateur.
  Future<void> _updateInitialAdapterState() async {
    try {
      // Attendre un état stable (ni unknown, ni turningOn/Off)
      _state = await _getFirstStableAdapterState();
      print("BluetoothService: Initial adapter state updated to: $_state");
      notifyListeners();
    } catch (e) {
      print("BluetoothService: Error getting initial adapter state: $e");
      _state = BluetoothState.unknown; // État inconnu en cas d'erreur
      notifyListeners();
    }
  }

  /// Attend et retourne le premier état stable de l'adaptateur Bluetooth.
  /// Évite de démarrer des opérations pendant que le BT s'allume/s'éteint.
  Future<BluetoothState> _getFirstStableAdapterState({Duration timeout = const Duration(seconds: 5)}) async {
    // Si l'état actuel est déjà stable, le retourner immédiatement
     final currentState = blue.FlutterBluePlus.adapterStateNow; // Lire état synchrone
     if (currentState != BluetoothState.unknown &&
         currentState != BluetoothState.turningOn &&
         currentState != BluetoothState.turningOff) {
        return currentState;
     }
     print("BluetoothService: Waiting for stable adapter state...");

    // Attendre la prochaine émission du stream qui correspond à un état stable
    try {
       return await blue.FlutterBluePlus.adapterState
           .where((state) => state != BluetoothState.unknown &&
                             state != BluetoothState.turningOn &&
                             state != BluetoothState.turningOff)
           .first // Prendre le premier état stable reçu
           .timeout(timeout); // Appliquer un timeout
    } on TimeoutException {
       print("BluetoothService: Timeout waiting for stable adapter state. Returning current: $currentState");
       return currentState; // Retourner l'état actuel (potentiellement instable) après timeout
    } catch (e) {
       print("BluetoothService: Error waiting for stable adapter state: $e. Returning current: $currentState");
        return currentState; // Retourner l'état actuel en cas d'erreur
    }
  }


  /// Tente d'activer le Bluetooth via l'API système (Android uniquement).
  /// Retourne `true` si la tentative a été faite, `false` sinon.
  Future<bool> attemptToEnableBluetooth() async {
    if (!isBleSupported || !Platform.isAndroid) {
      print("BluetoothService: attemptToEnableBluetooth only available on Android.");
      return false;
    }
    if (_state == BluetoothState.on) {
      print("BluetoothService: Bluetooth already ON.");
      return true; // Déjà allumé
    }

    print("BluetoothService: Attempting to turn Bluetooth ON via system API...");
    try {
      // Utilise FlutterBluePlus pour demander l'activation à l'OS
      await blue.FlutterBluePlus.turnOn();
      print("BluetoothService: System request to turn ON Bluetooth sent.");
      // Le listener _onAdapterStateChanged mettra à jour l'état réel.
      // On retourne true pour indiquer que la demande a été faite.
      return true;
    } catch (e) {
      // L'utilisateur a peut-être refusé la popup système
      print("BluetoothService: Failed to request Bluetooth turn ON: $e");
      _scanError = "Impossible d'activer le Bluetooth automatiquement."; // Message pour l'UI
      notifyListeners();
      return false;
    }
  }

  // --- Gestion des Permissions ---

  /// Vérifie et demande toutes les permissions requises pour le scan BLE.
  /// Met à jour `_scanError` et `_state` si des permissions sont manquantes.
  /// Retourne `true` si toutes les permissions sont accordées et le service de localisation activé.
  Future<bool> checkAndRequestRequiredPermissions() async {
    if (!isBleSupported) return true; // Pas de permissions si non supporté
    print("BluetoothService: Checking and requesting required permissions...");
    _clearScanError(); // Effacer l'erreur précédente

    // Vérifier les permissions en parallèle pour gagner du temps
    final results = await Future.wait([
      _checkAndRequestLocationPermission(), // Permission et service localisation
      _checkAndRequestBluetoothPermissions(), // Permissions spécifiques BLE (Android)
    ]);

    final bool locationOk = results[0];
    final bool bluetoothOk = results[1];
    final bool overallResult = locationOk && bluetoothOk;

    // Mettre à jour l'état global si les permissions ont échoué
    if (!overallResult) {
       print("BluetoothService: Permissions check failed (Location: $locationOk, Bluetooth: $bluetoothOk). Setting state to unauthorized.");
      _state = BluetoothState.unauthorized; // Marquer comme non autorisé
       // L'erreur spécifique (_scanError) a été définie dans les méthodes check
    } else if (_state == BluetoothState.unauthorized) {
      // Si les permissions sont maintenant OK mais l'état était 'unauthorized',
      // revérifier l'état matériel réel de l'adaptateur.
      print("BluetoothService: Permissions granted, re-checking adapter state...");
      await _updateInitialAdapterState();
    }

    print("BluetoothService: Permissions check complete. Overall result: $overallResult. Final State: $_state");
    notifyListeners(); // Notifier des changements potentiels (_state, _scanError)
    return overallResult;
  }

  /// Vérifie et demande la permission de localisation et l'activation du service.
  /// Utilise le package `location`.
  Future<bool> _checkAndRequestLocationPermission() async {
    // Pas nécessaire sur macOS pour le scan BLE standard a priori
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    print("BluetoothService: Checking Location service & permission...");
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    // 1. Vérifier si le service de localisation est activé
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      print("BluetoothService: Location service disabled. Requesting...");
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print("BluetoothService: Location service denied by user.");
        _scanError = ErrorMessages.locationServiceDisabled;
        return false; // Service requis
      }
      print("BluetoothService: Location service enabled by user.");
    }

    // 2. Vérifier la permission de localisation
    permissionGranted = await _location.hasPermission();
    print("BluetoothService: Initial location permission status: $permissionGranted");
    if (permissionGranted == loc.PermissionStatus.denied) {
      print("BluetoothService: Location permission denied. Requesting...");
      permissionGranted = await _location.requestPermission();
      print("BluetoothService: Location permission status after request: $permissionGranted");
    }

    // Vérifier si la permission est accordée (granted ou grantedLimited)
    if (permissionGranted == loc.PermissionStatus.granted ||
        permissionGranted == loc.PermissionStatus.grantedLimited) {
      print("BluetoothService: Location permission is sufficient.");
      return true;
    } else {
       print("BluetoothService: Location permission NOT granted.");

       _scanError = ErrorMessages.permissionDeniedLocation;
       return false;
    }
  }

  /// Vérifie et demande les permissions Bluetooth spécifiques (Android 12+).
  /// Utilise le package `permission_handler`.
  Future<bool> _checkAndRequestBluetoothPermissions() async {
    // Nécessaire seulement sur Android
    if (!Platform.isAndroid) return true;

    print("BluetoothService: Checking Android specific BLE permissions...");
    // Permissions requises pour Android 12+ (API 31+)
    final List<ph.Permission> requiredPermissions = [
      ph.Permission.bluetoothScan,
      ph.Permission.bluetoothConnect,

    ];

    // Demander toutes les permissions requises en une fois
    Map<ph.Permission, HandlerPermissionStatus> statuses = await requiredPermissions.request();

    // Vérifier si toutes les permissions sont accordées
    bool allGranted = statuses.values.every((status) => status == HandlerPermissionStatus.granted);

    if (allGranted) {
      print("BluetoothService: All required Android BLE permissions granted.");
      return true;
    } else {
      print("BluetoothService: Not all required Android BLE permissions granted. Statuses: $statuses");
      // Déterminer un message d'erreur plus précis si possible
      if (statuses[ph.Permission.bluetoothScan] != HandlerPermissionStatus.granted) {
         _scanError = "La permission 'Appareils à proximité' (Scan) est requise.";
      } else if (statuses[ph.Permission.bluetoothConnect] != HandlerPermissionStatus.granted) {
          _scanError = "La permission 'Appareils à proximité' (Connexion) est requise.";
      } else {
          _scanError = ErrorMessages.permissionDeniedBluetooth; // Message générique
      }
      // L'état sera mis à 'unauthorized' par checkAndRequestRequiredPermissions si overallResult est false
      return false;
    }
  }

  // --- Logique de Scan ---

  /// Lance un scan BLE pour les appareils Tick, tente d'extraire leur ID, et s'arrête dès le premier trouvé.
  /// Gère les états de l'adaptateur, les permissions, et le timeout.
  /// Met à jour `_foundTickResult`, `_extractedTickId`, `_isScanning`, et `_scanError`.
  /// Retourne `true` si un Tick a été trouvé et son ID extrait, `false` sinon.
  Future<bool> startTickScanAndExtractId(
      {Duration timeout = const Duration(seconds: BluetoothConfig.scanTimeoutSeconds)}) async {
    print("BluetoothService: Attempting to start Tick scan...");
    _resetScanResultState(); // Effacer les résultats précédents
    _clearScanError(); // Effacer l'erreur précédente

    // Vérifier si l'adaptateur est prêt (permissions et état matériel)

    if (state != BluetoothState.on) {
      _scanError = _scanError ?? "Bluetooth non prêt pour le scan (État: $state)";
      print("BluetoothService: Cannot scan, adapter state is not ON ($state). Error: $_scanError");
      notifyListeners();
      return false;
    }
    if (_isScanning) {
      print("BluetoothService: Scan already in progress.");
      return false; // Ne pas démarrer un nouveau scan si déjà en cours
    }
    if (!isBleSupported) {
      _scanError = ErrorMessages.bleNotSupported;
      print("BluetoothService: Cannot scan, BLE not supported.");
      notifyListeners();
      return false;
    }

    _isScanning = true;
    notifyListeners(); // Notifier l'UI que le scan commence
    print("BluetoothService: Scan started. Timeout: $timeout. Waiting for Tick...");

    final completer = Completer<bool>(); // Pour gérer la fin du scan (trouvé ou timeout)

    // S'abonner aux résultats du scan
    _scanResultsSubscription = blue.FlutterBluePlus.scanResults.listen(
      (results) {
        // Si déjà trouvé ou terminé, ignorer les nouveaux résultats
        if (completer.isCompleted) return;

        // Parcourir les résultats reçus
        for (blue.ScanResult result in results) {
          // Vérifier si l'appareil correspond à un Tick potentiel
          if (_isPotentialTickDevice(result)) {
            final extractedId = getTickIdFromName(result.device.platformName);
            if (extractedId != null) {
              // Tick trouvé et ID extrait !
              print("BluetoothService: >>> Tick Found & ID Extracted: ${result.device.remoteId} / ${result.device.platformName} -> ID: $extractedId <<<");
              _foundTickResult = result;
              _extractedTickId = extractedId;

              // Arrêter le scan immédiatement et compléter le future
              if (!completer.isCompleted) {
                 stopScan(); // Arrête le scan matériel et l'abonnement
                 completer.complete(true); // Indique succès
              }
              notifyListeners(); // Notifier l'UI que le Tick est trouvé
              return; // Sortir de la boucle et du listener
            }
          }
        }
      },
      onError: (error) { // Erreur pendant l'écoute du stream de scan
        print("BluetoothService: Scan Stream Error: $error");
        _scanError = "Erreur pendant le scan: $error";
        if (!completer.isCompleted) {
          stopScan();
          completer.complete(false); // Indique échec
        }
        notifyListeners();
      },
      // onDone n'est pas utilisé car on arrête le scan manuellement ou par timeout
    );

    // Démarrer le scan matériel FlutterBluePlus
    try {
      await blue.FlutterBluePlus.startScan(
        // Filtrer par UUID de service pour optimiser
        withServices: [blue.Guid(BluetoothConfig.tickServiceUuid)],
        timeout: timeout, // Timeout géré par FlutterBluePlus
        androidScanMode: blue.AndroidScanMode.lowLatency, // Mode de scan Android
      );

      // Attendre que le scan se termine (trouvé, timeout, ou erreur)
      final result = await completer.future.timeout(
          timeout + const Duration(seconds: 1), // Ajouter une marge au timeout global
          onTimeout: () {
            print("BluetoothService: Scan future timed out.");
            if (!completer.isCompleted) {
              stopScan(); // Assurer l'arrêt si timeout externe
              return false; // Timeout = non trouvé
            }
            return _extractedTickId != null; // Si trouvé juste avant le timeout
          });

      print("BluetoothService: Scan process finished. Found & ID Extracted: $result");
      // Si non trouvé et pas d'erreur spécifique, définir l'erreur "non trouvé"
      if (!result && _scanError == null) {
        _scanError = ErrorMessages.deviceNotFound;
      }
      // Assurer que _isScanning est false (stopScan devrait le faire)
      if (_isScanning) {
        _isScanning = false;
        notifyListeners();
      }
      return result;

    } catch (e, stacktrace) { // Capturer les erreurs lors du DÉMARRAGE du scan (ex: permissions)
      print("BluetoothService: Exception during startScan execution: $e\n$stacktrace");
      if (e.toString().toLowerCase().contains('permission')) {
        _scanError = ErrorMessages.permissionDeniedBluetooth;
        _state = BluetoothState.unauthorized; // Mettre à jour l'état si erreur de permission
      } else {
        _scanError = "Erreur système lors du démarrage du scan: ${e.toString()}";
      }
      if (!completer.isCompleted) completer.complete(false);
      await stopScan(); // Assurer l'arrêt et la notification
      return false;
    }
  }


  /// Arrête le scan BLE en cours.
  Future<void> stopScan() async {
    // Vérifier si supporté et si un scan est réellement en cours
    if (!isBleSupported || !_isScanning) return;

    print("BluetoothService: Stopping scan...");
    try {
      // Annuler l'abonnement aux résultats d'abord pour éviter de traiter de nouveaux résultats
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;

      // Arrêter le scan matériel s'il est actif
      // Utiliser la propriété isScanning synchrone pour vérifier
      if (blue.FlutterBluePlus.isScanningNow) {
          await blue.FlutterBluePlus.stopScan();
          print("BluetoothService: Hardware scan stopped via FBP.");
      } else {
          print("BluetoothService: Hardware scan reported as already stopped.");
      }
    } catch (e) {
      // Une erreur ici est moins critique mais doit être loguée
      print('BluetoothService: Error stopping scan: $e');
      // On ne définit pas _scanError ici car ce n'est pas une erreur de scan utilisateur
    } finally {
      // Assurer la mise à jour de l'état interne et notifier l'UI
      // Mettre à jour _isScanning même si stopScan lève une exception
      if (_isScanning) {
         _isScanning = false;
         notifyListeners();
      }
    }
  }

  Future<bool> signalTickAssociationComplete() async {
    final deviceToSignal = _foundTickResult?.device;

    if (deviceToSignal == null) {
      print("BluetoothService: Cannot signal Tick, no device found from previous scan.");
      _scanError = "Erreur interne : appareil non trouvé pour la signalisation.";
      notifyListeners();
      return false;
    }
    if (state != BluetoothState.on) {
      print("BluetoothService: Cannot signal Tick, adapter state is not ON ($state).");
      _scanError = "Bluetooth non activé pour la signalisation.";
      notifyListeners();
      return false;
    }

    print("BluetoothService: Attempting to connect to Tick ${deviceToSignal.remoteId} to signal association (Simplified Logic V3.1)...");
    _clearScanError();
    bool connectionInitiatedSuccessfully = false;

    try {
      // Tenter la connexion.
      await deviceToSignal.connect(
        timeout: const Duration(seconds: 5),
        autoConnect: false,
      );
      connectionInitiatedSuccessfully = true;
      print("BluetoothService [Signal]: connect() call completed without immediate error.");
      await deviceToSignal.disconnect().catchError((e) { /* log info */ });
      print("BluetoothService [Signal]: Signaling considered SUCCESSFUL (connection initiated).");
      return true;

    } catch (e) {
      print("BluetoothService [Signal]: Exception caught during/after connect() attempt: $e");
      print("BluetoothService [Signal]: Exception type: ${e.runtimeType}");


      bool isExpectedDisconnectError = false;


      if (e is blue.FlutterBluePlusException) {

        final exceptionString = e.toString().toLowerCase();
        if (exceptionString.contains('device is disconnected') ||
            exceptionString.contains('status=19') ||
            exceptionString.contains('remote_user_terminated'))
        {
          isExpectedDisconnectError = true;
        }
      }
      // Garder la vérification pour PlatformException au cas où
      else if (e is PlatformException && (e.message?.toLowerCase().contains('device is disconnected') ?? false)) {
        isExpectedDisconnectError = true;
      }

      if (isExpectedDisconnectError) {
        print("BluetoothService [Signal]: Caught expected disconnection exception ($e). Treating as SUCCESSFUL signal.");
        // S'assurer que l'appareil est marqué comme déconnecté côté Flutter
        await deviceToSignal.disconnect().catchError((e2) { /* log info */ });
        return true; // <<< SUCCÈS pour cette erreur spécifique
      } else {
        // Autre erreur inattendue
        print("BluetoothService [Signal]: Caught UNEXPECTED exception ($e). Signaling FAILED.");
        _scanError = "Impossible de contacter le Tick pour finaliser : ${e.toString()}";
        notifyListeners();
        return false; // <<< ÉCHEC pour les autres erreurs
      }

    }
  }

  // --- Helpers & Cleanup ---

  /// Vérifie si un résultat de scan correspond potentiellement à un appareil Tick.
  /// Se base sur le préfixe du nom et l'UUID de service annoncé.
  bool _isPotentialTickDevice(blue.ScanResult result) {
    final deviceName = result.device.platformName;
    // Ignorer les appareils sans nom
    if (deviceName.isEmpty) return false;

    // 1. Vérifier si le nom commence par le préfixe attendu
    if (!deviceName.startsWith(BluetoothConfig.tickNamePrefix)) return false;

    // 2. Vérifier si l'UUID de service attendu est présent dans les données d'annonce
    // Convertir tous les UUID en minuscules pour une comparaison insensible à la casse
    final serviceUuids = result.advertisementData.serviceUuids
        .map((e) => e.toString().toLowerCase())
        .toList();
    final targetUuid = BluetoothConfig.tickServiceUuid.toLowerCase();

    // Debug log (peut être commenté en production)
    // print("Device: $deviceName, Services: $serviceUuids, Target: $targetUuid");
    return serviceUuids.contains(targetUuid);
  }

  /// Extrait l'ID unique du Tick à partir du nom de l'appareil BLE.
  /// Retourne `null` si le nom n'a pas le format attendu ("Tick-ID").
  String? getTickIdFromName(String? deviceName) {
    if (deviceName != null && deviceName.startsWith(BluetoothConfig.tickNamePrefix)) {
      // Retourne la partie après le préfixe
      return deviceName.substring(BluetoothConfig.tickNamePrefix.length);
    }
    return null; // Format invalide ou nom null
  }

  /// Réinitialise les informations liées au dernier scan réussi.
  void _resetScanResultState({bool notify = true}) {
    bool changed = _foundTickResult != null || _extractedTickId != null;
    _foundTickResult = null;
    _extractedTickId = null;
    if (changed && notify) {
      notifyListeners();
    }
  }

   /// Efface le message d'erreur de scan et notifie.
   void _clearScanError() {
      if (_scanError != null) {
         _scanError = null;
         notifyListeners();
      }
   }

  /// Libère les ressources (annule les abonnements aux streams).
  @override
  void dispose() {
    print("BluetoothService: Disposing...");
    _adapterStateSubscription?.cancel();
    stopScan(); // Assure l'arrêt du scan et l'annulation de _scanResultsSubscription
    super.dispose();
    print("BluetoothService: Disposed.");
  }
}
