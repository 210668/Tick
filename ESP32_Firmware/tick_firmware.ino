// ==========================================================================
// --- Fichier Principal ESP32 Tick Tracker ---
// ==========================================================================

// -----------------------------------------------------------------------------
// --- Includes ---
// -----------------------------------------------------------------------------
#define TINY_GSM_MODEM_SIM7000      // Définit le type de modem pour TinyGSM // Définit le type de modem utilisé (SIM7000 : 4G + GPS intégré)
#define TINY_GSM_RX_BUFFER 1024     // Augmente le buffer RX pour TinyGSM // Définit la taille du buffer de réception du modem (plus de données peuvent être reçues)
#include <time.h>                   // Pour la synchronisation NTP // Permet d'obtenir la date et l'heure via un serveur NTP
#include <Ticker.h> // Permet d'exécuter des fonctions à intervalles réguliers (sans bloquer le programme)
#include "secret.h"                 // Contient les informations sensibles (WiFi, AWS) // Fichier séparé contenant les identifiants sensibles (WiFi, MQTT, etc.)

// Réseaux
#include <WiFi.h>                   // Pour la connexion WiFi standard // Pour se connecter à un réseau WiFi
#include <WiFiClientSecure.h>       // Pour la connexion TLS à AWS // Pour établir une connexion sécurisée via TLS (nécessaire pour AWS IoT)
#include <PubSubClient.h> // Bibliothèque pour utiliser le protocole MQTT (échange de messages avec un serveur)
#define MQTT_MAX_PACKET_SIZE 1024         // Pour la communication MQTT // Définit la taille maximale des paquets MQTT
#include <BLEDevice.h>              // Pour Bluetooth Low Energy (BLE) // Gestion du Bluetooth Low Energy (BLE) - périphérique
#include <BLEServer.h>              // Pour créer un serveur BLE // Permet de créer un serveur BLE (le module devient visible et connectable)
#include <BLEUtils.h>               // Utilitaires BLE // Utilitaires divers pour BLE
#include <BLEAdvertising.h>         // Pour la publicité BLE // Pour rendre l'appareil visible aux autres via BLE
#include <esp_wifi.h>               // Pour libérer la mémoire BLE/WiFi // Fournit un contrôle plus bas niveau du WiFi (désactivation partielle possible)

// Capteurs & Périphériques
#include <Adafruit_MPU6050.h>       // Pour l'accéléromètre/gyroscope // Pour utiliser le capteur de mouvement MPU6050 (accéléromètre + gyroscope)
#include <Adafruit_Sensor.h>        // Dépendance pour MPU6050 // Bibliothèque de base requise pour Adafruit_MPU6050
#include <TinyGsmClient.h>          // Pour communiquer avec le modem GSM/GPS // Pour dialoguer avec le modem GSM/4G (ex : SIM7000)

// Utilitaires
#include <ArduinoJson.h>            // Pour manipuler les données JSON
#include <Preferences.h>            // *** NOUVEAU : Pour la mémoire NVS ***

// -----------------------------------------------------------------------------
// --- Defines ---
// -----------------------------------------------------------------------------
// Pins Modem SIM7000 & GPS
#define UART_BAUD   115200          // Vitesse de communication Série avec le modem
#define PIN_DTR     25              // Pin DTR (optionnel selon le module)
#define PIN_TX      27              // ESP TX -> Modem RX
#define PIN_RX      26              // ESP RX <- Modem TX
#define PWR_PIN     4               // Pin pour contrôler l'alimentation du modem
#define LED_PIN     12              // Pin de la LED (intégrée ou externe)

// Communication Série
#define SerialMon Serial            // Moniteur Série principal (USB)
#define SerialAT  Serial1           // Port Série matériel pour communiquer avec le modem

// MQTT
#define AWS_IOT_PUBLISH_TOPIC   "Tick/location" // Topic MQTT principal pour publier la localisation
// #define AWS_IOT_SUBSCRIBE_TOPIC "Tick/command" // Décommenter si besoin d'un topic de commande

// BLE
#define SERVICE_UUID        "7a8274fc-0723-44da-ad07-2293d5a5212a" // REMPLACE PAR TON UUID UNIQUE !
#define BLE_TIMEOUT_MS      360000  // Timeout BLE : 120 secondes (2 minutes)

// Logique applicative
#define SEUIL_DEPLACEMENT_METRES 10.0 // Seuil pour considérer un déplacement significatif
#define INACTIVITY_TIMEOUT_MS (5 * 60 * 1000UL) // 5 minutes pour l'envoi périodique si inactif
#define TRACKING_DURATION_MS (3 * 60 * 1000UL)   // 3 minutes de tracking actif après mouvement
#define TRACKING_INTERVAL_MS (5 * 1000UL)       // Intervalle de check GPS pendant le tracking (15s)
#define MPU_SENSITIVITY_THRESHOLD 14.0 // Seuil Magnitude Accélération (A ajuster ! 11.0-13.0 souvent ok)

// *** NOUVEAU : Clé pour NVS ***
#define NVS_NAMESPACE "tracker_state"
#define NVS_KEY_REGISTERED "registered"

/*  -----------  BATTERIE  T‑SIM7000G  -----------  */
#define BAT_ADC_PIN  35        // diviseur déjà soudé sur le PCB
#define ADC_MAX      4095.0f   // ADC 12 bits
#define VREF         3.30f     // tension de référence ADC (≈3,3 V)
#define DIV_FACTOR   2.00f     // 100 kΩ / 100 kΩ  →  tension x2

uint8_t batteryPercent()
{
  // 1. Mesure la tension réelle de l’accu
  uint16_t raw = analogRead(BAT_ADC_PIN);
  float vbat   = (raw / ADC_MAX) * VREF * DIV_FACTOR;   // en volts
  // 2. Conversion tension → pourcentage (table « terrain » Li‑ion)
  if (vbat >= 4.20) return 100;
  if (vbat >= 4.10) return  90;
  if (vbat >= 4.00) return  80;
  if (vbat >= 3.90) return  70;
  if (vbat >= 3.80) return  60;
  if (vbat >= 3.70) return  50;
  if (vbat >= 3.60) return  40;
  if (vbat >= 3.50) return  30;
  if (vbat >= 3.40) return  20;
  if (vbat >= 3.30) return  10;
  return 0;
}



// -----------------------------------------------------------------------------
// --- Objets Globaux ---
// -----------------------------------------------------------------------------
WiFiClientSecure net;
PubSubClient client(net);
TinyGsm modem(SerialAT);
Adafruit_MPU6050 mpu;
BLEServer* pServer = NULL;
BLEAdvertising* pAdvertising = NULL;
StaticJsonDocument<512> doc;
char jsonBuffer[768];
Preferences preferences; // *** NOUVEAU : Objet pour NVS ***

// -----------------------------------------------------------------------------
// --- Variables Globales d'état ---
// -----------------------------------------------------------------------------
char macHex[13];
String nom = "";
float lastLat = 0.0;
float lastLon = 0.0;
unsigned long lastMqttReconnectAttempt = 0;
unsigned long lastInactifSend = 0;
bool isGPSActive = false;
bool mpuIsActive = false; // Vrai si mpu.begin() a réussi au moins une fois
bool isSleep = true;
volatile bool bleIsActive = false; // Vrai si BLE est initialisé/actif
volatile bool bleStopRequested = false; // Flag pour arrêt BLE demandé par callback
bool deviceIsRegistered = false; // *** NOUVEAU : Flag lu depuis NVS ***
enum TrackState { IDLE, STARTING, TRACKING, FINISHING };
TrackState currentTrackState = IDLE;
bool alreadySubscribed = false;
int bat= 90;
volatile bool reactivationBLEDemandee = false;

