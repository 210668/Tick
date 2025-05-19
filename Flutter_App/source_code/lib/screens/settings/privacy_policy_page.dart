import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  static const String routeName = '/settings/privacy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Politique de Confidentialité'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Politique de Confidentialité de MyTick',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Dernière mise à jour : 11/05/2025', style: TextStyle(fontStyle: FontStyle.italic)),
            SizedBox(height: 16),
            Text(
              'Votre vie privée est importante pour nous. Cette politique de confidentialité explique quelles données personnelles MyTick collecte auprès de vous, '
                  'comment nous les utilisons, et les choix que vous avez concernant vos données.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('1. Collecte des Données', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Nous collectons des informations pour fournir et améliorer nos services. Cela inclut :\n'
                  '- Informations de compte : Lorsque vous créez un compte, nous collectons votre nom, adresse e-mail et mot de passe (hashé).\n'
                  '- Données de localisation : Les Ticks envoient périodiquement leur position GPS pour vous permettre de les localiser.\n',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('2. Utilisation des Données', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Les données collectées sont utilisées pour :\n'
                  '- Fournir, maintenir et améliorer nos services.\n'
                  '- Vous envoyer des notifications et des alertes.\n'
                  '- Répondre à vos demandes de support.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('3. Partage des Données', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Nous ne partageons pas vos informations personnelles avec des tiers, sauf dans les cas suivants :\n'
                  '- Avec votre consentement explicite.\n'
                  '- Pour se conformer à des obligations légales.\n'
                  '- Pour protéger nos droits et notre propriété.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('4. Sécurité des Données', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Nous prenons des mesures raisonnables pour protéger vos informations contre la perte, le vol, l\'utilisation abusive, l\'accès non autorisé, la divulgation, l\'altération et la destruction.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('5. Vos Choix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Vous pouvez accéder et mettre à jour les informations de votre compte via les paramètres de l\'application. Vous pouvez également supprimer votre compte, ce qui entraînera la suppression de vos données personnelles associées.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('6. Modifications de cette Politique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Nous pouvons mettre à jour cette politique de confidentialité de temps à autre. Nous vous informerons de tout changement important en publiant la nouvelle politique sur cette page.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('7. Nous Contacter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Si vous avez des questions concernant cette politique de confidentialité, veuillez nous contacter à tickapp.help@gmail.com.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}