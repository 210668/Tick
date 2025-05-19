import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

// Amplify
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/welcome_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/register_page.dart';
import 'screens/auth/change_password_page.dart';
import 'screens/auth/confirmation_page.dart';
import 'screens/auth/reset_password_page.dart';
import 'screens/tick/tick_list_page.dart';
import 'screens/tick/add_tick_page.dart';
import 'screens/tick/tick_settings_page.dart';

import 'screens/profile_page.dart';
import 'screens/settings/settings_page.dart';
import 'screens/settings/help_support_page.dart';
import 'screens/settings/about_page.dart';
import 'screens/settings/privacy_policy_page.dart';
import 'screens/settings/terms_of_service_page.dart';

// Services
import 'services/auth_service.dart';
import 'services/tick_service.dart';
import 'services/theme_service.dart';
import 'services/bluetooth_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

// Utils
import 'utils/theme.dart';
import 'utils/constants.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  // --- Initialisation Firebase ---
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully.");
  } catch (e) {
     print("CRITICAL: Firebase initialization failed: $e");
     runApp(const FirebaseInitErrorApp());
     return;
  }

  // --- Configuration Amplify ---
  final bool amplifyConfigured = await _configureAmplify();

  // --- Création des Instances de Service ---
  if (amplifyConfigured) {
    final apiService = ApiService();
    final authService = AuthService();
    final notificationService = NotificationService(apiService, authService);
    authService.setNotificationService(notificationService);
    final themeService = ThemeService();
    final bluetoothService = BluetoothService();
    final tickService = TickService(apiService, authService);


    bluetoothService.initialize();

    // --- Lancer l'Application ---
    runApp(MyApp(
      apiService: apiService,
      authService: authService,
      notificationService: notificationService,
      themeService: themeService,
      bluetoothService: bluetoothService,
      tickService: tickService,
    ));
  } else {
    runApp(const AmplifyConfigurationErrorApp());
  }
}

Future<bool> _configureAmplify() async {
  if (Amplify.isConfigured) return true;
  try {
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugins([authPlugin]);
    await Amplify.configure(amplifyconfig);
    print("Amplify configured successfully.");
    return true;
  } on Exception catch (e) {
    print("CRITICAL: Could not configure Amplify: $e");
    return false;
  }
}

class MyApp extends StatelessWidget {
  final ApiService apiService;
  final AuthService authService;
  final NotificationService notificationService;
  final ThemeService themeService;
  final BluetoothService bluetoothService;
  final TickService tickService;

  const MyApp({
    Key? key,
    required this.apiService,
    required this.authService,
    required this.notificationService,
    required this.themeService,
    required this.bluetoothService,
    required this.tickService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [

        Provider.value(value: apiService),
        ChangeNotifierProvider.value(value: authService),
        Provider.value(value: notificationService),
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: bluetoothService),
        ChangeNotifierProvider.value(value: tickService),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeServiceConsumed, _) {
          return MaterialApp(
            title: AppTexts.appName,
            theme: AppTheme.getLightTheme(),
            darkTheme: AppTheme.getDarkTheme(),
            themeMode: themeServiceConsumed.themeMode,
            debugShowCheckedModeBanner: false,
            initialRoute: Routes.splash,
            routes: {
              Routes.splash: (context) => const SplashScreen(),
              Routes.welcome: (context) => const WelcomePage(),
              Routes.login: (context) => const LoginPage(),
              Routes.register: (context) => const RegisterPage(),
              Routes.confirmSignUp: (context) => const ConfirmationPage(),
              Routes.passwordRecovery: (context) => const ResetPasswordPage(),
              Routes.tickList: (context) => const TickListPage(),
              Routes.addTick: (context) => const AddTickPage(),
              Routes.profile: (context) => const ProfilePage(),
              Routes.settings: (context) => const SettingsPage(),
              Routes.changePassword: (context) => const ChangePasswordPage(),
              Routes.helpSupport: (context) => const HelpSupportPage(),
              Routes.aboutApp: (context) => const AboutPage(),
              Routes.privacyPolicy: (context) => const PrivacyPolicyPage(),
              Routes.termsOfService: (context) => const TermsOfServicePage(),
            },
            onGenerateRoute: (settings) {
              print("Generating route for: ${settings.name}");
              if (settings.name == Routes.tickSettings) {
                final String? tickId = settings.arguments as String?;
                if (tickId != null) {
                  return MaterialPageRoute(
                    builder: (context) => TickSettingsPage(tickId: tickId),
                    settings: settings,
                  );
                } else {
                  print("Error: Missing tickId argument for TickSettingsPage");
                  return MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Erreur : ID du Tick manquant"))));
                }
              }

              return null;
            },
            onUnknownRoute: (settings) {
               print("Navigation Error: Unknown route: ${settings.name}");
               return MaterialPageRoute(builder: (_) => const SplashScreen());
            },
          );
        },
      ),
    );
  }
}

/// Widget simple affiché en cas d'échec de configuration d'Amplify.
class AmplifyConfigurationErrorApp extends StatelessWidget {
  const AmplifyConfigurationErrorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'Erreur critique: Impossible de configurer Amplify. Veuillez vérifier la configuration et redémarrer l\'application.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class FirebaseInitErrorApp extends StatelessWidget {
  const FirebaseInitErrorApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Erreur Initialisation Firebase')),
        ),
      );
}