Ticker revive_timer;
bool tick_enabled = true;
bool is_temporarily_disabled = false;
bool restartLoopRequested = false;

unsigned long trackingStartTime = 0;
unsigned long lastTrackingCheck = 0;
// --- VARIABLES GLOBALES A AJOUTER ---

// -----------------------------------------------------------------------------
// --- Déclarations Anticipées de Fonctions ---
// -----------------------------------------------------------------------------
void stopBluetooth();
void initBluetooth();
void wifi();
void connectAWS();
void activerWifi();
void desactiverWifi();
void activerGPS();
void desactiverGPS();
bool getLoc(float &lat, float &lon);
void activerMPU();
void desactiverMPU();
bool checkMouvement();
void sendLoc(float lat, float lon, String type);
bool haversine(float lat, float lon, float seuil);
bool modeVeille();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void revive();
void disable();
void temporary_disable(int minutes);
void enable_modules() ;
void disable_modules();
void reactivateBLENow();
void subscribeToMQTTTopic();
// -----------------------------------------------------------------------------
// --- Classe Callback BLE ---
// -----------------------------------------------------------------------------
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      SerialMon.println(">>> Client BLE Connecté ! <<<");

      // *** NOUVEAU : Enregistrer l'état dans NVS lors de la PREMIERE connexion ***
      if (!deviceIsRegistered) { // Double check, même si la logique setup le prévient
        SerialMon.println("Première connexion BLE détectée. Enregistrement dans NVS...");
        preferences.begin(NVS_NAMESPACE, false); // Ouvre NVS en mode lecture/écriture
        preferences.putBool(NVS_KEY_REGISTERED, true);
        preferences.end(); // Ferme NVS
        deviceIsRegistered = true; // Met à jour le flag en mémoire vive également
        SerialMon.println("Appareil marqué comme enregistré.");
      } else {
        SerialMon.println("Note: Connexion BLE sur un appareil déjà enregistré.");
      }

      SerialMon.println("Demande d'arrêt définitif du Bluetooth...");
      bleStopRequested = true; // Signaler à setup() ou loop() d'arrêter BLE
    }
    void onDisconnect(BLEServer* pServer) {
      SerialMon.println("Client BLE Déconnecté.");
    }
};

// -----------------------------------------------------------------------------
// --- Fonctions BLE ---
// -----------------------------------------------------------------------------
void stopBluetooth() {
  if (bleIsActive || bleStopRequested) { // Garde cette condition large
    SerialMon.println("Arrêt du Bluetooth...");
    BLEAdvertising* pAdv = BLEDevice::getAdvertising();
    if (pAdv != nullptr) { // Si l'objet publicité existe // Check si en cours de pub
        pAdv->stop();
        SerialMon.println("Commande d'arrêt publicité BLE envoyée.");
    } else { SerialMon.println("Publicité BLE non active ou objet non trouvé."); }

    // Tentative de déconnexion propre du serveur si nécessaire
    if (pServer != nullptr) {
        // Peut-être déconnecter les clients connectés si besoin spécifique
        // pServer->disconnect(pServer->getConnId()); // A utiliser avec prudence
    }

    pAdvertising = NULL; // Reset pointeur

    // Désinitialisation BLE propre
    BLEDevice::deinit(true); // true = libère la mémoire contrôleur
    // La ligne suivante est souvent redondante avec deinit(true) mais peut être gardée par sécurité
    // esp_bt_controller_mem_release(ESP_BT_MODE_BTDM);

    SerialMon.println("Stack BLE désinitialisée et mémoire radio libérée.");
    pServer = NULL; // Reset pointeur
    bleIsActive = false;
    bleStopRequested = false; // Reset le flag de demande
    SerialMon.println("Bluetooth désactivé.");
  } else { SerialMon.println("Demande arrêt BLE, mais non actif/demandé."); }
}


void initBluetooth() {
  // *** NOUVEAU : Vérification supplémentaire au cas où, mais setup gère le flux principal ***
  if (deviceIsRegistered) {
      SerialMon.println("ERREUR INTERNE: initBluetooth appelé alors que l'appareil est déjà enregistré.");
      return;
  }
  if (bleIsActive) { SerialMon.println("Avertissement: initBluetooth appelé mais BLE déjà actif."); return; }
  if (nom == "") { SerialMon.println("ERREUR FATALE: Nom appareil vide pour initBluetooth."); return; }

  SerialMon.println("Initialisation BLE avec nom : " + nom);
  BLEDevice::init(nom.c_str()); // Init BLE Stack
  bleIsActive = true; // Marquer comme actif dès l'initialisation

  pServer = BLEDevice::createServer();
  if (pServer == nullptr) { SerialMon.println("ERREUR FATALE: Création serveur BLE échouée !"); stopBluetooth(); return; }
  pServer->setCallbacks(new MyServerCallbacks()); // Attache les callbacks (onConnect/onDisconnect)

  BLEService *pService = pServer->createService(SERVICE_UUID);
  if (pService == nullptr) { SerialMon.println("ERREUR FATALE: Création service BLE échouée !"); stopBluetooth(); return; }
  pService->start(); // Démarre le service

  pAdvertising = BLEDevice::getAdvertising();
  if (pAdvertising == nullptr) { SerialMon.println("ERREUR FATALE: Obtention objet Advertising échouée !"); stopBluetooth(); return; }
  pAdvertising->addServiceUUID(SERVICE_UUID); // Ajoute le service à la publicité
  pAdvertising->setScanResponse(true); // Permet aux scanners de demander plus d'infos
  //pAdvertising->setMinPreferred(0x06);  // Exemples de paramètres d'intervalle (optionnel)
  //pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising(); // Démarre la publicité

  bleStopRequested = false; // S'assurer que le flag est false au début
  SerialMon.println("BLE actif et en publicité. Attente connexion/timeout (" + String(BLE_TIMEOUT_MS / 1000) + "s)...");
}

