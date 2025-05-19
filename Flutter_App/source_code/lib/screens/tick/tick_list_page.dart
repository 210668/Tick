import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/tick_model.dart';
import '../../services/auth_service.dart';
import '../../services/tick_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/loading_indicator.dart';
import 'map_page.dart';

class TickListPage extends StatefulWidget {
  const TickListPage({Key? key}) : super(key: key);

  @override
  State<TickListPage> createState() => _TickListPageState();
}

class _TickListPageState extends State<TickListPage> {



  /// Navigue vers la page de carte pour un Tick spécifique.
  void _navigateToMapPage(Tick tick) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(tick: tick),
      ),
    );
  }

  /// Navigue vers la page d'ajout de Tick.
  void _navigateToAddTickPage() {
    Navigator.pushNamed(context, Routes.addTick);
  }

  /// Navigue vers la page de profil utilisateur.
  void _navigateToProfilePage() {
    Navigator.pushNamed(context, Routes.profile);
  }

  /// Navigue vers la page des paramètres généraux.
  void _navigateToSettingsPage() {
     Navigator.pushNamed(context, Routes.settings);
  }

  /// Gère la déconnexion de l'utilisateur.
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppTexts.logout),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppTexts.cancel),
          ),
          // Bouton de confirmation en rouge pour attirer l'attention
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppTexts.logout),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      if (mounted) {
         Navigator.pushNamedAndRemoveUntil(context, Routes.welcome, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTexts.myTicks),
        actions: [
          const ThemeToggleButton(),
          // Menu pour Profil, Paramètres et Déconnexion
          PopupMenuButton<String>(
            tooltip: "Menu",
            onSelected: (value) {
              if (value == 'profile') _navigateToProfilePage();
              if (value == 'settings') _navigateToSettingsPage();
              if (value == 'logout') _logout();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text(AppTexts.profile),
                ),
              ),
               const PopupMenuItem<String>(
                 value: 'settings',
                 child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text(AppTexts.settings),
                 ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppTheme.errorColor),
                  title: Text(AppTexts.logout, style: TextStyle(color: AppTheme.errorColor)),
                ),
              ),
            ],
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: Consumer<TickService>(
        builder: (context, tickService, child) {
          // --- Cas 1: Chargement initial ---
          if (tickService.isLoading && tickService.ticks.isEmpty) {
            return const Center(child: LoadingIndicator());
          }

          // --- Cas 2: Erreur de chargement initial ---
          if (tickService.error != null && tickService.ticks.isEmpty) {
            return _buildErrorState(tickService.error!, () => tickService.fetchTicks());
          }

          // --- Cas 3: Aucun Tick associé ---
          if (tickService.ticks.isEmpty) {
            return _buildEmptyState();
          }

          // --- Cas 4: Afficher la liste des Ticks ---

          return RefreshIndicator(
            onRefresh: () => tickService.fetchTicks(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: tickService.ticks.length,
              itemBuilder: (context, index) {
                final tick = tickService.ticks[index];
                return _buildTickListItem(tick);
              },
            ),
          );
        },
      ),
      // Bouton flottant pour ajouter un Tick (uniquement sur mobile)
      floatingActionButton: (kIsWeb || !(Platform.isAndroid || Platform.isIOS))
          ? null
          : FloatingActionButton(
              onPressed: _navigateToAddTickPage,
              tooltip: AppTexts.addTick,
              child: const Icon(Icons.add),
            ),
    );
  }

  /// Construit le widget pour afficher un élément Tick dans la liste.
  Widget _buildTickListItem(Tick tick) {
    final batteryLevel = tick.batteryLevel;
    final batteryColor = AppColors.getBatteryColor(batteryLevel);
    final statusColor = AppColors.getStatusColor(tick.status, context);
    final theme = Theme.of(context);
    // Utiliser la couleur du texte par défaut du thème pour le temps (au lieu du bleu)
    final defaultTextColor = theme.textTheme.bodySmall?.color ?? theme.disabledColor;

    const double approxSubtitleLineHeight = 17.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToMapPage(tick),
        child: Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 10.0, left: 16.0, right: 16.0),
          child: Stack(
            children: [

              Row(

                crossAxisAlignment: CrossAxisAlignment.center,

                children: [

                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(_getTickIcon(tick.status), color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 16),

                  // Colonne pour Titre et Sous-titres (partie gauche)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Text(
                          tick.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Sous-titre Ligne 1: Statut
                        Text(
                          tick.statusDescription,
                          style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),

                        // Sous-titre Ligne 2: Batterie (si disponible)
                        if (batteryLevel != null)
                          Row(
                            children: [
                              Icon(
                                _getBatteryIcon(batteryLevel),
                                size: 14,
                                color: batteryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$batteryLevel%',
                                style: TextStyle(fontSize: 12, color: batteryColor, fontWeight: FontWeight.w500),
                              ),
                            ],
                          )
                        else
                          const SizedBox(height: approxSubtitleLineHeight),

                      ],
                    ),
                  ),

                  const SizedBox(width: 50),
                ],
              ),

              // --- Temps Relatif + Icône (Positionné à droite, aligné ~batterie) ---
              Positioned(
                right: 18,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,

                      color: defaultTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tick.formattedLastUpdate,
                      style: TextStyle(
                        fontSize: 11,

                        color: defaultTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // --- Flèche Trailing (Positionnée à l'extrême droite) ---
              Positioned(
                top: 0,
                bottom: 0,
                right: -4,
                child: Center(
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7) ?? theme.disabledColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit le widget affiché lorsqu'aucun Tick n'est associé.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_off_outlined, size: 80, color: Theme.of(context).disabledColor),
            const SizedBox(height: 24),
            Text(
              AppTexts.noTicksAvailable,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppTexts.addFirstTick,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 32),

            if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
              ElevatedButton.icon(
                onPressed: _navigateToAddTickPage,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(AppTexts.addTick),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
          ],
        ),
      ),
    );
  }

  /// Construit le widget affiché en cas d'erreur de chargement.
  Widget _buildErrorState(String errorMessage, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 60),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text(AppTexts.retry),
              onPressed: onRetry,
            )
          ],
        ),
      ),
    );
  }

  /// Retourne l'icône principale pour le Tick en fonction de son statut.
  IconData _getTickIcon(TickStatus status) {
     switch (status) {
       case TickStatus.theftAlert: return Icons.warning_amber_rounded;
       case TickStatus.lowBattery: return Icons.battery_alert_outlined;
       case TickStatus.moving: return Icons.directions_walk;
       case TickStatus.inactive: return Icons.cloud_off_outlined;
       case TickStatus.active:
       case TickStatus.unknown:
       default: return Icons.location_pin;
     }
   }

  /// Retourne l'icône de batterie appropriée en fonction du niveau.
  IconData _getBatteryIcon(int level) {

    if (level > 95) return Icons.battery_full_outlined;
    if (level > 80) return Icons.battery_6_bar_outlined;
    if (level > 60) return Icons.battery_5_bar_outlined;
    if (level > 40) return Icons.battery_3_bar_outlined;
    if (level > 20) return Icons.battery_1_bar_outlined;
    return Icons.battery_alert_outlined; // <= 20%
  }
}