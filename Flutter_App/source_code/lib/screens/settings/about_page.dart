import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  static const String routeName = '/settings/about';

  @override
  Widget build(BuildContext context) {

    const String appVersion = '1.0.0';
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final String logoAssetPath = isDarkMode
        ? 'assets/icon/icon_foreground_dark_mode.png'
        : 'assets/icon/icon_foreground.png';

    return Scaffold(
      appBar: AppBar(
        title: Text('À propos de ${AppTexts.appName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Hero(
                tag: 'logo_settings',
                child: Image.asset(
                  logoAssetPath,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 80),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppTexts.appName,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Version $appVersion',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 24),
              Text(
                AppTexts.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              const Text(
                'MyTick est une application développée pour vous aider à garder un œil sur vos véhicules. '
                    'Grâce à nos Ticks GPS intelligents, vous pouvez localiser vos biens en temps réel et recevoir des alertes instantanées en cas de mouvement suspect.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                '© ${DateTime.now().year} FPMs BA3 - Groupe 56',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                child: const Text('Voir les licences open source'),
                onPressed: () {
                  showLicensePage(
                    context: context,
                    applicationName: AppTexts.appName,
                    applicationVersion: appVersion,
                    applicationIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/icon/icon_round.png', width: 40),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}