// -----------------------------------------------------------------------------
// --- Fonctions WiFi & AWS --- [INCHANGÉES]
// -----------------------------------------------------------------------------
void wifi(){
  uint8_t mac[6];
  if (WiFi.status() == WL_CONNECTED) {
       WiFi.macAddress(mac);
       sprintf(macHex, "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
       if (nom == "") nom = "Tick-" + String(macHex);
       SerialMon.println("wifi(): Déjà connecté. MAC: " + String(macHex));
       return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  SerialMon.println("Attente connexion Wi-Fi (dans wifi())...");
  int wifi_retries = 0;
  while (WiFi.status() != WL_CONNECTED && wifi_retries < 30) { delay(500); SerialMon.print("."); wifi_retries++; }

  if (WiFi.status() == WL_CONNECTED) {
      SerialMon.println("\nConnecté au Wi-Fi ! (dans wifi())");
      SerialMon.print("Adresse IP: "); SerialMon.println(WiFi.localIP());
      WiFi.macAddress(mac);
      SerialMon.print("DEBUG: Tableau mac[]: "); for (int i=0;i<6;i++){ SerialMon.printf("%02X:", mac[i]); } SerialMon.println();
      sprintf(macHex, "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
      nom = "Tick-" + String(macHex);
      SerialMon.println("MAC formatée (macHex): " + String(macHex));
      SerialMon.println("Nom appareil (nom): " + nom);
  } else {
      SerialMon.println("\nÉchec connexion Wi-Fi. (dans wifi())");
      // Utiliser une MAC par défaut ou gérer l'erreur autrement
      strcpy(macHex, "000000000000"); nom = "Tick-FAILED";
      SerialMon.println("ATTENTION: MAC/Nom non définis.");
  }
}

void activerWifi() {
  if (WiFi.status() != WL_CONNECTED) {
      SerialMon.println("-> Activation/Connexion Wi-Fi...");
      WiFi.mode(WIFI_STA); wifi();
  } else { /* SerialMon.println("-> Wi-Fi déjà connecté."); */ }
}

void desactiverWifi(){
  if (WiFi.status() == WL_CONNECTED || WiFi.getMode() != WIFI_OFF) {
      SerialMon.println("-> Désactivation Wi-Fi...");
      client.disconnect(); // Déconnecter MQTT proprement avant de couper le WiFi
      WiFi.disconnect(true, true); // disconnect(wifioff, eraseap)
      WiFi.mode(WIFI_OFF); delay(100); // Force mode OFF
      if (WiFi.status() != WL_CONNECTED && WiFi.getMode() == WIFI_OFF) { SerialMon.println("-> Wi-Fi désactivé."); }
      else { SerialMon.println("-> Avertissement: WiFi possiblement pas désactivé."); }
  }
}


// Fonction pour désactiver les modules applicatifs (GPS, MPU)
void disable_modules() {
    SerialMon.println("--- Désactivation Modules Applicatifs (GPS, MPU) ---");
    //desactiverGPS(); // Assurer que le GPS est éteint
    desactiverMPU(); // Assurer que le MPU est en veille
}

// Fonction pour réactiver le module nécessaire à la reprise (MPU uniquement)
void enable_modules() {
    SerialMon.println("--- Activation Module pour Reprise (MPU) ---");
    activerMPU(); // Réveiller le MPU pour la détection en mode veille
    // NE PAS activer le GPS ici.
}

// Fonction pour désactiver logiquement le tracker (appelée via MQTT 'disable')
void disable() {
    if (!tick_enabled) {
        SerialMon.println("disable(): Déjà désactivé.");
        return; // déjà désactivé
    }
    SerialMon.println(">>> Commande disable() reçue et traitée <<<");

    disable_modules(); // Eteindre GPS et MPU
    tick_enabled = false; // *** Le flag clé pour arrêter la logique applicative ***
    is_temporarily_disabled = false; // Assurer que ce n'est pas un disable temporaire

    // *** Important: Si on était en mode Actif (!isSleep), forcer le retour logique à l'état Veille ***
    //     Ceci arrête la machine d'état Active (STARTING/TRACKING/FINISHING).
    if (!isSleep) {
        SerialMon.println("disable(): Forçage sortie du mode Actif vers état Veille logique (mais désactivé).");
        // Pas besoin de désactiver WiFi/GPS ici, disable_modules l'a fait
        // et on veut garder WiFi/MQTT actifs.
        isSleep = true; // Revenir à l'état logique de base
        currentTrackState = IDLE; // Réinitialiser la machine d'état active
        digitalWrite(LED_PIN, LOW); // Eteindre LED active si allumée
    }

    SerialMon.println(">>> Tracker logiquement DÉSACTIVÉ. Maintien écoute MQTT uniquement. <<<");
    // Optionnel: Allumer une LED spécifique (ex: Rouge fixe?) pour indiquer l'état désactivé
    // digitalWrite(LED_PIN, HIGH); // Ou une autre couleur si possible
}

// Fonction pour réactiver logiquement le tracker (appelée via MQTT 'revive')
void revive() {
    if (tick_enabled) {
         SerialMon.println("revive(): Déjà actif.");
         return; // déjà actif
    }
    SerialMon.println(">>> Commande revive() reçue et traitée <<<");

    enable_modules(); // Réactive MPU
    tick_enabled = true; // *** Réactive la logique applicative ***
    if (is_temporarily_disabled) {
        revive_timer.detach();
        is_temporarily_disabled = false;
    }

    // Forcer la réévaluation de l'état au prochain tour de loop
    restartLoopRequested = true;
    SerialMon.println(">>> Tracker logiquement RÉACTIVÉ. Reprise surveillance/veille au prochain cycle. <<<");
     // Optionnel: Eteindre la LED d'état désactivé
     // digitalWrite(LED_PIN, LOW);
}

// Fonction pour désactiver temporairement pendant X minutes
// Elle doit maintenant utiliser la même logique que disable/revive
void temporary_disable(int minutes) {
    if (!tick_enabled) {
        SerialMon.println("temporary_disable(): Déjà désactivé (permanent ou temporaire).");
        // On pourrait choisir de remplacer un disable permanent par un temporaire ici? Non, gardons simple.
        return;
    }
    SerialMon.println(">>> Commande temporary_disable(" + String(minutes) + ") reçue et traitée <<<");

    disable_modules(); // Eteindre GPS et MPU
    tick_enabled = false; // Arrêter logique applicative
    is_temporarily_disabled = true; // Marquer comme temporaire

    // Forcer sortie du mode Actif si nécessaire
    if (!isSleep) {
        SerialMon.println("temporary_disable(): Forçage sortie du mode Actif.");
        isSleep = true;
        currentTrackState = IDLE;
        digitalWrite(LED_PIN, LOW);
    }

    SerialMon.println("Tracker temporairement DÉSACTIVÉ pour " + String(minutes) + " min. Maintien écoute MQTT.");
    // Lancer le timer pour appeler revive() après la durée
    revive_timer.once(minutes * 60.0f, revive); // Utiliser float pour éviter overflow sur calcul secondes
}

void connectAWS() {
  if (bleIsActive) {
    SerialMon.println("connectAWS: Différé car BLE actif.");
    return;
  }
  if(WiFi.status() != WL_CONNECTED) {
    SerialMon.println("connectAWS: Différé car WiFi non connecté.");
    return;
  }
  if (client.connected()) {
    return; // Déjà connecté
  }

  if (millis() - lastMqttReconnectAttempt < 5000) {
    return;
  }
  lastMqttReconnectAttempt = millis();

  SerialMon.println("Configuration TLS pour AWS...");
  net.setCACert(AWS_CERT_CA);
  net.setCertificate(AWS_CERT_CRT);
  net.setPrivateKey(AWS_CERT_PRIVATE);

  client.setServer(AWS_IOT_ENDPOINT, 8883);
  client.setKeepAlive(60);

  SerialMon.println("Tentative connexion à AWS MQTT (" + String(AWS_IOT_ENDPOINT) + ")...");
  if (client.connect(macHex)) {
    SerialMon.println("✅ Connecté à AWS IoT !");

    // Reset du flag d’abonnement à chaque reconnexion
    alreadySubscribed = false;

    // === Appel de la fonction d’abonnement ici ===
    subscribeToMQTTTopic();  // <-- On s'abonne proprement une seule fois

  } else {
    SerialMon.print("❌ Échec connexion MQTT. État = ");
    SerialMon.print(client.state());
    SerialMon.print(" (");
    if (client.state() == MQTT_CONNECTION_TIMEOUT) SerialMon.print("Timeout");
    else if (client.state() == MQTT_CONNECTION_LOST) SerialMon.print("Connexion perdue");
    else if (client.state() == MQTT_CONNECT_FAILED) SerialMon.print("Échec connexion");
    else if (client.state() == MQTT_CONNECT_BAD_PROTOCOL) SerialMon.print("Mauvais protocole");
    else if (client.state() == MQTT_CONNECT_BAD_CLIENT_ID) SerialMon.print("Mauvais ID Client");
    else if (client.state() == MQTT_CONNECT_UNAVAILABLE) SerialMon.print("Service indispo");
    else if (client.state() == MQTT_CONNECT_BAD_CREDENTIALS) SerialMon.print("Mauvais identifiants");
    else if (client.state() == MQTT_CONNECT_UNAUTHORIZED) SerialMon.print("Non autorisé");
    else SerialMon.print("Code Erreur Inconnu");
    SerialMon.println(")");
  }
}

void subscribeToMQTTTopic() {
  if (!client.connected()) {
    SerialMon.println("subscribeToMQTTTopic: client non connecté.");
    return;
  }

  if (!alreadySubscribed) {
    String topic = "Tick/" + String(macHex);  // Ton topic personnalisé
    if (client.subscribe(topic.c_str())) {
      SerialMon.println("✅ Abonnement réussi à : " + topic);
      alreadySubscribed = true;
    } else {
      SerialMon.println("❌ Échec abonnement à : " + topic);
    }
  } else {
    SerialMon.println("subscribeToMQTTTopic: Déjà abonné, skip.");
  }
}
void reactivateBLENow() {
    SerialMon.println("\n--- Réactivation BLE demandée ---");

    // Désactiver les autres modules pour éviter les conflits pendant BLE
    disable_modules(); // Assurez-vous que cette fonction arrête bien GPS, MPU etc.
    //desactiverWifi(); // Assurez-vous que le WiFi est coupé

    // --- Lancer la séquence BLE ---
    initBluetooth(); // Lance BLE

    unsigned long bleStartTime = millis();
    bool connectionHappened = false;
    SerialMon.print("Attente connexion BLE ");
    while (bleIsActive && !bleStopRequested && (millis() - bleStartTime < BLE_TIMEOUT_MS)) {
        SerialMon.print(".");
        delay(500);
        yield(); // Important pour le watchdog
    }
    SerialMon.println();

    if (bleStopRequested) {
        connectionHappened = true;
        // Le flag NVS est mis à jour dans le callback onConnect
    }

    // --- Arrêter BLE après attente ---
    if (bleIsActive) {
        if (connectionHappened) {
            SerialMon.println("Connexion BLE détectée et traitée. Arrêt BLE...");
        } else {
            SerialMon.println("Timeout BLE atteint (" + String(BLE_TIMEOUT_MS / 1000) + "s). Arrêt BLE...");
        }
        stopBluetooth();
    } else {
        SerialMon.println("Note: BLE n'était pas ou plus actif à la fin de l'attente.");
    }

    SerialMon.println("Réactivation BLE terminée.");
    // À la sortie, le loop() devrait reprendre et (si tick_enabled)
    // réactiver les modules nécessaires via la logique de veille/actif.
}

// Callback MQTT - Modifié pour appeler les fonctions disable/revive existantes
void callback(char* topic, byte* payload, unsigned int length) {
  // ... (début du parsing JSON identique) ...
  StaticJsonDocument<256> incomingDoc;
  DeserializationError error = deserializeJson(incomingDoc, payload, length);

  if (error) {
    Serial.print("Erreur de parsing JSON : ");
    Serial.println(error.c_str());
    return;
  }

  const char* id = incomingDoc["id"];
  const char* type = incomingDoc["type"];

  // Vérifier si le message est pour ce device
  if (!id || strcmp(id, macHex) != 0) {
      // SerialMon.println("Message MQTT ignoré (ID non correspondant)");
      return;
  }

  SerialMon.print("Commande reçue pour cet appareil: "); SerialMon.println(type);

  // --- Gérer les commandes ---

  if (strcmp(type, "get_location") == 0) {
    Serial.println("📍 Demande de localisation reçue !");
    // ... (code d'envoi de la réponse identique) ...
    getLoc(lastLat,lastLon);

     StaticJsonDocument<256> responseDoc;
     responseDoc["id"] = String(macHex);
     responseDoc["type"] = "loc_update";
     responseDoc["lat"] = lastLat; // Utiliser les globales standard
     responseDoc["lng"] = lastLon;
     responseDoc["bat"] = batteryPercent(); // TODO: vraie valeur batterie
     serializeJson(responseDoc, jsonBuffer);

     if (client.connected()) {
         client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer);
         Serial.println("✅ Coordonnées envoyées !");
         } else {
              Serial.println("❌ Echec envoi coordonnées.");
         }

  } else if (strcmp(type, "is_dissociated") == 0 || strcmp(type, "RESET_PAIRING") == 0) {
    SerialMon.println("🔁 Commande RESET_PAIRING reçue. Réinitialisation demandée...");
    reactivationBLEDemandee = true; // Sera traité en début de loop

  } else if (strcmp(type, "disable") == 0) { // Utilise la commande "disable"
    SerialMon.println("⚫ Commande 'disable' reçue. Désactivation logique...");
    StaticJsonDocument<256> responseDoc2;
    responseDoc2["id"] = String(macHex);
    responseDoc2["type"] = "disabling_permanently";
    serializeJson(responseDoc2, jsonBuffer);
    disable();
    if (client.connected()) {
         client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer);
         Serial.println("✅disabling_permanently!");
         } else {
              Serial.println("❌ Echec envoi coordonnées.");
         }
 // Appel de la fonction existante qui utilise tick_enabled

  } else if (strcmp(type, "revive") == 0) { // Utilise la commande "revive"
    SerialMon.println("🟢 Commande 'revive' reçue. Réactivation logique...");
    StaticJsonDocument<256> responseDoc4;
    responseDoc4["id"] = String(macHex);
    responseDoc4["type"] = "revive";
    serializeJson(responseDoc4, jsonBuffer);
    disable();
    if (client.connected()) {
         client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer);
         Serial.println("✅revive");
         } else {
              Serial.println("❌ Echec envoi coordonnées.");
         }
    revive(); // Appel de la fonction existante qui utilise tick_enabled

  // --- Optionnel: Ajouter la gestion de temporary_disable ---
  } else if (strcmp(type, "temporary_disable") == 0) {
     if (incomingDoc.containsKey("value")) {
         int duration = incomingDoc["value"];
         if (duration > 0) {
             SerialMon.println("⏳ Commande 'temporary_disable' reçue pour " + String(duration) + " minutes.");
             StaticJsonDocument<256> responseDoc3;
             responseDoc3["id"] = String(macHex);
             responseDoc3["type"] = "disabling_temporarily";
             responseDoc3["value"] = duration;
             serializeJson(responseDoc3, jsonBuffer);
             temporary_disable(duration);
             if (client.connected()) {

              client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer);
              Serial.println("✅disabling_permanently!");
         } else {
              Serial.println("❌ Echec envoi coordonnées.");
         } // Appel de la fonction existante
         } else {
              SerialMon.println("Erreur: durée invalide pour temporary_disable.");
         }
     } else {
         SerialMon.println("Erreur: commande temporary_disable sans duration_minutes.");
     }
  }
   // Ajouter d'autres commandes ici si nécessaire
}


