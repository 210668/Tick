
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../services/bluetooth_service.dart';
import '../../services/tick_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/bluetooth_status_widget.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/step_indicator.dart';
import '../../widgets/theme_toggle_button.dart';

/// Étapes du processus d'association d'un nouveau Tick.
enum AssociationStep {
  naming,          // 1. Entrer le nom du Tick.
  bluetoothCheck,  // 2. Vérifier les permissions et l'état du Bluetooth.
  scanning,        // 3. Scanner les appareils Tick à proximité.
  sending,         // 4. Envoyer les informations au backend pour l'association.
  signaling,       // 5. Envoyer le signal de connexion final au Tick. (NOUVEAU)
  done,            // 6. Association réussie.
  error            // Une erreur est survenue.
}

class AddTickPage extends StatefulWidget {
  const AddTickPage({Key? key}) : super(key: key);

  @override
  State<AddTickPage> createState() => _AddTickPageState();
}

class _AddTickPageState extends State<AddTickPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  AssociationStep _currentStep = AssociationStep.naming;
  String? _errorMessage;

  bool _isProcessing = false;
  bool _isPlatformSupported = false;

  late BluetoothService _bluetoothService;

  @override
  void initState() {
    super.initState();
    _isPlatformSupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    if (_isPlatformSupported) {
      _bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    }
  }

  /// Change l'étape actuelle du processus et met à jour l'UI.
  void _setStep(AssociationStep step) {
    if (!mounted || _currentStep == step) return;

    // Logique pour éviter retours en arrière depuis états finaux (inchangée)
    if ((_currentStep == AssociationStep.done || _currentStep == AssociationStep.error) &&
        step.index < _currentStep.index && step != AssociationStep.naming) {
      print("AddTickPage: Cannot go back from step: $_currentStep to $step");
      return;
    }

    setState(() {
      _currentStep = step;
      _isProcessing = false;
      if (step != AssociationStep.error) _errorMessage = null;

    });
    print("AddTickPage: Current Step set to: $_currentStep");
  }

  /// Met l'UI en état d'erreur avec un message spécifique.
  void _setError(String message) {
    if (!mounted) return;
    print("AddTickPage: Setting Error: $message");
    setState(() {
      _currentStep = AssociationStep.error;
      _errorMessage = message;
      _isProcessing = false;
    });
  }

  // --- Logique Principale du Processus ---

  /// Étape 1 -> 2: Vérifie les permissions et l'état Bluetooth avant de lancer le scan.
  Future<void> _checkPermissionsAndStartScan() async {
    if (!mounted || _isProcessing) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _isProcessing = true);

    print("AddTickPage: Checking permissions and Bluetooth state...");
    bool permissionsOk = await _bluetoothService.checkAndRequestRequiredPermissions();
    if (!mounted) { setState(() => _isProcessing = false); return; }

    if (!permissionsOk) {
      print("AddTickPage: Permissions check failed. State: ${_bluetoothService.state}, Error: ${_bluetoothService.scanError}");
      _setError(_bluetoothService.scanError ?? ErrorMessages.permissionDenied);
      _setStep(AssociationStep.bluetoothCheck);
      return;
    }

    print("AddTickPage: Permissions OK. Adapter State: ${_bluetoothService.state}");
    if (_bluetoothService.state != BluetoothState.on) {
      print("AddTickPage: Bluetooth is not ON.");
      _setError(_bluetoothService.scanError ?? ErrorMessages.bluetoothNotEnabled);
      _setStep(AssociationStep.bluetoothCheck); // Afficher l'étape de check
      return;
    }

    print("AddTickPage: Permissions and State OK. Proceeding to scan...");

    await _startScanAndProcess(); // Lance le scan

    // Remettre _isProcessing à false SEULEMENT si on est pas passé à une étape de processing
    if (mounted &&
        _currentStep != AssociationStep.scanning &&
        _currentStep != AssociationStep.sending &&
        _currentStep != AssociationStep.signaling) {
      setState(() { _isProcessing = false; });
    }
  }

  /// Étape 2 -> 3: Lance le scan Bluetooth, extrait l'ID.
  Future<void> _startScanAndProcess() async {
    if (!mounted) return;

    _setStep(AssociationStep.scanning);
    setState(() => _isProcessing = true);

    try {
      final bool found = await _bluetoothService.startTickScanAndExtractId();
      if (!mounted) return;

      if (found && _bluetoothService.extractedTickId != null) {

        print("AddTickPage: Scan successful, Extracted ID: ${_bluetoothService.extractedTickId}");
        _setStep(AssociationStep.sending); // Passe à l'envoi API
        await _triggerAssociationApi(); // Lance l'appel API
      } else {
        print("AddTickPage: Scan failed or ID not extracted. Error: ${_bluetoothService.scanError}");
        _setError(_bluetoothService.scanError ?? ErrorMessages.deviceNotFound);

      }
    } catch (e) {
      print("AddTickPage: Exception during scan process: $e");
      _setError("Erreur inattendue pendant le scan: ${e.toString()}");
    } finally {
      // Assurer que _isProcessing est false si on n'est pas dans sending/signaling
      if (mounted && _currentStep != AssociationStep.sending && _currentStep != AssociationStep.signaling) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Étape 3 -> 4 -> 5: Appelle l'API backend, puis tente de signaler le Tick via BT.
  Future<void> _triggerAssociationApi() async {
    if (!mounted) return;
    if (_bluetoothService.extractedTickId == null) {
      _setError("Erreur interne: ID du Tick non trouvé après le scan.");
      _setStep(AssociationStep.scanning);
      return;
    }

    final tickService = Provider.of<TickService>(context, listen: false);
    final tickNickname = _nameController.text.trim();
    final tickHardwareId = _bluetoothService.extractedTickId!;

    // On est déjà à l'étape Sending, _isProcessing est true
    print("AddTickPage: Triggering association API call with Name: $tickNickname, Hardware ID: $tickHardwareId");

    try {
      // --- Appel API ---
      final apiSuccess = await tickService.associateTick(tickNickname, tickHardwareId);
      if (!mounted) return;

      if (apiSuccess) {
        print("AddTickPage: Association API successful! Proceeding to signal Tick.");
        // --- Passage à l'étape de signalisation ---
        _setStep(AssociationStep.signaling);
        setState(() => _isProcessing = true); // Assurer le processing pour le signal
        await _signalTick(); // Appeler la nouvelle fonction de signalisation

      } else {
        print("AddTickPage: Association API failed. Error: ${tickService.error}");
        _setError(tickService.error ?? ErrorMessages.associationFailed);
      }
    } catch (e) {
      print("AddTickPage: Exception during association API call: $e");
      _setError(ErrorMessages.connectionFailed);
    } finally {

    }
  }

  /// Étape 5 -> 6: Tente la connexion BT pour signaler le Tick.
  Future<void> _signalTick() async {
    if (!mounted) return;
    // On est à l'étape Signaling, _isProcessing est true
    print("AddTickPage: Attempting to signal Tick via Bluetooth connect...");

    try {
      final signalSuccess = await _bluetoothService.signalTickAssociationComplete();
      if (!mounted) return;

      if (signalSuccess) {
        print("AddTickPage: Signaling attempt successful/initiated.");
        _setStep(AssociationStep.done); // Terminé !

        await Future.delayed(AppDurations.mediumDelay);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        print("AddTickPage: Signaling attempt failed. Error: ${_bluetoothService.scanError}");
        _setError(_bluetoothService.scanError ?? "Impossible de finaliser l'association avec le Tick. Vérifiez qu'il est allumé et à proximité, puis réessayez.");
        // Reste en état d'erreur
      }
    } catch (e) {
      print("AddTickPage: Exception during signaling: $e");
      _setError("Erreur inattendue lors de la finalisation: ${e.toString()}");
    } finally {
      // Mettre fin au processing si on n'est pas passé à Done
      if (mounted && _currentStep != AssociationStep.done) {
        setState(() => _isProcessing = false);
      }
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    // Arrêter le scan s'il est en cours lors de la sortie de la page
    if (_isPlatformSupported && _currentStep == AssociationStep.scanning && _isProcessing) {

      _bluetoothService.stopScan();
    }
    super.dispose();
  }

  // --- Construction de l'UI ---

  @override
  Widget build(BuildContext context) {
    if (!_isPlatformSupported) {
      return _buildUnsupportedPlatformWidget();
    }

    // --- Listener Bluetooth State (peut rester tel quel) ---
    final btState = context.watch<BluetoothService>().state;
    if (_currentStep.index >= AssociationStep.scanning.index &&
        _currentStep != AssociationStep.done &&
        _currentStep != AssociationStep.error &&
        btState != BluetoothState.on) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(_currentStep != AssociationStep.error && mounted) {
          print("AddTickPage: Bluetooth turned off during association process. Returning to check step.");
          _setError(ErrorMessages.bluetoothNotEnabled);
          _setStep(AssociationStep.bluetoothCheck);
        }
      });
    }
    // --- Fin Listener ---

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTexts.addTick),
        actions: const [ThemeToggleButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppTexts.associateNewTick, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(AppTexts.associationSteps, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),

            // --- Indicateur d'étapes (MAJ) ---
            StepIndicator(
              stepCount: 5, // 1:Nom, 2:Scan, 3:API, 4:Signal, 5:Fini
              currentStep: _getCurrentStepIndex(),
              activeColor: AppTheme.primaryColor,
              inactiveColor: Theme.of(context).dividerColor,
              errorStep: _currentStep == AssociationStep.error ? _getPreviousStepIndex() : null,

              doneStep: _currentStep == AssociationStep.done ? 4 : null,
            ),
            const SizedBox(height: 32),

            // Contenu spécifique à l'étape actuelle
            AnimatedSwitcher(
              duration: AppDurations.shortFade,
              child: Container(
                key: ValueKey<AssociationStep>(_currentStep),
                child: _buildStepContent(),
              ),
            ),
            const SizedBox(height: 32),

            // Bouton d'action principal
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  /// Retourne l'index (0-based) de l'étape actuelle pour le StepIndicator. (MAJ)
  int _getCurrentStepIndex() {
    switch (_currentStep) {
      case AssociationStep.naming: return 0;
      case AssociationStep.bluetoothCheck: return 1; // Check fait partie de Scan
      case AssociationStep.scanning: return 1; // Scan = étape 2 (index 1)
      case AssociationStep.sending: return 2; // Envoi API = étape 3 (index 2)
      case AssociationStep.signaling: return 3; // Signal = étape 4 (index 3) (NOUVEAU)
      case AssociationStep.done: return 4; // Terminé = étape 5 (index 4)
      case AssociationStep.error: return _getPreviousStepIndex();
    }
  }

  /// Retourne l'index (0-based) de l'étape où l'erreur s'est produite. (MAJ)
  int _getPreviousStepIndex() {
        if (_currentStep == AssociationStep.error && _bluetoothService.extractedTickId != null /* Implique qu'on a passé l'API */ ) {

      return 2;
    }

    return 1;
  }

  /// Construit le contenu principal de l'UI en fonction de l'étape actuelle.
  Widget _buildStepContent() {
    switch (_currentStep) {
      case AssociationStep.naming: return _buildNamingStep();
      case AssociationStep.bluetoothCheck: return _buildBluetoothCheckStep();
      case AssociationStep.scanning: return _buildScanningStep();
      case AssociationStep.sending: return _buildSendingStep();
      case AssociationStep.signaling: return _buildSignalingStep();
      case AssociationStep.done: return _buildDoneStep();
      case AssociationStep.error: return _buildErrorStep();
    }
  }

  // Widgets pour les étapes naming, bluetoothCheck, scanning, sending (INCHANGÉS)
  Widget _buildNamingStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("1. Nommez votre Tick", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: AppTexts.tickName,
              hintText: AppTexts.tickNameHint,
              prefixIcon: Icon(Icons.label_outline),
            ),
            validator: (value) => Validators.validateNotEmpty(value, "Veuillez nommer votre Tick"),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _checkPermissionsAndStartScan(),
            enabled: !_isProcessing,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothCheckStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("2. Vérification Bluetooth", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(AppTexts.enableBluetoothPrompt),
        const SizedBox(height: 16),
        BluetoothStatusWidget(showOnlyWhenOffOrUnauthorized: false),
      ],
    );
  }

  Widget _buildScanningStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const LoadingIndicator(size: 40),
        const SizedBox(height: 24),
        Text(AppTexts.searchingTick, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          AppTexts.activateTickPrompt,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildSendingStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const LoadingIndicator(size: 40),
        const SizedBox(height: 24),
        Text(AppTexts.associatingTick, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          // Utilise l'ID stocké dans le service Bluetooth
          "Enregistrement de '${_nameController.text}' (ID: ${_bluetoothService.extractedTickId ?? '...'})...",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  /// Widget pour la NOUVELLE étape 5: Signalisation du Tick.
  Widget _buildSignalingStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const LoadingIndicator(size: 40),
        const SizedBox(height: 24),
        Text("Finalisation...", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          "Envoi du signal de confirmation au Tick...",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }


  // Widgets pour les étapes done et error
  Widget _buildDoneStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 60),
        const SizedBox(height: 24),
        Text(AppTexts.tickAssociatedSuccess, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.successColor)),
        const SizedBox(height: 8),
        Text(
          "'${_nameController.text}' est maintenant visible dans votre liste.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildErrorStep() {
    return AlertCard(
      title: AppTexts.error,
      message: _errorMessage ?? ErrorMessages.unknownError,
      type: AlertType.error,
    );
  }

  /// Construit le bouton d'action principal en bas de page.
  Widget _buildActionButton() {
    String buttonText = AppTexts.next;
    VoidCallback? onPressedAction;
    bool isEnabled = !_isProcessing;

    switch (_currentStep) {
      case AssociationStep.naming:
        buttonText = AppTexts.searchTickButton;
        onPressedAction = _checkPermissionsAndStartScan;
        break;
      case AssociationStep.bluetoothCheck:
        final state = _bluetoothService.state;
        if (state == BluetoothState.unauthorized || (_bluetoothService.scanError?.contains("Permission") ?? false)) {
          buttonText = AppTexts.openSettings;
          onPressedAction = () async => await ph.openAppSettings();
        } else if (state == BluetoothState.off) {
          buttonText = AppTexts.enableBluetoothButton;
          onPressedAction = () async {
            await _bluetoothService.attemptToEnableBluetooth();
            await Future.delayed(AppDurations.shortDelay);
            if (mounted && _bluetoothService.state == BluetoothState.on) {
              _setStep(AssociationStep.naming);
            }
          };
        } else {
          buttonText = AppTexts.retry;
          onPressedAction = () => _setStep(AssociationStep.naming);
        }
        break;
      case AssociationStep.scanning:
        buttonText = AppTexts.cancel;
        isEnabled = isEnabled && _bluetoothService.isScanning;
        onPressedAction = isEnabled ? () async {
          await _bluetoothService.stopScan();
          _setStep(AssociationStep.naming);
        } : null;
        break;
      case AssociationStep.sending:
        buttonText = AppTexts.associatingTick;
        onPressedAction = null; // Pas d'action pendant envoi API
        isEnabled = false;
        break;
      case AssociationStep.signaling:
        buttonText = "Finalisation...";
        onPressedAction = null;
        isEnabled = false;
        break;
      case AssociationStep.done:
        buttonText = AppTexts.done;
        onPressedAction = () {
          print(">>> AddTickPage: DONE button pressed. Attempting Navigator.pop...");
          Navigator.pop(context);
          print(">>> AddTickPage: Navigator.pop() called.");
        };
        isEnabled = true;
        break;
      case AssociationStep.error:
        buttonText = AppTexts.retry;
        onPressedAction = () => _setStep(AssociationStep.naming);
        isEnabled = true;
        break;
    }

    return ElevatedButton(
      onPressed: isEnabled ? onPressedAction : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
      ),

      child: (_isProcessing && (
          _currentStep == AssociationStep.scanning ||
              _currentStep == AssociationStep.sending ||
              _currentStep == AssociationStep.signaling
      ))
          ? const LoadingIndicator(size: 20, color: Colors.white)
          : Text(buttonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildUnsupportedPlatformWidget() {
    return Scaffold(
      appBar: AppBar(title: const Text(AppTexts.addTick)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bluetooth_disabled, size: 60, color: Theme.of(context).disabledColor),
              const SizedBox(height: 16),
              Text(
                'Fonctionnalité non supportée',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppTexts.featureNotAvailableOnPlatform,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppTexts.back),
              )
            ],
          ),
        ),
      ),
    );
  }
}