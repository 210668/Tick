import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue;
import 'package:permission_handler/permission_handler.dart' as ph;

import '../services/bluetooth_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import 'alert_card.dart';
import 'loading_indicator.dart';

/// Un widget qui affiche l'état actuel du Bluetooth et des permissions associées.
/// Peut proposer des actions pour résoudre les problèmes (activer BT, ouvrir paramètres).
class BluetoothStatusWidget extends StatelessWidget {
  /// Si `true`, n'affiche rien si le Bluetooth est activé et autorisé.
  final bool showOnlyWhenOffOrUnauthorized;

  const BluetoothStatusWidget({
    Key? key,
    this.showOnlyWhenOffOrUnauthorized = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Vérifier si le BLE est pertinent sur la plateforme actuelle
    final bool isBleRelevant = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    if (!isBleRelevant) {
      return const SizedBox.shrink(); // Ne rien afficher si non pertinent
    }

    // Écouter les changements du BluetoothService
    return Consumer<BluetoothService>(
      builder: (context, bluetoothService, child) {
        final state = bluetoothService.state;
        final scanError = bluetoothService.scanError; // Lire l'erreur potentielle

        // Si on ne doit afficher que les problèmes et que tout est OK
        if (showOnlyWhenOffOrUnauthorized && state == blue.BluetoothAdapterState.on && state != blue.BluetoothAdapterState.unauthorized) {
          return const SizedBox.shrink();
        }

        // Gérer les états transitoires (activation/désactivation)
        if (state == blue.BluetoothAdapterState.turningOn || state == blue.BluetoothAdapterState.turningOff) {
          return _buildTransitionStateCard(context, state);
        }

        // Gérer les états problématiques (Off, Non autorisé, Indisponible)
        if (state == blue.BluetoothAdapterState.off ||
            state == blue.BluetoothAdapterState.unavailable ||
            state == blue.BluetoothAdapterState.unauthorized) {

          String title;
          String message;
          AlertType type;
          IconData icon;
          VoidCallback? buttonAction;
          String? buttonLabel;
          IconData? buttonIcon;

          switch (state) {
            case blue.BluetoothAdapterState.off:
              title = 'Bluetooth désactivé';
              message = AppTexts.enableBluetoothPrompt;
              type = AlertType.warning;
              icon = Icons.bluetooth_disabled;
              buttonLabel = AppTexts.enableBluetoothButton;
              buttonIcon = Icons.bluetooth_audio;
              buttonAction = () async {
                // Tenter d'activer via le service
                final success = await bluetoothService.attemptToEnableBluetooth();
                // Sur iOS, guider l'utilisateur car l'activation programmatique n'est pas possible
                if (!success && Platform.isIOS && context.mounted) {
                  CustomSnackBar.show(
                    context,
                    message: 'Veuillez activer le Bluetooth dans le Centre de contrôle ou les Réglages.',
                    type: AlertType.info,
                  );
                }
              };
              break;

            case blue.BluetoothAdapterState.unauthorized:
              title = 'Permissions requises';
              // Utiliser l'erreur spécifique du service si disponible
              message = scanError ?? 'L\'application nécessite les permissions Bluetooth et/ou Localisation pour scanner les appareils.';
              type = AlertType.error;
              icon = Icons.lock_outline; // Icône de permission
              buttonLabel = AppTexts.openSettings; // Bouton pour ouvrir les paramètres
              buttonIcon = Icons.settings;
              buttonAction = () async => await ph.openAppSettings(); // Utilise permission_handler
              break;

            case blue.BluetoothAdapterState.unavailable:
              title = 'Bluetooth non disponible';
              message = scanError ?? AppTexts.featureNotAvailableOnPlatform; // Message plus générique
              type = AlertType.error;
              icon = Icons.bluetooth_disabled;
              buttonLabel = null; // Pas d'action possible
              buttonAction = null;
              break;

            default: // Ne devrait pas être atteint
              return const SizedBox.shrink();
          }

          // Construire la carte d'alerte avec les informations déterminées
          return _buildProblemStateCard(
              context, type, icon, title, message, buttonLabel, buttonIcon, buttonAction);
        }

        // Si l'état est 'on' et qu'on n'a pas filtré, ou tout autre état non géré
        return const SizedBox.shrink(); // Ne rien afficher dans les autres cas
      },
    );
  }

  /// Construit une carte simple pour les états transitoires (turningOn/turningOff).
  Widget _buildTransitionStateCard(BuildContext context, blue.BluetoothAdapterState state) {
     return Card(
       margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
       color: AppTheme.infoColor.withOpacity(0.1),
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Row(
           children: [
             SizedBox(
                width: 20,
                height: 20,
                child: LoadingIndicator(size: 20, strokeWidth: 2, color: AppTheme.infoColor),
              ),
             const SizedBox(width: 16),
             Expanded(
               child: Text(
                 state == blue.BluetoothAdapterState.turningOn
                     ? 'Activation du Bluetooth...'
                     : 'Désactivation du Bluetooth...',
                 style: const TextStyle(color: AppTheme.infoColor),
               ),
             ),
           ],
         ),
       ),
     );
  }

  /// Construit une carte d'alerte pour les états problématiques (Off, Unauthorized, Unavailable).
  Widget _buildProblemStateCard(
      BuildContext context,
      AlertType type,
      IconData icon,
      String title,
      String message,
      String? buttonLabel,
      IconData? buttonIcon,
      VoidCallback? buttonAction) {
    final alertColor = AppTheme.getAlertColor(type);
    // Choisir une couleur de texte contrastante pour le bouton
    final buttonTextColor = ThemeData.estimateBrightnessForColor(alertColor) == Brightness.dark
                           ? Colors.white : Colors.black;

     return Card(
       margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
       // Utiliser une couleur de fond légère basée sur le type d'alerte
       color: alertColor.withOpacity(0.1),
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 Icon(icon, color: alertColor),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Text(
                     title,
                     style: TextStyle(fontWeight: FontWeight.bold, color: alertColor),
                   ),
                 ),
               ],
             ),
             const SizedBox(height: 8),
             Text(message),
             // Afficher le bouton d'action si défini
             if (buttonAction != null && buttonLabel != null) ...[
               const SizedBox(height: 16),
               ElevatedButton.icon(
                 icon: buttonIcon != null ? Icon(buttonIcon, size: 18) : const SizedBox.shrink(),
                 label: Text(buttonLabel),
                 onPressed: buttonAction,
                 // Style pour correspondre à la couleur de l'alerte
                 style: ElevatedButton.styleFrom(
                   backgroundColor: alertColor,
                   foregroundColor: buttonTextColor,
                   visualDensity: VisualDensity.compact, // Bouton plus petit
                 ),
               ),
             ]
           ],
         ),
       ),
     );
  }
}