// -----------------------------------------------------------------------------
// --- Fonctions GPS --- [INCHANGÉES]
// -----------------------------------------------------------------------------
void activerGPS() {
    if (isGPSActive) return;
    SerialMon.println("-> Tentative activation GPS..."); // Message initial plus clair

    // S'assurer que l'alimentation SGPIO est active initialement
    SerialMon.println("  Activation initiale SGPIO (1)...");
    modem.sendAT("+SGPIO=0,4,1,1");
    modem.waitResponse(200L); // Donner un peu de temps à la commande
    delay(500);               // Attendre la stabilisation de l'alimentation du GPS

    SerialMon.print("  Première tentative modem.enableGPS()... ");
    if (modem.enableGPS()) {
        SerialMon.println("-> SUCCES !");
        isGPSActive = true;
    } else {
        SerialMon.println("-> ECHEC.");
        SerialMon.println("    Tentative de réinitialisation GPS via cycle d'alimentation SGPIO...");

        // Désactiver logiquement le GPS (bonne pratique avant de couper l'alim)
        SerialMon.print("    Désactivation logique (modem.disableGPS())... ");
        if(modem.disableGPS()) { // Envoie AT+CGNSPWR=0
            SerialMon.println("OK.");
        } else {
            SerialMon.println("Echec ou non nécessaire.");
        }
        
        // Couper l'alimentation matérielle via SGPIO
        SerialMon.print("    Coupure SGPIO (0)... ");
        modem.sendAT("+SGPIO=0,4,1,0");
        modem.waitResponse(200L);
        SerialMon.println("OK.");
        delay(2000); // Attendre un délai significatif avec l'alimentation coupée

        // Rétablir l'alimentation matérielle via SGPIO
        SerialMon.print("    Rétablissement SGPIO (1)... ");
        modem.sendAT("+SGPIO=0,4,1,1");
        modem.waitResponse(200L);
        SerialMon.println("OK.");
        delay(500); // Attendre stabilisation alim GPS

        SerialMon.print("  Deuxième tentative modem.enableGPS()... ");
        if (modem.enableGPS()) {
            SerialMon.println("-> SUCCES après réinitialisation !");
            isGPSActive = true;
        } else{
            SerialMon.println("-> ECHEC MÊME APRÈS RÉINITIALISATION.");
            isGPSActive = false; // S'assurer que le flag est correct
            // Optionnel: couper SGPIO si échec final
            // SerialMon.println("    Coupure SGPIO finale par précaution...");
            // modem.sendAT("+SGPIO=0,4,1,0"); modem.waitResponse(200L);
        }
    }
    // Log final sur l'état
    if(isGPSActive) {
        SerialMon.println("GPS activé.");
    } else {
        SerialMon.println("ERREUR: Le GPS n'a pas pu être activé.");
    }
}

