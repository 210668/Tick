
import 'package:flutter/foundation.dart' show immutable;
import 'package:intl/intl.dart';



/// Représente les différents états possibles d'un Tick.
enum TickStatus {
  active,       /// Fonctionnement normal, communication récente.
  inactive,     /// Pas de communication récente.
  lowBattery,   /// Niveau de batterie bas détecté.
  moving,       /// Mouvement détecté (sans changement de position majeur récent).
  theftAlert,   /// Déplacement significatif détecté (alerte vol).
  unknown,      /// Statut initial ou inconnu.
  disabled,     /// Appareil désactivé
}

/// Représente un appareil Tick GPS.
@immutable
class Tick {
  /// ID unique du Tick (probablement l'ID extrait du nom BLE).
  final String id;

  /// Nom personnalisé donné par l'utilisateur.
  final String name;

  /// Dernière latitude connue (peut être null).
  final double? latitude;

  /// Dernière longitude connue (peut être null).
  final double? longitude;

  /// Dernier niveau de batterie connu en pourcentage (peut être null).
  final int? batteryLevel;

  /// Date et heure de la dernière mise à jour reçue du Tick (peut être null).
  final DateTime? lastUpdate;

  /// Statut actuel déduit du Tick.
  final TickStatus status;

  /// ID de l'utilisateur propriétaire du Tick.
  final String ownerId;

  /// Adresse MAC Bluetooth du Tick (peut être null ou non pertinente après association).
  final String? macAddress;

  /// Index du son d'alarme sélectionné (peut être null si non défini).
  final int? selectedAlarmSoundIndex;

  /// Date et heure de fin de la désactivation temporaire (si applicable).
  final DateTime? disableEndTime;

  /// Constructeur principal.
  const Tick({
    required this.id,
    required this.name,
    required this.ownerId,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.lastUpdate,
    this.status = TickStatus.unknown,
    this.macAddress,
    this.selectedAlarmSoundIndex,
    this.disableEndTime,
  });

