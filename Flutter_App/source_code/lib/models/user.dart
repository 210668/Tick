import 'package:flutter/foundation.dart' show immutable;

/// Représente un utilisateur de l'application.
@immutable
class User {
  /// Identifiant unique de l'utilisateur (Cognito Sub).
  final String uid;

  /// Adresse email de l'utilisateur (utilisée pour la connexion).
  final String email;

  /// Nom d'affichage de l'utilisateur (peut être le nom complet).
  final String displayName;

  /// Constructeur principal.
  const User({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  /// Crée une instance `User` à partir d'une Map JSON (ex: réponse API ou attributs Cognito).
  factory User.fromJson(Map<String, dynamic> json) {

    final String userId = json['userId'] ?? json['uid'] ?? json['sub'] ?? '';
    final String userEmail = json['email'] ?? '';

    final String name = json['name'] ?? json['displayName'] ?? '';
    final String firstName = json['firstName'] ?? json['prénom'] ?? '';
    final String lastName = json['lastName'] ?? json['nom'] ?? '';

    String finalDisplayName = name;
    if (finalDisplayName.isEmpty && (firstName.isNotEmpty || lastName.isNotEmpty)) {
      finalDisplayName = '$firstName $lastName'.trim();
    }

    return User(
      uid: userId,
      email: userEmail,
      displayName: finalDisplayName.isNotEmpty ? finalDisplayName : 'Utilisateur',
    );
  }

  /// Convertit l'objet `User` en une Map JSON.
  /// Utile si l'objet doit être envoyé à une API (moins courant avec Amplify Auth).
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
    };
  }

  /// Crée une copie de l'objet `User` avec certaines valeurs modifiées.
  /// Utile pour la gestion d'état immuable.
  User copyWith({
    String? uid,
    String? email,
    String? displayName,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName;

  @override
  int get hashCode => uid.hashCode ^ email.hashCode ^ displayName.hashCode;

  @override
  String toString() {
    return 'User(uid: $uid, email: $email, displayName: $displayName)';
  }
}