void desactiverGPS(){
  if (!isGPSActive) return;
  SerialMon.println("-> Désactivation GPS...");
  modem.disableGPS();
  modem.sendAT("+SGPIO=0,4,1,0"); modem.waitResponse(1000L); // Eteindre alim GPS
  isGPSActive = false; SerialMon.println("Module GPS éteint.");
}

// Version getLoc avec attente non bloquante et client.loop()
bool getLoc(float &lat, float &lon) {
  float speed_kph=0, alt_m=0, accuracy_m=0; int vsat=0, usat=0, year=0, month=0, day=0, hour=0, min=0, sec=0;
  lat = 0.0; lon = 0.0;
  if (!isGPSActive) { SerialMon.println("Erreur getLoc: GPS non actif !"); return false; }

  SerialMon.print("Recherche localisation GPS ");
  for (int attempt = 1; attempt <= 2; attempt++) {
    SerialMon.print(".");
    if (modem.getGPS(&lat, &lon, &speed_kph, &alt_m, &vsat, &usat, &accuracy_m,
                     &year, &month, &day, &hour, &min, &sec)) {
         if (lat != 0.0 || lon != 0.0) { SerialMon.println(" -> OK!"); return true; }
         else { SerialMon.print("(0,0)"); }
    } else { SerialMon.print("(Fail)"); }

    if (attempt < 2) {
        unsigned long delayStartTime = millis();
        while(millis() - delayStartTime < 5000L) { // Attente 5 secondes entre tentatives
            if (!bleIsActive && WiFi.status() == WL_CONNECTED && client.connected()) { client.loop(); }
            delay(50);
        }
    }
  }
  SerialMon.println("\nÉchec getLoc après tentatives.");
  
  return false;
}

// -----------------------------------------------------------------------------
// --- Fonctions MPU --- [INCHANGÉES]
// -----------------------------------------------------------------------------
void activerMPU(){
  // Si déjà initialisé avec succès, juste le réveiller
  if (mpuIsActive) {
    //SerialMon.println("-> Réveil MPU6050...");
    mpu.enableSleep(false);
    delay(50); // Petit délai pour stabilisation après réveil
    // Vérifier si le réveil a fonctionné (optionnel)
    // uint8_t sleep_status; mpu.readPowerManagement1(&sleep_status);
    // if (sleep_status & MPU6050_SLEEP) SerialMon.println("Avertissement: MPU n'a pas pu être réveillé !");
    return;
  }
  // Première initialisation
  SerialMon.println("-> Initialisation MPU6050...");
  // Utiliser l'adresse I2C par défaut. S'assurer que Wire est initialisé (généralement fait par MPU lib)
  // Wire.begin(); // Décommenter si nécessaire
  if(!mpu.begin()) {
    SerialMon.println("ERREUR: MPU6050 non détecté. Vérifier connexion I2C.");
    mpuIsActive = false; // Marquer comme non initialisé
    return; // Ne pas continuer si l'init échoue
  }
  // Configuration initiale (optionnelle, à ajuster selon besoin)
  // mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
  // mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  // mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);

  mpu.enableSleep(false); // S'assurer qu'il n'est pas en veille après init
  delay(100); // Délai après initialisation
  SerialMon.println("MPU6050 initialisé et actif.");
  mpuIsActive = true; // Marquer comme initialisé avec succès
}

void desactiverMPU() {
  if (!mpuIsActive) {
      // SerialMon.println("-> MPU déjà inactif ou non initialisé.");
      return; // Ne rien faire si pas initialisé
  }
  SerialMon.println("-> Mise en veille MPU6050...");
  mpu.enableSleep(true); // Met le MPU en mode basse consommation
  delay(50); // Petit délai
  // Vérifier si la mise en veille a fonctionné (optionnel)
  // uint8_t sleep_status; mpu.readPowerManagement1(&sleep_status);
  // if (!(sleep_status & MPU6050_SLEEP)) SerialMon.println("Avertissement: MPU n'a pas pu être mis en veille !");
  // else SerialMon.println("MPU6050 mis en veille.");
  // Ne PAS mettre mpuIsActive à false ici, car il est toujours initialisé, juste endormi.
}

bool checkMouvement() {
  if (!mpuIsActive) { SerialMon.println("CheckMvt: MPU inactif/non initialisé."); return false; }
  sensors_event_t a, g, temp;
  if (mpu.getEvent(&a, &g, &temp)) {
    // Calcul de la magnitude du vecteur accélération
    // On soustrait g (environ 9.8) de l'axe Z si le capteur est à plat,
    // mais une simple magnitude est souvent suffisante pour la détection de chocs/mouvements brusques.
    float accelMagnitude = sqrt(a.acceleration.x * a.acceleration.x +
                              a.acceleration.y * a.acceleration.y +
                              a.acceleration.z * a.acceleration.z);

    // Décommenter pour affiner le seuil
    // SerialMon.printf(" MPU Mag=%.2f (X:%.1f Y:%.1f Z:%.1f) Thr=%.1f\n",
    //                  accelMagnitude, a.acceleration.x, a.acceleration.y, a.acceleration.z, MPU_SENSITIVITY_THRESHOLD);

    if (accelMagnitude > MPU_SENSITIVITY_THRESHOLD) {
      SerialMon.println("!!! MOUVEMENT DÉTECTÉ !!! Mag: " + String(accelMagnitude, 2));
      return true; // Mouvement détecté
    }
  } else {
      SerialMon.println("Erreur lecture MPU dans checkMouvement !");
      // Gérer l'erreur ? Tenter réinit ? Pour l'instant, retourne false.
      // Peut-être désactiver temporairement MPU check si erreurs répétées?
  }
  return false; // Pas de mouvement détecté ou erreur lecture
}


