

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'dart:async';

import '../../models/tick_model.dart';
import '../../services/theme_service.dart';
import '../../services/tick_service.dart';
import '../../widgets/action_button.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/loading_indicator.dart';
import '../../utils/map_styles.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import 'tick_settings_page.dart';
import 'history_page.dart';

class MapPage extends StatefulWidget {

  final Tick tick;

  const MapPage({
    Key? key,
    required this.tick,
  }) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();
  GoogleMapController? _mapController;

  // État local pour suivre les chargements spécifiques
  bool _isMapLoading = true; // Chargement initial de Google Maps
  bool _isLocateActionLoading = false; // NOUVEAU : Pour 'Localiser'
  bool _isRingActionLoading = false; // NOUVEAU : Pour 'Faire sonner'
  bool _isUserLocationLoading = false; // Pour la récupération de la position utilisateur
  bool _isFetchingData = false;

  LatLng? _userPosition;

  // Les marqueurs à afficher sur la carte (contiendra le Tick et potentiellement l'utilisateur)
  final Set<Marker> _markers = {};

  // Référence locale au Tick, mise à jour par Provider
  late Tick _currentTickData;


  String? _tickAddress;
  bool _isFetchingAddress = false;

  @override
  void initState() {
    super.initState();
    // Initialiser avec les données passées via le constructeur
    _currentTickData = widget.tick;
    // Mettre à jour le marqueur initial du Tick
    _updateTickMarker();
    // Essayer de récupérer la position initiale de l'utilisateur (sans bloquer)
    _getCurrentUserLocation(centerMap: false);
    if (_currentTickData.latitude != null && _currentTickData.longitude != null) {
      _fetchAddressFromCoordinates(
          _currentTickData.latitude!, _currentTickData.longitude!);
    }
  }

