import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/theme_service.dart';
import '../../utils/map_styles.dart';
import 'package:geocoding/geocoding.dart';


import '../../services/tick_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/loading_indicator.dart';

/// Modèle simple pour représenter un événement d'historique.
class HistoryEvent {
  final String id;
  final DateTime timestamp;
  final String eventType;
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final String description;

  HistoryEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.description,
    this.latitude,
    this.longitude,
    this.batteryLevel,
  });

  factory HistoryEvent.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp;
    final String timestampFieldName = 'timestamp_iso';

    if (json[timestampFieldName] is String) {
      parsedTimestamp = DateTime.tryParse(json[timestampFieldName] as String) ?? DateTime(1970);
      if (parsedTimestamp.year == 1970 && (json[timestampFieldName] as String).isNotEmpty) {
        print("CRITICAL: Failed to parse timestamp string from field '$timestampFieldName'. Value: ${json[timestampFieldName]}. JSON item: $json");
      }
    } else {
      print("CRITICAL: Timestamp field '$timestampFieldName' not found or not a String. JSON item: $json");
      parsedTimestamp = DateTime(1970);
    }

    double? lat;
    if (json['latitude'] is num) lat = (json['latitude'] as num).toDouble();
    if (lat == null && json['lat'] is num) lat = (json['lat'] as num).toDouble();

    double? lng;
    if (json['longitude'] is num) lng = (json['longitude'] as num).toDouble();
    if (lng == null && json['lng'] is num) lng = (json['lng'] as num).toDouble();

    int? bat;
    if (json['batteryLevel'] is num) bat = (json['batteryLevel'] as num).toInt();
    if (bat == null && json['bat'] is num) bat = (json['bat'] as num).toInt();
    if (bat == null && json['battery'] is num) bat = (json['battery'] as num).toInt();

    String type = json['eventType'] ?? 'unknown';
    String desc = json['description'] ?? _generateDefaultDescription(type, lat, lng, bat, parsedTimestamp);

    String tickIdentifier = json['tick_id'] ?? json['tickId'] ?? UniqueKey().toString();
    String eventId = "${tickIdentifier}_${parsedTimestamp.toIso8601String()}";


    return HistoryEvent(
      id: eventId,
      timestamp: parsedTimestamp,
      eventType: type,
      latitude: lat,
      longitude: lng,
      batteryLevel: bat,
      description: desc,
    );
  }

  static String _generateDefaultDescription(String type, double? lat, double? lng, int? bat, DateTime ts) {
    String timeStr = DateFormat('HH:mm', 'fr_FR').format(ts.toLocal());
    switch (type) {
      case 'periodic_update': return "Mise à jour périodique reçue à $timeStr.";
      case 'movement_alert': return "Mouvement détecté à $timeStr.";
      case 'theft_alert': return "⚠️ ALERTE DÉPLACEMENT à $timeStr !";
      case 'low_battery':
        String batteryText = bat != null ? " ($bat%)" : "";
        return "Batterie faible${batteryText} détectée à $timeStr.";
      case 'location_response': return "Position reçue à $timeStr.";
      case 'link_device': return "Appareil associé à $timeStr.";
      case 'unlink_device': return "Appareil dissocié à $timeStr.";
      case 'sound_alert': return "Sonnerie activée à $timeStr.";
      case 'temporary_disable': return "Surveillance désactivée à $timeStr.";
      case 'reactivate': return "Surveillance réactivée à $timeStr.";
      default: return "Événement système ($type) à $timeStr.";
    }
  }

  IconData get eventIcon {
    switch (eventType) {
      case 'periodic_update': return Icons.update_outlined;
      case 'movement_alert': return Icons.directions_walk;
      case 'theft_alert': return Icons.warning_amber_rounded;
      case 'low_battery': return Icons.battery_alert_outlined;
      case 'location_response': return Icons.gps_fixed;
      case 'link_device': return Icons.link;
      case 'unlink_device': return Icons.link_off;
      case 'sound_alert': return Icons.volume_up_outlined;
      case 'temporary_disable': return Icons.pause_circle_outline;
      case 'reactivate': return Icons.play_circle_outline;
      default: return Icons.history_edu_outlined;
    }
  }

  Color getEventColor(BuildContext context) {
    switch (eventType) {
      case 'theft_alert': return AppTheme.errorColor;
      case 'low_battery': return AppTheme.warningColor;
      case 'link_device':
      case 'unlink_device':
      case 'reactivate':
        return AppTheme.accentColor;
      case 'movement_alert':
      case 'location_response':
      case 'sound_alert':
      case 'temporary_disable':
        return AppTheme.primaryColor;
      case 'periodic_update':
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    }
  }

  /// Retourne une description plus lisible du type d'événement.
  String get eventTypeDescription {
    switch (eventType) {
      case 'periodic_update': return 'Mise à jour';
      case 'movement_alert': return 'Mouvement Détecté';
      case 'theft_alert': return 'Alerte Déplacement';
      case 'low_battery': return 'Batterie Faible';
      case 'location_response': return 'Position Reçue';
      case 'link_device': return 'Appareil Associé';
      case 'unlink_device': return 'Appareil Dissocié';
      case 'sound_alert': return 'Sonnerie Activée';
      case 'temporary_disable': return 'Surveillance Désactivée';
      case 'reactivate': return 'Surveillance Réactivée';
      default: return eventType;
    }
  }
}


