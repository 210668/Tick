# Projet Tick : Système de sécurité et de suivi IoT pour véhicules personnels

<img src="./Flutter_App/source_code/assets/icon/icon.png" alt="Logo Tick" width="250">

Bienvenue sur le dépôt GitHub du projet "Tick", réalisé dans le cadre du cours de Projet d'Ingénierie Informatique (E56) à la Faculté Polytechnique de Mons (UMONS) durant l'année académique 2024-2025.

**Membres du groupe :**
*   Maximilien Zarioh
*   Ayoub Hamam
*   Aymeric De Volder
*   Mohammed Kebbab
*   Walid Mellouki

## Contexte du projet

Face à l’augmentation du nombre de vols de scooters, motos, trottinettes, etc., la sécurité des véhicules personnels est devenue une préoccupation majeure. L’objectif de ce projet est de réaliser un système de sécurité et de suivi pour les véhicules personnels, incluant une détection de mouvement pour alerter les propriétaires en cas de mouvements suspects ou non autorisés de leur véhicule.

## Structure du dépôt

Ce dépôt est organisé en plusieurs parties principales :

*   **`/ESP32_Firmware`**: Contient le code source du firmware pour le microcontrôleur ESP32 (carte LilyGO T-SIM7000G), ainsi que les instructions détaillées pour la configuration de l'environnement, le téléversement du code et la gestion des dépendances.
    *   [Lien vers le README du Firmware ESP32](./ESP32_Firmware/README.md)

*   **`/Flutter_App`**: Contient le code source complet de l'application mobile multiplateforme (iOS/Android) développée avec Flutter, ainsi qu'un fichier APK précompilé pour une installation facile sur Android. Des instructions pour la compilation et la configuration des clés API nécessaires sont également fournies.
    *   [Lien vers le README de l'Application Flutter](./Flutter_App/README.md)

*   **`/AWS_Backend_Documentation`**: Contient la documentation relative à l'infrastructure backend hébergée sur Amazon Web Services. Cela inclut un diagramme d'architecture et une description des services utilisés (IoT Core, Lambda, DynamoDB, Cognito, IAM).
    *   [Lien vers la Documentation du Backend AWS](./AWS_Backend_Documentation/README.md)

## Guide d'installation et de déploiement

Pour installer et déployer l'ensemble du système "Tick", veuillez consulter les README spécifiques à chaque composant listés ci-dessus.

### 1. Firmware ESP32

Le firmware est conçu pour la carte LilyGo T-SIM7000G. Il gère la lecture des capteurs (GPS, accéléromètre MPU6050), la communication cellulaire 4G, le Bluetooth Low Energy (BLE) pour l'appairage, et l'envoi des données via MQTT à AWS IoT Core.

**Prérequis et instructions détaillées :** [Consulter le README du Firmware ESP32](./ESP32_Firmware/README.md)

**Fichiers clés :**
*   `[NomDeVotreFichierPrincipal].ino` : Code principal du firmware.
*   `secret.h.example` : Template pour le fichier `secret.h` contenant les informations sensibles (identifiants WiFi, endpoint AWS, certificats). **Vous devrez créer votre propre fichier `secret.h` basé sur ce template et y insérer vos informations.**

### 2. Application mobile Flutter

    L'application mobile permet aux utilisateurs de créer un compte, d'associer leurs dispositifs Tick, de visualiser la position de leurs véhicules en temps réel, de recevoir des alertes, et de gérer les paramètres.

    **Code source et instructions de compilation :** [Consulter le README de l'Application Flutter](./Flutter_App/README.md)

    **Installation rapide (Android) :**
    Un fichier APK précompilé (`app-release.apk`) est disponible dans le dossier `/Flutter_App/` pour une installation directe sur un appareil Android. [Consulter le README de l'Application Flutter](./Flutter_App/README.md)

    **Configuration Importante :**
    Si vous compilez l'application depuis les sources, vous devrez configurer plusieurs éléments :
    *   **Configuration Firebase :** L'application utilise Firebase (notamment pour les notifications push via FCM). Le fichier de configuration `lib/firebase_options.dart` n'est **pas inclus** dans ce dépôt pour des raisons de sécurité (il contiendrait des clés API spécifiques au projet). Si vous souhaitez compiler et exécuter l'application, vous devrez configurer votre propre projet Firebase et générer ce fichier. Des instructions détaillées sont fournies dans le README de l'application.
    *   **Clé API Google Maps :** À remplacer dans les fichiers de configuration natifs Android et iOS (instructions dans le README de l'application).
    *   **URLs des Fonctions Lambda :** Les URLs des fonctions backend AWS sont définies dans `lib/utils/constants.dart`. Pour une version fonctionnelle, ces URLs doivent pointer vers une instance déployée du backend. Pour l'évaluation, elles sont actuellement remplacées par des placeholders.

### 3. Infrastructure backend AWS

L'infrastructure backend utilise AWS IoT Core, Lambda, DynamoDB, Cognito, et IAM. Elle gère l'authentification des utilisateurs, la communication avec les dispositifs Tick, le stockage des données, et l'envoi des notifications.

**Documentation et diagramme d'architecture :** [Consulter la Documentation du Backend AWS](./AWS_Backend_Documentation/README.md)

**Note sur le déploiement pour l'évaluation :**
L'infrastructure AWS est actuellement déployée et fonctionnelle sur un compte AWS personnel. En raison des complexités liées à l'exportation et au partage direct d'une configuration AWS complète (incluant les certificats IoT, les configurations Cognito spécifiques, etc.) et pour garantir la sécurité des clés, nous proposons les options suivantes pour l'évaluation du backend :
1.  **Démonstration en direct :** Nous pouvons effectuer une démonstration complète du système fonctionnel.
2.  **Accès temporaire au compte AWS :** Si nécessaire pour une inspection plus approfondie, nous pouvons organiser un accès temporaire et sécurisé au compte AWS utilisé pour le projet, après avoir modifié les informations d'identification. Veuillez nous contacter pour cette option.

Nous avons exploré des outils comme Former2 et AWS IaC Generator, mais leur utilisation pour recréer fidèlement et simplement l'ensemble de l'infrastructure dans un autre compte s'est avérée non triviale dans le temps imparti pour ce projet.

## Rapport final du projet

Le rapport final détaillé du projet, incluant l'analyse, la conception, la mise en œuvre, les résultats, et les conclusions, est inclus au format PDF.

## Contact

Pour toute question ou information complémentaire, veuillez nous envoyer un message privé sur Github, ou alors nous contacter par mail au tickapp.help@gmail.com.