// -----------------------------------------------------------------------------
// --- Fonctions Utilitaires & Logique Applicative --- [INCHANGÉES]
// -----------------------------------------------------------------------------
bool haversine(float lat2, float lon2, float seuilMetres) {
  // Cas initial : si lastLat/lastLon sont à 0, tout nouveau point (non nul) est un "déplacement"
  if (lastLat == 0.0f && lastLon == 0.0f) {
      if (lat2 == 0.0f && lon2 == 0.0f) return false; // Ne pas considérer (0,0) comme un déplacement initial
      // SerialMon.println("Haversine: Premier point de référence enregistré.");
      return true; // Considérer le premier point valide comme un déplacement initial
  }
  // Si le nouveau point est (0,0), ce n'est pas un déplacement valide
  if (lat2 == 0.0f && lon2 == 0.0f) return false;

  const float R = 6371000.0f; // Rayon de la Terre en mètres
  // Conversion degrés en radians
  float lat1Rad = radians(lastLat);
  float lon1Rad = radians(lastLon);
  float lat2Rad = radians(lat2);
  float lon2Rad = radians(lon2);

  // Différences
  float dLat = lat2Rad - lat1Rad;
  float dLon = lon2Rad - lon1Rad;

  // Calcul Haversine
  float a = sin(dLat/2.0f)*sin(dLat/2.0f) +
            cos(lat1Rad)*cos(lat2Rad) *
            sin(dLon/2.0f)*sin(dLon/2.0f);
  float c = 2.0f * atan2(sqrt(a), sqrt(1.0f - a));
  float distance = R * c; // Distance en mètres

  // Affichage pour debug (optionnel)
  // SerialMon.print("Haversine dist: " + String(distance, 1) + "m ");

  // Comparaison avec le seuil
  if (distance >= seuilMetres) {
      SerialMon.println(" -> Déplacement significatif OUI (" + String(distance,0)+"m)");
      return true;
  }
  else {
      SerialMon.print(" -> Déplacement significatif NON ("+ String(distance,0)+"m)");
      return false;
  }
}

void sendLoc(float lat, float lon, String type) {
  doc["id"] = macHex;
  if(type == "loc_update") {
    doc["type"] = type;
  } else if(type == "movement_alert") {
    doc["type"] = type;
  } else if(type == "theft_alert") {
    doc["type"] = type;
  }
  // theft_alert  movement_alert periodic_update
  doc["lat"] = lat;
  doc["lng"] = lon;
  doc["bat"] = batteryPercent();
  serializeJson(doc, jsonBuffer);
  Serial.println(jsonBuffer);
  if (!client.connected()) {
    connectAWS();
  }
  connectAWS();
  client.publish(AWS_IOT_PUBLISH_TOPIC, jsonBuffer);
  Serial.println("Le message a bien été envoyé au serveur !");

  lastLat = lat;
  lastLon = lon;

}

bool modeVeille() {
  static bool firstEntryInSleep = true;

  if (firstEntryInSleep) {
      SerialMon.println("\n--- Entrée en Mode Veille ---");
      //desactiverGPS();
      //desactiverWifi(); // Ensure MQTT disconnects here too
      activerMPU();
      if (!mpuIsActive) {
          SerialMon.println("ERREUR CRITIQUE: MPU non fonctionnel pour la veille !");
      } else {
          SerialMon.println("MPU actif. Attente mouvement ou timeout périodique...");
      }
      lastInactifSend = millis();
      firstEntryInSleep = false;
      digitalWrite(LED_PIN, LOW);
  }

  // 1. Check for movement
  if (mpuIsActive && checkMouvement()) {
    SerialMon.println("modeVeille: Mouvement détecté !");
    SerialMon.println("modeVeille: ---> Signal pour sortir de veille (retourne false)");
    firstEntryInSleep = true; // Prepare for next sleep entry
    return false; // Exit sleep
  }

  // 2. Check for inactivity timeout
  if (millis() - lastInactifSend >= INACTIVITY_TIMEOUT_MS) {
    SerialMon.println("\nmodeVeille: Timeout inactivité atteint (" + String(INACTIVITY_TIMEOUT_MS / 60000UL) + "min). Envoi périodique...");
    digitalWrite(LED_PIN, HIGH);

    activerWifi();
    if(WiFi.status() == WL_CONNECTED) {
        connectAWS();
        if(client.connected()){
            activerGPS();
            float currentLat, currentLon;
            if (getLoc(currentLat, currentLon)) {
                // *** MODIFIED TYPE HERE ***
                sendLoc(currentLat, currentLon, "loc_update"); // Send periodic update
            } else {
                SerialMon.println("[Veille] Échec getLoc périodique.");
                // Send error or just skip? Current code sends error:
                sendLoc(0.0f, 0.0f, "loc_update");
            }
            //desactiverGPS();
        } else { SerialMon.println("[Veille] Echec connexion MQTT post-WiFi."); }
        //desactiverWifi(); // Disconnect WiFi after attempt
    } else { SerialMon.println("[Veille] Echec connexion WiFi pour envoi périodique."); }

    lastInactifSend = millis(); // Reset timer *after* the attempt
    SerialMon.println("modeVeille: Envoi périodique terminé (ou tentative). Retour attente...");
    digitalWrite(LED_PIN, LOW);
  }

  // Maintain MQTT if somehow connected (shouldn't happen if WiFi is off)
   if (client.connected()) { client.loop(); }

  return true; // Stay in sleep
}


