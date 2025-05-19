# Firmware ESP32 pour le Tick

Ce firmware est pour la carte LilyGo T-SIM7000G et permet de suivre sa localisation. Il utilise le Wi-Fi, le GPS, le modem cellulaire SIM7000G, et communique avec AWS IoT.

## Prérequis

1.  **IDE Arduino** (Version 1.8.19 ou plus récente).
2.  **Support ESP32 pour Arduino :**
    *   Dans l'IDE Arduino : `Fichier > Préférences`.
    *   URL Gestionnaire de cartes : `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
    *   Puis `Outils > Type de carte > Gestionnaire de cartes...`, recherchez "esp32" et installez "esp32 by Espressif Systems".
3.  **Bibliothèques Arduino :**
    *   Depuis `Croquis > Inclure une bibliothèque > Gérer les bibliothèques...`, installez :
        *   `TinyGSM`
        *   `Adafruit MPU6050`
        *   `Adafruit Unified Sensor`
        *   `PubSubClient`
        *   `ArduinoJson` (v6.x.x)

## Configuration rapide

1.  **Créez `secret.h` :**
    *   À côté de votre fichier `.ino` principal, créez un fichier nommé `secret.h`.
    *   Copiez-y le contenu suivant et **modifiez les valeurs entre guillemets `""` et les certificats** :

    ```cpp
    #ifndef SECRET_H
    #define SECRET_H

    #include <pgmspace.h>

    #define THINGNAME "Tick_MonAppareil" // Optionnel: Nom pour AWS IoT

    // --- À MODIFIER ---
    const char WIFI_SSID[] = "VOTRE_WIFI_SSID";
    const char WIFI_PASSWORD[] = "VOTRE_MOT_DE_PASSE_WIFI";
    const char AWS_IOT_ENDPOINT[] = "xxxxxxxxxxxxxx-ats.iot.VOTRE_REGION.amazonaws.com";

    // Certificat CA Racine Amazon (Généralement Amazon Root CA 1)
    static const char AWS_CERT_CA[] PROGMEM = R"EOF(
    -----BEGIN CERTIFICATE-----
    [COPIEZ_ICI_VOTRE_CERTIFICAT_CA_AMAZON]
    -----END CERTIFICATE-----
    )EOF";

    // Certificat de l'appareil pour AWS IoT
    static const char AWS_CERT_CRT[] PROGMEM = R"KEY(
    -----BEGIN CERTIFICATE-----
    [COPIEZ_ICI_LE_CERTIFICAT_DE_VOTRE_APPAREIL]
    -----END CERTIFICATE-----
    )KEY";

    // Clé Privée de l'appareil pour AWS IoT
    static const char AWS_CERT_PRIVATE[] PROGMEM = R"KEY(
    -----BEGIN RSA PRIVATE KEY-----
    [COPIEZ_ICI_LA_CLÉ_PRIVÉE_DE_VOTRE_APPAREIL]
    -----END RSA PRIVATE KEY-----
    )KEY";

    #endif // SECRET_H
    ```

    **Important :** Obtenez `AWS_IOT_ENDPOINT`, `AWS_CERT_CRT`, et `AWS_CERT_PRIVATE` depuis votre console AWS IoT Core lors de la création d'un "Objet" (Thing). `AWS_CERT_CA` est le certificat racine d'Amazon.