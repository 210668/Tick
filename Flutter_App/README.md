# Application Mobile Tick (Flutter)

Ce dossier contient un APK précompilé pour Android et le code source de l'application mobile "Tick" .

## Installation via l'APK (Android)

Un fichier APK précompilé (`app-release.apk`) se trouve dans le dossier `/apk/` de ce répertoire (`Flutter_App/apk/`).
Vous pouvez transférer ce fichier sur un appareil Android et l'installer directement (vous devrez peut-être autoriser l'installation depuis des sources inconnues sur votre appareil).
**Note :** Cet APK est configuré avec les clés Firebase et Google Maps de notre projet de développement. Pour une utilisation ou une compilation personnelle, veuillez suivre les instructions de configuration ci-dessus.

## Installation via le code source

Le code source complet de l'application Flutter se trouve dans le sous-dossier `source_code/`.

### Prérequis pour la compilation
*   Flutter SDK (Version 3.10.0 ou plus récente recommandée)
*   Firebase CLI : `npm install -g firebase-tools` (puis `firebase login`)
*   FlutterFire CLI : `dart pub global activate flutterfire_cli`
*   Android Studio / VS Code avec les plugins Flutter et Dart
*   Un appareil ou émulateur Android/iOS
*   Un compte Firebase et un projet Firebase créé.

### Configuration avant compilation
Avant de compiler l'application, vous devrez configurer les éléments suivants :

1.  **Configuration de Firebase et génération de `firebase_options.dart` (Obligatoire) :**
    L'application utilise Firebase pour les notifications push (Firebase Cloud Messaging - FCM) et potentiellement d'autres services. Le fichier de configuration `lib/firebase_options.dart` qui lie l'application à un projet Firebase spécifique **n'est pas inclus dans ce dépôt pour des raisons de sécurité.**

    Pour générer ce fichier pour votre propre projet Firebase, suivez ces étapes :
    *   **Créez un projet Firebase :** Si vous n'en avez pas, allez sur la [console Firebase](https://console.firebase.google.com/) et créez un nouveau projet.
    *   **Enregistrez vos applications :** Dans votre projet Firebase, enregistrez vos applications iOS et Android.
        *   Pour **Android**, vous aurez besoin du nom du package (généralement trouvé dans `source_code/android/app/build.gradle`, sous `applicationId`). Vous devrez peut-être aussi fournir un certificat SHA-1 de débogage.
        *   Pour **iOS**, vous aurez besoin de l'ID de bundle (généralement trouvé dans Xcode ou dans `source_code/ios/Runner.xcodeproj/project.pbxproj`).
    *   **Activez FlutterFire CLI :** Si ce n'est pas déjà fait, exécutez `dart pub global activate flutterfire_cli` dans votre terminal.
    *   **Connectez-vous à Firebase :** Exécutez `firebase login` si vous n'êtes pas déjà connecté.
    *   **Configurez FlutterFire :** À la racine de votre projet Flutter (le dossier `source_code/`), exécutez la commande :
        ```bash
        flutterfire configure
        ```
        La CLI vous guidera pour sélectionner votre projet Firebase et les plateformes pour lesquelles vous souhaitez générer la configuration. Cela créera automatiquement le fichier `lib/firebase_options.dart`.
    *   Pour plus de détails, suivez le guide officiel : [Ajouter Firebase à votre application Flutter](https://firebase.google.com/docs/flutter/setup?hl=fr&platform=ios) (le lien que tu as fourni).

2.  **Clé API Google Maps :**
    *   Obtenez une clé API Google Maps depuis la [Google Cloud Console](https://console.cloud.google.com/google/maps-apis/) et activez l'API "Maps SDK for Android" et "Maps SDK for iOS".
    *   Pour Android : Ajoutez votre clé dans `source_code/android/app/src/main/AndroidManifest.xml` et dans `source_code/ios/Runner/AppDelegate.swift`:
        ```xml
        <application ...>
            <meta-data android:name="com.google.android.geo.API_KEY"
                       android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
            <!-- ... autres meta-data ... -->
        </application>
        ```
		```xml
        "api_key": [
			{
			  "current_key": "YOUR_GOOGLE_MAPS_API_KEY_HERE"
			}
		  ],
        ```
    *   Pour iOS : Ajoutez votre clé dans `source_code/ios/Runner/AppDelegate.swift` (ou `AppDelegate.m` si votre projet est plus ancien) :
        ```swift
        // Dans AppDelegate.swift
        import UIKit
        import Flutter
        import GoogleMaps // Assurez-vous d'importer GoogleMaps

        @UIApplicationMain
        @objc class AppDelegate: FlutterAppDelegate {
          override func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
          ) -> Bool {
            GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE") // Ajoutez cette ligne
            GeneratedPluginRegistrant.register(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
          }
        }
        ```
	*   Pour Web : Ajoutez votre clé dans `source_code/web/index.html`:
		```html
				<title>tick_app</title>
				<link rel="manifest" href="manifest.json">

				<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_GOOGLE_MAPS_API_KEY_HERE"></script>
			</head>
		<body>
        ```

3.  **URLs des Fonctions Lambda AWS :**
    *   Les URLs des fonctions backend sont définies dans `source_code/lib/utils/constants.dart`, dans la classe `ApiConfigURLs`.
    *   Pour que l'application communique avec un backend fonctionnel, ces URLs doivent être mises à jour pour pointer vers votre déploiement AWS. Pour l'évaluation, elles sont laissées en tant que placeholders.
        ```dart
        // Exemple dans source_code/lib/utils/constants.dart
        class ApiConfigURLs {
          static const String getMyTicksFunctionUrl = 'YOUR_FUNCTION_URL_HERE';
          // ... autres URLs ...
        }
        ```

### Compilation
1. Naviguez vers le dossier `source_code/`.
2. Exécutez `flutter pub get` pour installer les dépendances.
3. Exécutez `flutter run --release` pour installer l'application sur un appareil connecté ou un émulateur. Un Mac est requis pour installer l'application sur iOS.
4. Pour créer un build de release : `flutter build apk --release` ou `flutter build ios --release`.