// ==========================================================================
// SETUP - VERSION AVEC CHECK NVS
// ==========================================================================
void setup() {
    SerialMon.begin(115200); delay(2000);
    SerialMon.println("\n\n=============================================");
    SerialMon.println("--- Démarrage Tick Tracker (REVISED) ---");
    SerialMon.println("=============================================");
    SerialMon.println("Free Heap initial: " + String(ESP.getFreeHeap()));

    // --- Phase 0: Check NVS for Registration Status ---
    SerialMon.println("Vérification état enregistrement (NVS)...");
    preferences.begin(NVS_NAMESPACE, true); // Read-only mode
    deviceIsRegistered = preferences.getBool(NVS_KEY_REGISTERED, false);
    preferences.end();
    if (deviceIsRegistered) {
        SerialMon.println(">>> Appareil déjà enregistré via BLE. <<<");
    } else {
        SerialMon.println(">>> Appareil NON enregistré. Phase BLE initiale requise. <<<");
    }

    // --- Phase 1: WiFi Init for MAC Address / Device Name ---
    SerialMon.println("\n--- Phase 1: Initialisation WiFi (MAC/Nom) ---");
    wifi(); // Connecte et récupère macHex, nom
    if (nom == "" || nom == "Tick-FAILED") {
        SerialMon.println("ERREUR CRITIQUE: Impossible d'obtenir MAC/Nom via WiFi ! Arrêt.");
        wifi(); // Halt
    }
    SerialMon.println("MAC/Nom OK: " + nom);

    // --- Phase 2: Conditional BLE Pairing ---
    if (!deviceIsRegistered) {
        SerialMon.println("\n--- Phase 2: Initialisation et Attente BLE (Appairage) ---");
        initBluetooth(); // Start BLE advertising

        unsigned long bleStartTime = millis();
        bool connectionHappened = false;
        SerialMon.print("Attente connexion BLE ");
        // Wait for connection (bleStopRequested set in callback) or timeout
        while (bleIsActive && !bleStopRequested && (millis() - bleStartTime < BLE_TIMEOUT_MS)) {
            SerialMon.print(".");
            delay(500);
            yield(); // Prevent watchdog timeout
        }
        SerialMon.println();

        if (bleStopRequested) {
            connectionHappened = true; // Flag was set by the callback
            // NVS write is handled within the callback now
            SerialMon.println("Connexion BLE détectée et traitée (NVS mis à jour).");
        } else {
            SerialMon.println("Timeout BLE atteint (" + String(BLE_TIMEOUT_MS / 1000) + "s).");
        }

        // Stop BLE regardless of outcome
        if (bleIsActive) {
             SerialMon.println("Arrêt du module BLE...");
             stopBluetooth();
        } else {
             SerialMon.println("Note: BLE n'était pas/plus actif à la fin de l'attente.");
        }
        SerialMon.println("Phase BLE terminée.");
        // Re-check NVS in case connection happened just before timeout logic ended
        preferences.begin(NVS_NAMESPACE, true);
        deviceIsRegistered = preferences.getBool(NVS_KEY_REGISTERED, false);
        preferences.end();
        if(!deviceIsRegistered && !connectionHappened){
            SerialMon.println("AVERTISSEMENT: Timeout BLE sans connexion, appareil non enregistré. Redémarrage probable nécessaire pour appairer.");
             // Optional: force restart or halt? For now, continue.
        }

    } else {
        SerialMon.println("\n--- Phase 2: BLE ignoré (déjà enregistré) ---");
        bleIsActive = false; // Ensure state consistency
        bleStopRequested = false;
    }

    // --- Phase 3: Initialize Peripherals & Final Network ---
    SerialMon.println("\n--- Phase 3: Initialisation Modem, MPU, Réseau final ---");

    pinMode(LED_PIN, OUTPUT); digitalWrite(LED_PIN, LOW); // LED Off

    // Init Modem SIM7000 (Same as before)
    SerialMon.println("Allumage Modem SIM7000...");
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, HIGH);
    //Turn on the modem
    pinMode(PWR_PIN, OUTPUT);
    digitalWrite(PWR_PIN, HIGH);
    delay(1000);
    digitalWrite(PWR_PIN, LOW);
    delay(5000); // Wait for modem boot
    SerialAT.begin(UART_BAUD, SERIAL_8N1, PIN_RX, PIN_TX); delay(100);
    SerialMon.println("Test modem AT...");
    int retry = 0;
    while(retry < 5 && !modem.testAT(1000)){ SerialMon.print("."); delay(1000); retry++; }
    if(modem.testAT(1000)){
        SerialMon.println("\nModem OK.");
        SerialMon.println("Modem Info: " + modem.getModemInfo());
    } else {
        SerialMon.println("\nERREUR CRITIQUE: Modem ne répond pas ! Arrêt.");
         // Halt
    }

    // Init MPU6050
    SerialMon.println("Initialisation MPU6050...");
    activerMPU();  // Initialize
    desactiverMPU(); // Put to sleep immediately (starts in sleep mode)

    // Final WiFi/NTP/AWS Connection (if not already connected)
    SerialMon.println("Vérification/Connexion WiFi finale...");
    if (WiFi.status() != WL_CONNECTED) {
       SerialMon.println("WiFi non connecté. Tentative...");
       wifi(); // Retry connection
    }

    // Assign MQTT Callback *ONCE*
    client.setCallback(callback);
    alreadySubscribed = false; // Ensure we attempt subscription on first connect

    if (WiFi.status() == WL_CONNECTED) {
        SerialMon.println("Synchronisation NTP...");
        configTime(0, 0, "pool.ntp.org", "time.nist.gov"); struct tm timeinfo;
        if(!getLocalTime(&timeinfo, 10000)){
             SerialMon.println("ERREUR: Synchronisation NTP échouée!");
        } else {
             SerialMon.print("Heure locale: "); SerialMon.println(&timeinfo, "%A, %B %d %Y %H:%M:%S");
        }
        connectAWS(); // Attempt first MQTT connection
    } else {
        SerialMon.println("WiFi non connecté, impossible de synchroniser NTP ou connecter AWS pour le moment.");
    }

    // --- Phase 4: Set Initial Logical State ---
    SerialMon.println("\n--- Phase 4: Définition état initial ---");
    lastInactifSend = millis();   // Initialize inactivity timer
    isSleep = true;             // Start in logical sleep mode
    currentTrackState = IDLE;   // Active tracking state machine is idle
    tick_enabled = true;        // Start enabled by default
    is_temporarily_disabled = false;
    reactivationBLEDemandee = false; // Ensure flag is reset
    restartLoopRequested = false;
    activerGPS();    // Ensure flag is reset

    SerialMon.println("État initial: Veille logique (isSleep=true), Tick activé (tick_enabled=true)");
    SerialMon.println("=============================================");
    SerialMon.println("--- Fin Setup (REVISED) ---");
    SerialMon.println("Free Heap à la fin du setup: " + String(ESP.getFreeHeap()));
    SerialMon.println("=============================================");
    digitalWrite(LED_PIN, LOW); // Ensure LED is off before loop
}

