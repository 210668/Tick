/// Contient les styles JSON pour personnaliser l'apparence de Google Maps.

class MapStyles {

  /// Style JSON pour le mode sombre.
  /// Vise à réduire la luminosité et masquer les éléments non essentiels.
  static const String darkStyle = '''
[
  { "elementType": "geometry", "stylers": [ { "color": "#212121" } ] }, // Fond général
  { "elementType": "labels.icon", "stylers": [ { "visibility": "on" } ] }, // Masquer icônes POI
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#757575" } ] }, // Texte labels gris
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#212121" } ] }, // Contour texte labels
  { "featureType": "administrative", "elementType": "geometry", "stylers": [ { "color": "#757575" }, { "visibility": "on" } ] }, // Masquer lignes admin
  { "featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [ { "color": "#9e9e9e" } ] },
  { "featureType": "administrative.land_parcel", "stylers": [ { "visibility": "on" } ] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [ { "color": "#bdbdbd" } ] },
  { "featureType": "poi", "stylers": [ { "visibility": "on" } ] }, // Afficher tous les POI
  { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [ { "color": "#757575" } ] },
  { "featureType": "poi.park", "elementType": "geometry", "stylers": [ { "color": "#181818" }, { "visibility": "on" } ] }, // Afficher parcs (discret)
  { "featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [ { "color": "#616161" } ] },
  { "featureType": "poi.park", "elementType": "labels.text.stroke", "stylers": [ { "color": "#1b1b1b" } ] },
  { "featureType": "road", "elementType": "geometry.fill", "stylers": [ { "color": "#2c2c2c" } ] }, // Routes sombres
  { "featureType": "road", "elementType": "labels.text.fill", "stylers": [ { "color": "#8a8a8a" } ] }, // Texte routes gris clair
  { "featureType": "road", "elementType": "labels.icon", "stylers": [ { "visibility": "on" } ] }, // Masquer icônes routes (N°, etc.)
  { "featureType": "road.arterial", "elementType": "geometry", "stylers": [ { "color": "#373737" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#3c3c3c" } ] },
  { "featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [ { "color": "#4e4e4e" } ] },
  { "featureType": "road.local", "elementType": "labels.text.fill", "stylers": [ { "color": "#616161" } ] },
  { "featureType": "transit", "stylers": [ { "visibility": "on" } ] }, // Masquer transports en commun
  { "featureType": "transit", "elementType": "labels.text.fill", "stylers": [ { "color": "#757575" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#000000" } ] }, // Eau en noir
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [ { "color": "#3d3d3d" } ] }
]
''';

  /// Style JSON pour le mode clair.
  /// Exemple simple masquant POI/transit et ajustant la couleur de l'eau.
  static const String lightStyle = '''
[
  { "featureType": "poi", "stylers": [ { "visibility": "on" } ] },
  { "featureType": "transit", "stylers": [ { "visibility": "on" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#aadaff" } ] }, // Eau bleu clair
  { "featureType": "road", "elementType": "labels.icon", "stylers": [ { "visibility": "on" } ] }
]
''';
}