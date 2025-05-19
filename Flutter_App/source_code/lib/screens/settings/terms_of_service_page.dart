import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({Key? key}) : super(key: key);

  static const String routeName = '/settings/terms';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conditions d\'Utilisation'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Conditions d\'Utilisation de MyTick',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Dernière mise à jour : 11/05/2025', style: TextStyle(fontStyle: FontStyle.italic)),
            SizedBox(height: 16),
            Text(
              'Veuillez lire attentivement ces conditions d\'utilisation avant d\'utiliser l\'application MyTick exploitée par l\'équipe 56',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('1. Acceptation des Conditions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'En accédant ou en utilisant le Service, vous acceptez d\'être lié par ces Conditions. Si vous n\'êtes pas d\'accord avec une partie des conditions, vous ne pouvez pas accéder au Service.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('2. Comptes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Lorsque vous créez un compte chez nous, vous devez nous fournir des informations exactes, complètes et à jour en tout temps. Le non-respect de cette obligation constitue une violation des Conditions, qui peut entraîner la résiliation immédiate de votre compte sur notre Service.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('3. Propriété Intellectuelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Le Service et son contenu original, ses caractéristiques et ses fonctionnalités sont et resteront la propriété exclusive de l\'équipe 56 et de ses concédants de licence.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('4. Limitation de Responsabilité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'En aucun cas l\'équipe 56, ni ses administrateurs, employés, partenaires, agents, fournisseurs ou sociétés affiliées, ne pourront être tenus responsables de dommages indirects, accessoires, spéciaux, consécutifs ou punitifs, y compris, sans limitation, la perte de profits, de données, d\'utilisation, de clientèle ou d\'autres pertes intangibles, résultant de (i) votre accès ou utilisation ou incapacité d\'accéder ou d\'utiliser le Service ; (ii) toute conduite ou contenu d\'un tiers sur le Service ; (iii) tout contenu obtenu à partir du Service ; et (iv) l\'accès non autorisé, l\'utilisation ou l\'altération de vos transmissions ou de votre contenu, que ce soit sur la base d\'une garantie, d\'un contrat, d\'un délit (y compris la négligence) ou de toute autre théorie juridique, que nous ayons été informés ou non de la possibilité de tels dommages, et même si un recours énoncé dans les présentes s\'avère avoir échoué dans son objectif essentiel.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('5. Modifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Nous nous réservons le droit, à notre seule discrétion, de modifier ou de remplacer ces Conditions à tout moment. Si une révision est importante, nous essaierons de fournir un préavis d\'au moins 30 jours avant l\'entrée en vigueur des nouvelles conditions. Ce qui constitue un changement important sera déterminé à notre seule discrétion.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text('6. Nous Contacter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Si vous avez des questions concernant ces Conditions, veuillez nous contacter à tickapp.help@gmail.com.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}