// ==========================================================================
// LOOP - Version finale intégrant tick_enabled ET correction log subscribe
// ==========================================================================
void loop() {
    yield(); // Essentiel pour ESP32

    // --- 0. Gérer le redémarrage logique demandé par revive() ---
    if (restartLoopRequested) {
        SerialMon.println("\n🔄 Redémarrage logique du loop demandé par revive().");
        restartLoopRequested = false;
        isSleep = true; // Revenir en état Veille par défaut après reviveTRAcking
        currentTrackState = IDLE;
        // On continue l'exécution pour que la logique (maintenant activée) s'exécute
    }

    // --- 1. Gérer la demande de réactivation BLE (RESET_PAIRING) ---
    if (reactivationBLEDemandee) {
        SerialMon.println("\n*** Traitement RESET_PAIRING ***");
        // Arrêter les modules avant de redémarrer pourrait être plus propre
        //desactiverGPS();
        //desactiverWifi(); // Inclut client.disconnect()
        desactiverMPU();
        // Effacer le flag NVS
        SerialMon.println("Effacement flag NVS...");
        preferences.begin(NVS_NAMESPACE, false);
        preferences.putBool(NVS_KEY_REGISTERED, false);
        preferences.end();
        deviceIsRegistered = false;
        reactivationBLEDemandee = false;
        SerialMon.println("Redémarrage système pour appairage...");
        delay(1000); // Laisser le temps aux logs de s'afficher
        ESP.restart();
    }

    // --- 2. Maintenance Réseau (WiFi & MQTT) - TOUJOURS ACTIF ---
    //    Objectif: Garder la connexion pour recevoir les commandes, notamment 'revive'.
    bool networkMaintenanceDone = false; // Flag pour savoir si on a fait le travail réseau ce tour
    if (!bleIsActive) { // Toujours vrai après setup
        if (WiFi.status() != WL_CONNECTED) {
            // Tenter reconnexion WiFi périodiquement
            static unsigned long lastWifiRecAtt = 0;
            if (millis() - lastWifiRecAtt > 30000UL) { // Toutes les 30s
                lastWifiRecAtt = millis();
                SerialMon.println("[Maintenance Réseau] WiFi déconnecté! Tentative reconnexion...");
                activerWifi(); // Peut prendre du temps
                networkMaintenanceDone = true;
            }
        } else {
            // WiFi est connecté, gérer MQTT
            if (!client.connected()) {
                // Tenter reconnexion MQTT (connectAWS appellera subscribe si succès)
                connectAWS();
                networkMaintenanceDone = true;
            } else {
                // >>> Point crucial: Écouter MQTT <<<
                client.loop();
                // subscribeToMQTTTopic(); // <<< APPEL SUPPRIMÉ ICI - géré par connectAWS
                networkMaintenanceDone = true;
            }
        }
    } // Fin (!bleIsActive)

    // --- 3. Exécution Logique Applicative OU État Désactivé ---
    if (!bleIsActive) { // Toujours vrai après setup
        if (tick_enabled) {
            // *** TRACKER ACTIVÉ ***
            // La logique Veille/Actif s'exécute ici

            if (isSleep) {
                // *** Mode Veille Logique (équivalent "Active-Veille") ***
                bool detecteMouvement = !modeVeille(); // Gère MPU check, envoi périodique, WiFi/GPS on/off
                if (detecteMouvement) {
                    // Transition vers Mode Actif
                    SerialMon.println("Loop: Mouvement détecté. Passage état Actif.");
                    isSleep = false;
                    trackingStartTime = millis();
                    lastTrackingCheck = millis();
                    currentTrackState = STARTING;
                    digitalWrite(LED_PIN, HIGH); // LED Active/Alerte (ex: Rouge)
                }
                // else: Rester en veille, modeVeille a fait son travail

            } else {
                // *** Mode Actif (équivalent "Active-Surveillance") ***
                switch(currentTrackState) {
                    case STARTING:
                        SerialMon.println("[Mode Actif] Phase: STARTING");
                        activerMPU(); // Assurer MPU actif (même si veille le fait)
                        activerWifi(); // Assurer WiFi actif
                        if (WiFi.status() != WL_CONNECTED) { SerialMon.println("[Actif] Attente WiFi..."); delay(500); break; }

                        // Assurer connexion MQTT (connectAWS gère l'abonnement si connexion réussit)
                        if (!client.connected()) {
                            SerialMon.println("[Actif] Attente MQTT...");
                            connectAWS(); // Tente connexion
                            if(!client.connected()) { delay(500); break; } // Réessayer au prochain tour
                        } else {
                            client.loop(); // Important pour maintenir connexion existante
                            // subscribeToMQTTTopic(); // <<< APPEL SUPPRIMÉ ICI AUSSI
                        }

                        activerGPS(); // Activer GPS
                        if (!isGPSActive) { SerialMon.println("[Actif] Attente GPS..."); delay(500); break; }

                        // Si tout est prêt (WiFi, MQTT connecté, GPS actif)
                        SerialMon.println("[Actif] Prérequis OK. GetLoc initiale...");
                        float initialLat, initialLon;
                        if (getLoc(initialLat, initialLon)) { // getLoc gère tentatives et client.loop
                            sendLoc(initialLat, initialLon, "movement_alert");
                        } else {
                            SerialMon.println("[Actif] Échec getLoc initial.");
                            sendLoc(0.0f, 0.0f, "movement_alert");
                        }
                        // Transition vers TRACKING
                        currentTrackState = TRACKING;
                        lastTrackingCheck = millis();
                        trackingStartTime = millis();
                        SerialMon.println("[Actif] Passage Phase: TRACKING");
                        break; // Fin case STARTING

                    case TRACKING:
                        // Maintenir MQTT
                        if(client.connected()) client.loop(); else { connectAWS(); }

                        // Check fin durée
                        if (millis() - trackingStartTime >= TRACKING_DURATION_MS) {
                            SerialMon.println("[Actif] Fin période suivi.");
                            currentTrackState = FINISHING;
                            break;
                        }

                        // Check intervalle GPS
                        if (millis() - lastTrackingCheck >= TRACKING_INTERVAL_MS) { // Utilise le #define
                            lastTrackingCheck = millis();
                            SerialMon.print("[Actif Suivi] Vérif. GPS...");
                            // Re-check prérequis rapides
                            if (WiFi.status() != WL_CONNECTED) { SerialMon.println(" WiFi perdu!"); activerWifi(); break; }
                            if (!client.connected()) { SerialMon.println(" MQTT perdu!"); connectAWS(); break; }
                            if (!isGPSActive) { SerialMon.println(" GPS inactif!"); activerGPS(); break; }

                            // Get Loc et envoi si déplacement
                            float currentLat, currentLon;
                            if (getLoc(currentLat, currentLon)) { // getLoc a client.loop()
                                SerialMon.print(" Pos OK.");
                                if (haversine(currentLat, currentLon, SEUIL_DEPLACEMENT_METRES)) {
                                    SerialMon.println(" Déplacement -> Alerte Vol!");
                                    sendLoc(currentLat, currentLon, "theft_alert");
                                } else {
                                    SerialMon.println(" Pas de déplacement.");
                                }
                            } else {
                                SerialMon.println(" Échec getLoc pendant suivi.");
                                // Optionnel: sendLoc(0.0f, 0.0f, "error_gps_tracking");
                            }
                        }
                        break; // Fin case TRACKING

                    case FINISHING:
                        SerialMon.println("[Mode Actif] Phase: FINISHING");
                        //desactiverGPS();
                        //desactiverWifi(); // Coupe WiFi et déconnecte MQTT
                        desactiverMPU(); // Mettre MPU en veille
                        isSleep = true; // Retour à l'état Veille Logique
                        currentTrackState = IDLE; // Réinitialiser état actif
                        digitalWrite(LED_PIN, LOW); // LED Veille (ex: Vert discret ou OFF)
                        SerialMon.println(">>> Retour en Mode Veille Logique <<<");

                        break; // Fin case FINISHING

                    case IDLE:
                         // Sécurité: si on arrive ici en mode actif, forcer retour veille
                         SerialMon.println("Avertissement: État Actif IDLE inattendu. Forçage retour veille.");
                         currentTrackState = FINISHING;
                         break;

                 } // fin switch(currentTrackState)
            } // Fin else (!isSleep)

        } else {
            // *** TRACKER DÉSACTIVÉ (tick_enabled == false) ***
            // La maintenance réseau (section 2) s'assure que client.loop() tourne.
            // Aucune action applicative ici (pas de modeVeille, pas de machine d'état active).
            static unsigned long lastDisabledLog = 0;
            if (millis() - lastDisabledLog > 15000UL) { // Log toutes les 15s
                 lastDisabledLog = millis();
                 SerialMon.println("[Loop] Tracker DÉSACTIVÉ. Écoute MQTT active.");
                 // Optionnel: Gérer une LED d'état spécifique (ex: Rouge fixe ou clignotant lent)
                 // digitalWrite(LED_PIN, HIGH); // Exemple: Rouge fixe si LED = Rouge
            }
        }
    } // Fin if (!bleIsActive)

    // --- 4. Délai final court ---
    // Important pour la stabilité et éviter de saturer le CPU
    delay(50);

} // Fin loop()