class HistoryPage extends StatefulWidget {
  final String tickId;
  final String tickName;

  const HistoryPage({
    Key? key,
    required this.tickId,
    required this.tickName,
  }) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<HistoryEvent>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<HistoryEvent>> _fetchHistory() async {
    final tickService = Provider.of<TickService>(context, listen: false);
    try {
      final response = await tickService.getTickHistory(widget.tickId);
      if (response['success'] == true && response['data'] is List) {
        final List<dynamic> rawDataList = response['data'];
        List<HistoryEvent> events = rawDataList.map((data) {
          try {
            return HistoryEvent.fromJson(data as Map<String, dynamic>);
          } catch (e) {
            print("HistoryPage: Error parsing HistoryEvent JSON item: $e \nData: $data");
            return null;
          }
        }).whereType<HistoryEvent>().toList();
        print("HistoryPage: History processed successfully: ${events.length} events for ${widget.tickId}.");
        return events;
      } else {
        String errorMessage = response['error']?.toString() ?? ErrorMessages.apiError;
        print("HistoryPage: Error response received from getTickHistory: $errorMessage");
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("HistoryPage: Exception fetching history for ${widget.tickId}: $e");
      throw Exception(ErrorMessages.connectionFailed);
    }
  }

  Future<void> _refreshHistory() async {
    setState(() {
      _historyFuture = _fetchHistory();
    });
    await _historyFuture;
  }

  Future<String> _getAddressFromCoordinates(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        // Construire une adresse lisible
        final street = place.street;
        final city = place.locality;
        final addressParts = [street, city];
        String formattedAddress = addressParts
            .where((part) => part != null && part.isNotEmpty)
            .join(', ');
        return formattedAddress.isNotEmpty ? formattedAddress : "Adresse non détaillée";
      } else {
        return "Adresse introuvable";
      }
    } catch (e) {
      print("Error fetching address for history popup: $e");
      return "Erreur de géocodage";
    }
  }


  void _showLocationPopup(BuildContext context, HistoryEvent event) {
    if (event.latitude == null || event.longitude == null) {
      CustomSnackBar.show(context, message: "Position non disponible pour cet événement.", type: AlertType.info);
      return;
    }

    final LatLng eventPosition = LatLng(event.latitude!, event.longitude!);
    final String eventTime = DateFormat('le dd/MM/yy à HH:mm', 'fr_FR').format(event.timestamp.toLocal());
    final themeService = Provider.of<ThemeService>(context, listen: false);


    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {

        String displayAddress = "Chargement de l'adresse...";
        bool isLoadingAddress = true;


        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              // Fonction pour charger l'adresse une seule fois
              void fetchAddress() async {
                if (isLoadingAddress) {
                  String fetchedAddress = await _getAddressFromCoordinates(event.latitude!, event.longitude!);
                  if (mounted) {
                    setStateDialog(() {
                      displayAddress = fetchedAddress;
                      isLoadingAddress = false;
                    });
                  }
                }
              }


              if (isLoadingAddress) {

                WidgetsBinding.instance.addPostFrameCallback((_) => fetchAddress());
              }

              return AlertDialog(
                title: Text('Localisation - ${event.eventTypeDescription}', style: const TextStyle(fontSize: 18)),
                contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                content: SizedBox(
                  width: MediaQuery.of(dialogContext).size.width * 0.9,
                  height: MediaQuery.of(dialogContext).size.height * 0.45,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: GoogleMap(
                          mapType: MapType.normal,
                          initialCameraPosition: CameraPosition(
                            target: eventPosition,
                            zoom: 15.0,
                          ),
                          markers: {
                            Marker(
                              markerId: MarkerId('event_location_${event.id}'),
                              position: eventPosition,
                              infoWindow: InfoWindow(
                                title: event.eventTypeDescription,
                                snippet: isLoadingAddress ? 'Position à ${eventTime}' : displayAddress, // Affiche l'adresse dans l'InfoWindow
                              ),
                            ),
                          },
                          style: themeService.isDarkMode(context) ? MapStyles.darkStyle : MapStyles.lightStyle,
                          myLocationButtonEnabled: false,
                          myLocationEnabled: false,
                          zoomControlsEnabled: true,
                          zoomGesturesEnabled: true,
                          mapToolbarEnabled: false,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Column(
                          children: [
                            Text(
                              'Position à ${eventTime}',
                              textAlign: TextAlign.center,
                              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),

                            isLoadingAddress
                                ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text("Chargement adresse...", style: TextStyle(fontSize: 12)),
                              ],
                            )
                                : Text(
                              displayAddress,
                              textAlign: TextAlign.center,
                              style: Theme.of(dialogContext).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text(AppTexts.close),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTexts.history.replaceAll(" des alertes", "")),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHistory,
        child: FutureBuilder<List<HistoryEvent>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: LoadingIndicator());
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }
            final historyEvents = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: historyEvents.length,
              itemBuilder: (context, index) {
                final event = historyEvents[index];
                bool showDateHeader = index == 0 ||
                    !_isSameDay(historyEvents[index-1].timestamp, event.timestamp);
                return Column(
                  children: [
                    if (showDateHeader) _buildDateHeader(context, event.timestamp),
                    _buildHistoryListItem(event),
                  ],
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 0, indent: 72, thickness: 0.5),
            );
          },
        ),
      ),
    );
  }

  bool _isSameDay(DateTime dt1, DateTime dt2) {
    final localDt1 = dt1.toLocal();
    final localDt2 = dt2.toLocal();
    return localDt1.year == localDt2.year &&
        localDt1.month == localDt2.month &&
        localDt1.day == localDt2.day;
  }

  Widget _buildDateHeader(BuildContext context, DateTime timestamp) {
    final DateTime localTimestamp = timestamp.toLocal();
    final now = DateTime.now();
    String dateText;
    if (_isSameDay(localTimestamp, now)) {
      dateText = 'Aujourd\'hui';
    } else if (_isSameDay(localTimestamp, now.subtract(const Duration(days: 1)))) {
      dateText = 'Hier';
    } else {
      dateText = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(localTimestamp);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      alignment: Alignment.centerLeft,
      child: Text(
        dateText,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }


  Widget _buildHistoryListItem(HistoryEvent event) {
    final eventColor = event.getEventColor(context);
    final timeFormat = DateFormat('HH:mm:ss');
    final DateTime localTimestamp = event.timestamp.toLocal();
    final theme = Theme.of(context);

    final bool isClickable = event.latitude != null && event.longitude != null;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: eventColor.withOpacity(0.15),
        child: Icon(event.eventIcon, color: eventColor, size: 20),
      ),
      title: Text(
        event.description,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Row(
        children: [
          Text(
            timeFormat.format(localTimestamp),
            style: theme.textTheme.bodySmall,
          ),
          if (event.latitude != null && event.longitude != null)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(Icons.location_on_outlined, size: 12, color: theme.disabledColor),
            ),
          if (event.batteryLevel != null &&
              (event.eventType == 'low_battery' || event.eventType == 'periodic_update')) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(Icons.battery_std_outlined, size: 12, color: AppColors.getBatteryColor(event.batteryLevel)),
            ),
            const SizedBox(width: 2),
            Text('${event.batteryLevel}%', style: TextStyle(fontSize: 11, color: AppColors.getBatteryColor(event.batteryLevel))),
          ]
        ],
      ),
      dense: true,
      onTap: isClickable
          ? () => _showLocationPopup(context, event)
          : null,
    );
  }



  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_outlined, size: 80, color: Theme.of(context).disabledColor),
            const SizedBox(height: 24),
            Text(
              AppTexts.noHistoryAvailable,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Les événements de votre Tick apparaîtront ici.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text(AppTexts.retry),
              onPressed: _refreshHistory,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 60),
            const SizedBox(height: 16),
            Text(
              AppTexts.loadingHistoryError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString().replaceFirst("Exception: ", ""),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text(AppTexts.retry),
              onPressed: _refreshHistory,
            )
          ],
        ),
      ),
    );
  }
}