  /// Crée une instance `Tick` à partir d'une Map JSON (venant de l'API/DB).
  factory Tick.fromJson(Map<String, dynamic> json) {
    final String tickId = json['id'] as String? ?? json['tickId'] as String? ?? json['tick_id'] as String? ?? '';
    final String tickName = json['name'] ?? json['tickName'] ?? 'Tick Sans Nom';
    final String userId = json['ownerId'] ?? json['userId'] ?? '';
    final String? mac = json['macAddress'] as String?;

    double? lat;
    if (json['latitude'] is num) lat = (json['latitude'] as num).toDouble();
    if (lat == null && json['lastPosition']?['lat'] is num) lat = (json['lastPosition']['lat'] as num).toDouble();
    if (lat == null && json['lat'] is num) lat = (json['lat'] as num).toDouble();

    double? lng;
    if (json['longitude'] is num) lng = (json['longitude'] as num).toDouble();
    if (lng == null && json['lastPosition']?['lng'] is num) lng = (json['lastPosition']['lng'] as num).toDouble();
    if (lng == null && json['lng'] is num) lng = (json['lng'] as num).toDouble();

    int? bat;
    if (json['batteryLevel'] is num) bat = (json['batteryLevel'] as num).toInt();
    if (bat == null && json['battery'] is num) bat = (json['battery'] as num).toInt();
    if (bat == null && json['bat'] is num) bat = (json['bat'] as num).toInt();

    DateTime? lastUpdt;
    if (json['lastUpdate'] is String) lastUpdt = DateTime.tryParse(json['lastUpdate']);
    if (lastUpdt == null && json['lastUpdated'] is String) lastUpdt = DateTime.tryParse(json['lastUpdated']);
    if (lastUpdt == null && json['timestamp'] is num) {
      final tsNum = json['timestamp'] as num;
      if (tsNum > 1000000000000) {
        lastUpdt = DateTime.fromMillisecondsSinceEpoch(tsNum.toInt());
      } else {
        lastUpdt = DateTime.fromMillisecondsSinceEpoch(tsNum.toInt() * 1000);
      }
    }

    int? alarmIndex;
    if (json['selectedAlarmSoundIndex'] is num) {
      alarmIndex = (json['selectedAlarmSoundIndex'] as num).toInt();
    } else if (json['selectedAlarmSoundIndex'] is String) {
      alarmIndex = int.tryParse(json['selectedAlarmSoundIndex'] as String);
    }


    print("[Tick.fromJson] Raw disableEndTime from JSON for tick ${json['id'] ?? json['tickId']}: ${json['disableEndTime']}");
    DateTime? endTime;
    if (json['disableEndTime'] is String) {
      String dateTimeString = json['disableEndTime'] as String;
      print("[Tick.fromJson] Parsing disableEndTime as String: $dateTimeString");

      if (dateTimeString.contains('+00:00Z') || dateTimeString.contains('+0000Z')) {
        dateTimeString = dateTimeString.replaceAll(RegExp(r'\+00:?00Z$'), 'Z');
        print("[Tick.fromJson] Cleaned dateTimeString (removed +00:00): $dateTimeString");
      }

      else if (dateTimeString.endsWith('+00:00') && !dateTimeString.endsWith('Z')) {
        dateTimeString = dateTimeString.substring(0, dateTimeString.length - 6) + 'Z';
        print("[Tick.fromJson] Cleaned dateTimeString (replaced +00:00 with Z): $dateTimeString");
      }

      endTime = DateTime.tryParse(dateTimeString);

      if (endTime != null) {
        print("[Tick.fromJson] Successfully parsed to DateTime: ${endTime.toIso8601String()} (isUtc: ${endTime.isUtc})");
      } else {
        print("[Tick.fromJson] FAILED to parse string: $dateTimeString (original: ${json['disableEndTime']})");
      }

    } else if (json['disableEndTime'] is num) {
      print("[Tick.fromJson] Parsing disableEndTime as num: ${json['disableEndTime']}");
      final tsNum = json['disableEndTime'] as num;
      if (tsNum > 1000000000000) {
        print("[Tick.fromJson] Treating num as MILLISECONDS_SINCE_EPOCH");
        endTime = DateTime.fromMillisecondsSinceEpoch(tsNum.toInt(), isUtc: true);
      } else {
        print("[Tick.fromJson] Treating num as SECONDS_SINCE_EPOCH");
        endTime = DateTime.fromMillisecondsSinceEpoch(tsNum.toInt() * 1000, isUtc: true);
      }
      if (endTime != null) {
        print("[Tick.fromJson] Successfully parsed num to DateTime: ${endTime.toIso8601String()} (isUtc: ${endTime.isUtc})");
      }
    } else if (json['disableEndTime'] != null) {
      print("[Tick.fromJson] disableEndTime has UNEXPECTED TYPE: ${json['disableEndTime'].runtimeType}. Value: ${json['disableEndTime']}");
    }
    print("[Tick.fromJson] Final parsed disableEndTime for tick ${json['id'] ?? json['tickId']}: $endTime");


    TickStatus currentStatus = TickStatus.unknown;
    String? lastEventType = json['lastEventType'] as String?;

    if (lastEventType == 'theft_alert') {
      currentStatus = TickStatus.theftAlert;
    } else if (lastEventType == 'movement_alert') {
      currentStatus = TickStatus.moving;
    } else if (bat != null && bat <= 20) {
      currentStatus = TickStatus.lowBattery;
    } else if (lastUpdt != null) {
      if (DateTime.now().difference(lastUpdt).inHours < 24) {
        currentStatus = TickStatus.active;
      } else {
        currentStatus = TickStatus.inactive;
      }
    }
    if (json['status'] is String) {
      currentStatus = TickStatus.values.firstWhere(
              (e) => e.name == json['status'],
          orElse: () => currentStatus
      );
    }

    if (currentStatus != TickStatus.disabled &&
        endTime != null &&
        endTime.isAfter(DateTime.now())) {
      print("[Tick.fromJson] Setting status to disabled due to future disableEndTime: $endTime for tick $tickId");
      currentStatus = TickStatus.disabled;
    } else if (json['status'] == 'disabled' && (endTime == null || endTime.isBefore(DateTime.now()))) {

      print("[Tick.fromJson] Status is 'disabled' from API, but disableEndTime ($endTime) is past or null for tick $tickId. Keeping 'disabled'.");
    }


    return Tick(
      id: tickId,
      name: tickName,
      latitude: lat,
      longitude: lng,
      batteryLevel: bat,
      lastUpdate: lastUpdt,
      status: currentStatus,
      ownerId: userId,
      macAddress: mac,
      selectedAlarmSoundIndex: alarmIndex,
      disableEndTime: endTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'batteryLevel': batteryLevel,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'status': status.name,
      'ownerId': ownerId,
      'macAddress': macAddress,
      'selectedAlarmSoundIndex': selectedAlarmSoundIndex,
      'disableEndTime': disableEndTime?.toIso8601String(),
    };
  }

