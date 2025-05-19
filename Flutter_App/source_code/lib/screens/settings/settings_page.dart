import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/theme_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/theme.dart';
import '../../../widgets/theme_toggle_button.dart';
import 'help_support_page.dart';
import 'about_page.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';

/// Page pour les paramètres généraux de l'application.
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {


  /// Ouvre une URL externe dans le navigateur par défaut.
  /// Gère les erreurs si l'URL ne peut pas être lancée.
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le lien: $urlString')),
        );
      }
    } catch (e) {
      print("Error launching URL $urlString: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ouverture du lien.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTexts.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          _buildSectionTitle(context, AppTexts.appearance),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Thème de l\'application'),
            subtitle: Text(themeService.getThemeModeName()),
            trailing: const ThemeToggleButton(),
            onTap: () => themeService.toggleThemeMode(context),
          ),
          const Divider(height: 16),

          _buildSectionTitle(context, AppTexts.information),
          _buildInfoTile(
            icon: Icons.help_outline,
            title: 'Aide & Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpSupportPage()),
              );

            },
          ),
          _buildInfoTile(
            icon: Icons.info_outline,
            title: 'À propos de ${AppTexts.appName}',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );

            },
          ),
          _buildInfoTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );

            },
          ),
          _buildInfoTile(
            icon: Icons.description_outlined,
            title: 'Conditions d\'utilisation',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsOfServicePage()),
              );

            },
          ),
        ],
      ),
    );
  }

  /// Helper pour construire un ListTile cliquable pour les liens d'info.
  Widget _buildInfoTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  /// Helper pour créer les titres de section
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Affiche la boîte de dialogue standard "À propos".
  void _showAboutDialog(BuildContext context) {

     const String appVersion = '1.0.0';
     final theme = Theme.of(context);

     showAboutDialog(
       context: context,
       applicationName: AppTexts.appName,
       applicationVersion: appVersion,
       applicationIcon: Padding(
         padding: const EdgeInsets.all(8.0),
         child: Image.asset('assets/icon/icon_round.png', width: 40),
       ),
       applicationLegalese: '© ${DateTime.now().year} FPMs BA3 - Groupe 56',
       children: <Widget>[
         const SizedBox(height: 16),
         const Text(AppTexts.description),

       ],
     );
  }
}
