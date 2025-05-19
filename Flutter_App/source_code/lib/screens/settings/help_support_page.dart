import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({Key? key}) : super(key: key);

  static const String routeName = '/settings/help';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide & Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Besoin d\'aide ?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16.0),
            const Text(
              'Si vous rencontrez des problèmes avec l\'application ou votre appareil Tick, '
                  'voici quelques ressources qui pourraient vous aider :',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24.0),
            _buildSectionTitle(context, 'Foire Aux Questions (FAQ)'),
            _buildHelpItem(
              context,
              question: 'Mon Tick ne se connecte pas, que faire ?',
              answer:
              '1. Assurez-vous que le Bluetooth de votre téléphone est activé.\n'
                  '2. Vérifiez que votre Tick est allumé et suffisamment chargé.\n'
                  '3. Essayez de redémarrer votre Tick et votre téléphone.\n'
                  '4. Si le problème persiste, essayez de désassocier puis de réassocier le Tick depuis l\'application.',
            ),
            _buildHelpItem(
              context,
              question: 'La localisation de mon Tick n\'est pas précise.',
              answer:
              'La précision du GPS peut varier en fonction de l\'environnement (bâtiments élevés, intérieur, conditions météorologiques). '
                  'Assurez-vous que le Tick a une vue dégagée du ciel pour une meilleure réception. '
                  'En mode économie d\'énergie, la fréquence des mises à jour GPS peut être réduite.',
            ),
            const SizedBox(height: 24.0),
            _buildSectionTitle(context, 'Contacter le Support'),
            const Text(
              'Si vous ne trouvez pas de réponse à votre question, vous pouvez nous contacter directement :',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8.0),
            TextButton.icon(
              icon: const Icon(Icons.email_outlined),
              label: const Text('tickapp.help@gmail.com'),
              onPressed: () {
                // Implémenter l'ouverture du client mail

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité d\'envoi d\'email à implémenter.')),
                );
              },
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildHelpItem(BuildContext context, {required String question, required String answer}) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(question, style: Theme.of(context).textTheme.titleMedium),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(answer, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}