  Tick copyWith({
    String? id,
    String? name,
    Object? latitude = _sentinel,
    Object? longitude = _sentinel,
    Object? batteryLevel = _sentinel,
    Object? lastUpdate = _sentinel,
    TickStatus? status,
    String? ownerId,
    Object? macAddress = _sentinel,
    Object? selectedAlarmSoundIndex = _sentinel,
    Object? disableEndTime = _sentinel,
  }) {
    return Tick(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      latitude: latitude == _sentinel ? this.latitude : latitude as double?,
      longitude: longitude == _sentinel ? this.longitude : longitude as double?,
      batteryLevel: batteryLevel == _sentinel ? this.batteryLevel : batteryLevel as int?,
      lastUpdate: lastUpdate == _sentinel ? this.lastUpdate : lastUpdate as DateTime?,
      status: status ?? this.status,
      macAddress: macAddress == _sentinel ? this.macAddress : macAddress as String?,
      selectedAlarmSoundIndex: selectedAlarmSoundIndex == _sentinel
          ? this.selectedAlarmSoundIndex
          : selectedAlarmSoundIndex as int?,
      disableEndTime: disableEndTime == _sentinel ? this.disableEndTime : disableEndTime as DateTime?,
    );
  }

  String get formattedLastUpdate {
    if (lastUpdate == null) return 'jamais';
    final DateTime utcTimestamp = lastUpdate!;
    final DateTime localTimestamp = utcTimestamp.toLocal();
    final now = DateTime.now();
    final difference = now.difference(localTimestamp);

    final timeFormat = DateFormat('HH:mm', 'fr_FR');
    final dateTimeFormat = DateFormat('le dd/MM/yy à HH:mm', 'fr_FR');
    final weekdayFormat = DateFormat('EEEE', 'fr_FR');

    if (difference.inSeconds < 60) {
      return "à l'instant";
    } else if (difference.inMinutes < 60) {
      return "il y a ${difference.inMinutes} min";
    } else if (_isSameDay(localTimestamp, now)) {
      return "auj. à ${timeFormat.format(localTimestamp)}";
    } else if (_isSameDay(localTimestamp, now.subtract(const Duration(days: 1)))) {
      return "hier à ${timeFormat.format(localTimestamp)}";
    } else if (difference.inDays < 7) {
      return "${weekdayFormat.format(localTimestamp)} à ${timeFormat.format(localTimestamp)}";
    } else {
      return dateTimeFormat.format(localTimestamp);
    }
  }

  bool _isSameDay(DateTime dt1, DateTime dt2) {
    final localDt1 = dt1.toLocal();
    final localDt2 = dt2.toLocal();
    return localDt1.year == localDt2.year &&
        localDt1.month == localDt2.month &&
        localDt1.day == localDt2.day;
  }

  String get statusDescription {
    switch (status) {
      case TickStatus.active: return 'Actif';
      case TickStatus.inactive: return 'Inactif';
      case TickStatus.lowBattery: return 'Batterie faible';
      case TickStatus.moving: return 'Mouvement détecté';
      case TickStatus.theftAlert: return 'Déplacement détecté';
      case TickStatus.disabled: return 'Désactivé';
      case TickStatus.unknown:
      default: return 'Inconnu';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Tick &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              name == other.name &&
              latitude == other.latitude &&
              longitude == other.longitude &&
              batteryLevel == other.batteryLevel &&
              lastUpdate == other.lastUpdate &&
              status == other.status &&
              ownerId == other.ownerId &&
              macAddress == other.macAddress &&
              selectedAlarmSoundIndex == other.selectedAlarmSoundIndex &&
              disableEndTime == other.disableEndTime;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      batteryLevel.hashCode ^
      lastUpdate.hashCode ^
      status.hashCode ^
      ownerId.hashCode ^
      macAddress.hashCode ^
      selectedAlarmSoundIndex.hashCode ^
      disableEndTime.hashCode;

  @override
  String toString() {
    return 'Tick(id: $id, name: "$name", status: $status, disableEndTime: ${disableEndTime?.toIso8601String()}, lat: $latitude, lng: $longitude, bat: $batteryLevel, lastUpdate: ${lastUpdate?.toIso8601String()}, ownerId: $ownerId, alarmIdx: $selectedAlarmSoundIndex)';
  }
}

const Object _sentinel = Object();