  Future<void> _fetchAddressFromCoordinates(double lat, double lon) async {

    if (!mounted || _isFetchingAddress) return;

    setState(() {
      _isFetchingAddress = true;
      _tickAddress = null;
    });

    print("MapPage: Fetching address for $lat, $lon");

    try {

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;

        final street = place.street;
        final city = place.locality;

        // Construit la liste avec seulement ces deux éléments
        final addressParts = [street, city];


        _tickAddress = addressParts
            .where((part) => part != null && part.isNotEmpty)
            .join(', ');

        // Gérer le cas où ni la rue ni la ville ne sont trouvées
        if (_tickAddress!.isEmpty) {
            _tickAddress = "Adresse non détaillée";
        }
        print("MapPage: Fetched address: $_tickAddress");
      } else {
        print("MapPage: No address found for coordinates.");
        _tickAddress = "Adresse introuvable";
      }
    } catch (e, stacktrace) {
      print("MapPage: Error fetching address: $e");
      print(stacktrace);
      if (mounted) {
        _tickAddress = "Erreur de géocodage";
      }

    } finally {

      if (mounted) {
        setState(() => _isFetchingAddress = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final updatedTick = context.watch<TickService>().getTickById(widget.tick.id);

    if (updatedTick == null && mounted && ModalRoute.of(context)?.isCurrent == true) {

      print("MapPage: Tick ${widget.tick.id} no longer found in service. Popping.");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          CustomSnackBar.showError(context, "Ce Tick n'est plus disponible.");
          Navigator.of(context).pop();
        }
      });
    } else if (updatedTick != null && updatedTick != _currentTickData) {
      print("MapPage: Received update for Tick ${_currentTickData.id}");


      bool coordsChanged = (_currentTickData.latitude != updatedTick.latitude ||
          _currentTickData.longitude != updatedTick.longitude) &&
          updatedTick.latitude != null &&
          updatedTick.longitude != null;

      setState(() {
        _currentTickData = updatedTick;
        _updateTickMarker(); // Mettre à jour le marqueur avec les nouvelles données
      });


      if (coordsChanged) {
        _fetchAddressFromCoordinates(updatedTick.latitude!, updatedTick.longitude!);
      } else if (updatedTick.latitude == null || updatedTick.longitude == null) {

        if (_tickAddress != null) {
          setState(() => _tickAddress = null);
        }
      }

    }
  }


  @override
  void dispose() {
    _mapController?.dispose(); // Libérer le contrôleur de carte
    super.dispose();
  }

  // --- Gestion des Marqueurs ---

  /// Met à jour le marqueur du Tick sur la carte.
  void _updateTickMarker() {
    if (_currentTickData.latitude != null && _currentTickData.longitude != null) {
      final tickPosition = LatLng(_currentTickData.latitude!, _currentTickData.longitude!);
      final marker = Marker(
        markerId: MarkerId(_currentTickData.id),
        position: tickPosition,
        infoWindow: InfoWindow(
          title: _currentTickData.name,
          snippet: '${_currentTickData.statusDescription} - ${_currentTickData.formattedLastUpdate}',
        ),
        icon: _getMarkerIcon(_currentTickData.status),

      );
      // Remplacer l'ancien marqueur par le nouveau
      _markers.removeWhere((m) => m.markerId.value == _currentTickData.id);
      _markers.add(marker);

    } else {
      // Si pas de position, supprimer le marqueur
      _markers.removeWhere((m) => m.markerId.value == _currentTickData.id);
    }
    // Rafraîchir l'UI si le widget est toujours monté
    if (mounted) {
      setState(() {});
    }
  }

  /// Retourne l'icône de marqueur appropriée en fonction du statut du Tick.
  BitmapDescriptor _getMarkerIcon(TickStatus status) {
    // Utilise les teintes standard de BitmapDescriptor
    double hue;
    switch (status) {
      case TickStatus.active: hue = BitmapDescriptor.hueGreen; break;
      case TickStatus.moving: hue = BitmapDescriptor.hueAzure; break;
      case TickStatus.lowBattery: hue = BitmapDescriptor.hueOrange; break;
      case TickStatus.theftAlert: hue = BitmapDescriptor.hueRed; break;
      case TickStatus.disabled: hue = BitmapDescriptor.hueViolet; break;
      case TickStatus.inactive:
      case TickStatus.unknown:
      default: hue = BitmapDescriptor.hueMagenta; break;
    }
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  // --- Gestion de la Localisation Utilisateur ---

  /// Récupère la position actuelle de l'utilisateur.
  /// Met à jour `_userPosition` et gère les permissions/erreurs.
  Future<void> _getCurrentUserLocation({bool centerMap = false}) async {
    if (!mounted) return;
    setState(() => _isUserLocationLoading = true);

    // Définir les paramètres de précision souhaités
    const locationSettingsHigh = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Mettre à jour seulement si déplacé de 10m
      timeLimit: Duration(seconds: 10), // Timeout pour haute précision
    );
     const locationSettingsMedium = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50,
    );

    String? errorMsg; // Stocker le message d'erreur potentiel

    try {
      // 1. Vérifier si le service de localisation est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {

        throw Exception(ErrorMessages.locationServiceDisabled);
      }

      // 2. Vérifier et demander les permissions de localisation
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(ErrorMessages.permissionDeniedLocation);
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(ErrorMessages.permissionDeniedLocationExplain);
      }

      // 3. Obtenir la position
      Position position;
      try {
          // Tenter haute précision avec timeout
          position = await Geolocator.getCurrentPosition(locationSettings: locationSettingsHigh);
      } catch (e) {
          print("MapPage: High accuracy location failed ($e), falling back to medium...");
          // Si échec, tenter moyenne précision (sans timeout spécifique ici)
          position = await Geolocator.getCurrentPosition(locationSettings: locationSettingsMedium);
      }


      if (!mounted) return;

      _userPosition = LatLng(position.latitude, position.longitude);
      print("MapPage: User location updated: $_userPosition");

      // Centrer la carte si demandé et si la carte est prête
      if (centerMap && _mapController != null && _userPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_userPosition!, 16.0),
        );
      }

    } on Exception catch (e) {
      print("MapPage: Error getting user location: $e");

      errorMsg = e.toString().replaceFirst('Exception: ', '');

      _userPosition = null;
    } finally {
      if (mounted) {
        setState(() => _isUserLocationLoading = false);

        if (errorMsg != null) {

           SnackBarAction? action;
           if (errorMsg == ErrorMessages.permissionDeniedLocationExplain) {
              action = SnackBarAction(
                 label: AppTexts.openSettings.toUpperCase(),
                 onPressed: () async => await ph.openAppSettings(),
              );
           }
           CustomSnackBar.showError(context, errorMsg, action: action);
        }
      }
    }
  }

  // --- Contrôle de la Carte ---

  /// Centre la carte sur la dernière position connue du Tick.
  Future<void> _centerOnTick() async {
    if (_currentTickData.latitude == null || _currentTickData.longitude == null) {
        CustomSnackBar.show(context, message: AppTexts.noLocationAvailable, type: AlertType.info);
        return;
    }
    // Attendre que le contrôleur soit prêt si ce n'est pas déjà le cas
    if (_mapController == null) await _mapControllerCompleter.future;

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentTickData.latitude!, _currentTickData.longitude!),
        16.0,
      ),
    );
  }

  /// Centre la carte sur la position actuelle de l'utilisateur.
  /// Rafraîchit d'abord la position de l'utilisateur.
  Future<void> _centerOnUser() async {
    await _getCurrentUserLocation(centerMap: true);
  }

  // --- Actions du Tick ---

  /// Demande une mise à jour de la localisation du Tick via le service.
  Future<void> _requestLocationUpdate() async {
    if (_isLocateActionLoading || _isRingActionLoading) return;
    setState(() => _isLocateActionLoading = true);

    final tickService = Provider.of<TickService>(context, listen: false);
    final success = await tickService.requestTickLocation(_currentTickData.id);

    if (!mounted) return;
    setState(() => _isLocateActionLoading = false);

    if (success) {
      CustomSnackBar.show(context, message: AppTexts.locationRequestSent, type: AlertType.info);
      print("MapPage: Location request sent, now triggering data refresh...");
      _refreshTickData();
    } else {
      CustomSnackBar.showError(context, tickService.error ?? ErrorMessages.apiError);
    }
  }

  /// Demande à faire sonner le Tick via le service.
  Future<void> _ringTick() async {
    if (_isLocateActionLoading || _isRingActionLoading) return;
    setState(() => _isRingActionLoading = true);

    final tickService = Provider.of<TickService>(context, listen: false);
    final success = await tickService.ringTick(_currentTickData.id);

    if (!mounted) return;
    setState(() => _isRingActionLoading = false);

    if (success) {
      // Afficher un message de confirmation que la *commande* a été envoyée
      CustomSnackBar.showSuccess(context, AppTexts.ringingTickCommandSent);
    } else {
      // Afficher l'erreur renvoyée par TickService
      CustomSnackBar.showError(context, tickService.error ?? AppTexts.ringingTickError);
    }
  }

  // --- Navigation ---

  /// Navigue vers la page des paramètres du Tick.
  void _navigateToTickSettings() {
    // Vérifier si l'ID est valide avant de naviguer
    if (_currentTickData.id.isEmpty) {
      print("MapPage: Cannot navigate to settings, Tick ID is empty.");
      CustomSnackBar.showError(context, "Impossible d'ouvrir les paramètres (ID manquant).");
      return;
    }

    print("Navigating to settings for Tick ID: ${_currentTickData.id}");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TickSettingsPage(tickId: _currentTickData.id),
        settings: const RouteSettings(name: Routes.tickSettings),
      ),
    );
  }

  /// Navigue vers la page d'historique du Tick.
  void _navigateToHistory() {

      Navigator.push(
         context,
         MaterialPageRoute(
            builder: (context) => HistoryPage(
               tickId: _currentTickData.id,
               tickName: _currentTickData.name,
            ),
         ),
      );

  }

  Future<void> _refreshTickData() async {
    if (_isFetchingData) return;
    setState(() => _isFetchingData = true);

    final tickService = Provider.of<TickService>(context, listen: false);

    await tickService.fetchTicks();


    if (!mounted) return;

    setState(() => _isFetchingData = false);


    if (tickService.error != null) {
      CustomSnackBar.showError(context, "Erreur de rafraîchissement: ${tickService.error}");
    } else {

      print("MapPage: Tick data refreshed via fetchTicks().");
    }
  }

  void _showAddressActionsMenu(BuildContext context, LongPressStartDetails details, String address) {
    final bool canOpenMap = _currentTickData.latitude != null && _currentTickData.longitude != null;
    final double latitude = _currentTickData.latitude ?? 0;
    final double longitude = _currentTickData.longitude ?? 0;

    final position = RelativeRect.fromLTRB(
      details.globalPosition.dx,
      details.globalPosition.dy - 60,
      details.globalPosition.dx + 1,
      details.globalPosition.dy - 59,
    );


    final theme = Theme.of(context);
    final tooltipTheme = Theme.of(context).tooltipTheme;
    final bool isDark = theme.brightness == Brightness.dark;

    // Couleurs pour simuler le tooltip
    final tooltipBackgroundColor = tooltipTheme.decoration is BoxDecoration
        ? (tooltipTheme.decoration as BoxDecoration).color ?? (isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8))
        : (isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8));
    final tooltipTextColor = tooltipTheme.textStyle?.color ?? (isDark ? Colors.black : Colors.white);


    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: theme.cardColor,
      items: <PopupMenuEntry<String>>[

        // --- 1. Simulation du Tooltip (Item non cliquable) ---
        PopupMenuItem<String>(
          value: 'tooltip_display',
          padding: EdgeInsets.zero,
          enabled: false,
          height: 0,
          child: Container(
            padding: tooltipTheme.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 6.0),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            decoration: BoxDecoration(
              color: tooltipBackgroundColor,
              borderRadius: tooltipTheme.decoration is BoxDecoration
                  ? (tooltipTheme.decoration as BoxDecoration).borderRadius ?? BorderRadius.circular(4)
                  : BorderRadius.circular(4),
            ),
            child: Text(
              address,
              style: tooltipTheme.textStyle ?? TextStyle(color: tooltipTextColor, fontSize: 12),
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        ),



        // --- 2. Option Copier ---
        PopupMenuItem<String>(
          value: 'copy',
          height: 40,
          onTap: () {
            Clipboard.setData(ClipboardData(text: address));
            if (mounted) {
              CustomSnackBar.show(context, message: 'Adresse copiée !', type: AlertType.success);
            }
          },
          child: const Row(
            children: [
              Icon(Icons.copy_outlined, size: 20),
              SizedBox(width: 12),
              Text('Copier l\'adresse'),
            ],
          ),
        ),

        // --- 3. Option Ouvrir dans Maps (si coordonnées dispo) ---
        if (canOpenMap)
          PopupMenuItem<String>(
            value: 'open_map',
            height: 40,
            onTap: () async {
              final Uri googleMapsUrl = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
              );
              try {
                if (await canLaunchUrl(googleMapsUrl)) {
                  await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                } else {
                  if(mounted) CustomSnackBar.showError(context, 'Impossible d\'ouvrir Google Maps.');
                }
              } catch (e) {
                print("Error launching map URL: $e");
                if(mounted) CustomSnackBar.showError(context, 'Erreur lors de l\'ouverture de la carte.');
              }
            },
            child: const Row(
              children: [
                Icon(Icons.map_outlined, size: 20),
                SizedBox(width: 12),
                Text('Ouvrir dans Maps'),
              ],
            ),
          ),
      ],
    );
  }

  // --- Construction de l'UI ---

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTickData.name),
        actions: [
          const ThemeToggleButton(),
          // Bouton de rafraîchissement manuel (demande active de localisation)
          IconButton(

            icon: _isFetchingData
                ? const LoadingIndicator(size: 18)
                : const Icon(Icons.refresh),
            tooltip: "Actualiser les données",

            onPressed: _isFetchingData ? null : _refreshTickData,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppTexts.settings,
            onPressed: _navigateToTickSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Carte Google Maps ---
          SizedBox(

            height: MediaQuery.of(context).size.height * 0.5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Affiche la carte seulement si la position initiale est connue
                if (_currentTickData.latitude != null && _currentTickData.longitude != null)
                  GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_currentTickData.latitude!, _currentTickData.longitude!),
                      zoom: 16.0,
                    ),
                    markers: _markers,
                    style: themeService.isDarkMode(context) ? MapStyles.darkStyle : MapStyles.lightStyle,
                    onMapCreated: (GoogleMapController controller) {
                      if (!_mapControllerCompleter.isCompleted) {
                        _mapControllerCompleter.complete(controller);
                        _mapController = controller;
                      }
                      // Indiquer que la carte est chargée (même si le style met du temps)
                      if (mounted && _isMapLoading) setState(() => _isMapLoading = false);
                    },
                    myLocationButtonEnabled: false,
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                    zoomGesturesEnabled: true,
                    mapToolbarEnabled: false,
                  )
                else // Afficher message si pas de coordonnées initiales
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off_outlined, size: 50, color: Theme.of(context).disabledColor),
                          const SizedBox(height: 16),
                          Text(AppTexts.noLocationAvailable, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center,),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(

                            icon: _isLocateActionLoading ? const LoadingIndicator(size: 18, color: Colors.white) : const Icon(Icons.refresh, size: 18),
                            label: const Text(AppTexts.tryToLocate),
                            onPressed: _isLocateActionLoading || _isRingActionLoading ? null : _requestLocationUpdate,
                          )
                        ],
                      ),
                    ),
                  ),

                // Indicateur de chargement PENDANT que la carte s'initialise
                if (_isMapLoading && _currentTickData.latitude != null)
                  const Center(child: LoadingIndicator()),

                // Boutons flottants pour centrer la carte
                Positioned(
                  right: 16,
                  bottom: 90,
                  child: FloatingActionButton.small(
                    heroTag: "centerTickBtn",
                    onPressed: _centerOnTick,
                    tooltip: AppTexts.centerOnTick,
                    backgroundColor: themeService.isDarkMode(context)
                        ? AppTheme.dividerColorDark
                        : AppTheme.surfaceColorLight,
                    child: ImageIcon(
                      const AssetImage("assets/icon/tick_white.png"),
                      size: 24,
                      color: _getMarkerIcon(_currentTickData.status) == BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                        ? AppTheme.errorColor
                        : AppTheme.primaryColor,
                      ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 20,
                  child: FloatingActionButton.small(
                    heroTag: "centerUserBtn",
                    onPressed: _centerOnUser,
                    tooltip: AppTexts.centerOnMe,
                    backgroundColor: themeService.isDarkMode(context)
                        ? AppTheme.dividerColorDark
                        : AppTheme.surfaceColorLight,
                    child: _isUserLocationLoading
                      ? const LoadingIndicator(size: 18)
                      : const Icon(Icons.my_location,
                      color: AppTheme.primaryColor,),
                  ),
                ),
              ],
            ),
          ),

          // --- Section Inférieure (Infos, Actions) ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte d'informations du Tick
                  _buildTickInfoCard(),
                  const SizedBox(height: 24),

                  // Boutons d'action principaux
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ActionButton(
                        icon: Icons.location_searching,
                        label: AppTexts.locate,
                        onPressed: _requestLocationUpdate,
                        isLoading: _isLocateActionLoading,
                        isDisabled: _isLocateActionLoading || _isRingActionLoading,
                        color: AppTheme.accentColor,
                      ),
                      ActionButton(
                        icon: Icons.volume_up_outlined,
                        label: AppTexts.ring,
                        onPressed: _ringTick,
                        isLoading: _isRingActionLoading,
                        isDisabled: _isLocateActionLoading || _isRingActionLoading,
                        color: AppTheme.warningColor,
                      ),
                       ActionButton(
                        icon: Icons.history_outlined,
                        label: AppTexts.history_map_page,
                        onPressed: _navigateToHistory,
                        isDisabled: _isLocateActionLoading || _isRingActionLoading,
                      ),
                    ],
                  ),


                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit la carte affichant les informations détaillées du Tick.
  Widget _buildTickInfoCard() {
    return Card(
      // Utilise la CardTheme globale
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.info_outline,
              label: AppTexts.currentStatus,
              value: _currentTickData.statusDescription,
              valueColor: AppColors.getStatusColor(_currentTickData.status, context),
            ),
            const Divider(height: 16, thickness: 0.5),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              label: AppTexts.lastPosition,
              value: _isFetchingAddress
                  ? 'Chargement adresse...'
                  : _tickAddress ??
                  (_currentTickData.latitude != null && _currentTickData.longitude != null
                      ? '${_currentTickData.latitude!.toStringAsFixed(5)}, ${_currentTickData.longitude!.toStringAsFixed(5)}' // Fallback to coordinates
                      : AppTexts.noLocationAvailable),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.access_time,
              label: AppTexts.lastUpdate,
              value: _currentTickData.formattedLastUpdate,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: _getBatteryIcon(_currentTickData.batteryLevel),
              label: AppTexts.battery,
              value: _currentTickData.batteryLevel != null
                  ? '${_currentTickData.batteryLevel}%'
                  : 'Inconnu',
              valueColor: AppColors.getBatteryColor(_currentTickData.batteryLevel),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper pour construire une ligne d'information (Icône - Label: Valeur).
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final secondaryColor = textTheme.bodySmall?.color;

    // --- Logique pour le statut (inchangée) ---
    if (label == AppTexts.currentStatus) {
      final currentStatus = _currentTickData.status;
      if (currentStatus == TickStatus.disabled) {
        value = 'Désactivé';
        valueColor = AppTheme.errorColor;
      } else if (currentStatus == TickStatus.active) {
        value = 'Actif';
        valueColor = AppTheme.successColor;
      } else {
        value = _currentTickData.statusDescription;
        valueColor = AppColors.getStatusColor(currentStatus, context);
      }
    }
    // --- Fin logique statut ---

    // Widget affichant la valeur initiale (le Text)
    Widget valueWidget = Text(
      value,
      textAlign: TextAlign.right,
      style: valueStyle ??
          textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor ?? textTheme.bodyMedium?.color,
          ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );


    if (label == AppTexts.lastPosition && value != AppTexts.noLocationAvailable && value != 'Chargement adresse...')
    {

      final String addressValue = value;
      valueWidget = GestureDetector(

        onLongPressStart: (details) {
          print("Long press detected on address: $addressValue");
          _showAddressActionsMenu(context, details, addressValue);
        },
        child: valueWidget,
      );
    }



    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: secondaryColor),
          const SizedBox(width: 12),
          Text('$label:', style: textTheme.bodyMedium?.copyWith(color: secondaryColor)),
          const SizedBox(width: 8),
          Expanded(
            child: valueWidget,
          ),
        ],
      ),
    );
  }

  /// Retourne l'icône de batterie appropriée en fonction du niveau.
  IconData _getBatteryIcon(int? level) {
    if (level == null) return Icons.battery_unknown_outlined;
    if (level > 95) return Icons.battery_full_outlined;
    if (level > 80) return Icons.battery_6_bar_outlined;
    if (level > 60) return Icons.battery_5_bar_outlined;
    if (level > 40) return Icons.battery_3_bar_outlined;
    if (level > 20) return Icons.battery_1_bar_outlined;
    return Icons.battery_alert_outlined; // <= 20%
  }
}