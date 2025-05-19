import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/theme_toggle_button.dart';

class ConfirmationPage extends StatefulWidget {
  const ConfirmationPage({Key? key}) : super(key: key);

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  String? _username;

  bool _isResendingCode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is String) {
      _username = arguments;
    } else {

       _username = Provider.of<AuthService>(context, listen: false).pendingUsername;
    }
     if (_username == null) {
       print("ERREUR: Aucun username trouvé pour la confirmation.");

     }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitConfirmation() async {
    FocusScope.of(context).unfocus();
    if (_username == null) {
       CustomSnackBar.showError(context, "Impossible de confirmer sans email.");
       return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final code = _codeController.text.trim();

      final success = await authService.confirmSignUp(_username!, code);

      if (!mounted) return;

      if (success) {
        CustomSnackBar.showSuccess(context, "Compte confirmé avec succès ! Vous pouvez maintenant vous connecter.");

        Navigator.pushNamedAndRemoveUntil(context, Routes.login, (route) => false);
      } else {

        CustomSnackBar.showError(context, authService.error ?? "Erreur de confirmation.");
      }
    }
  }

  Future<void> _resendCode() async {
     if (_username == null) {
       CustomSnackBar.showError(context, "Impossible de renvoyer le code sans email.");
       return;
    }
    setState(() => _isResendingCode = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    final success = await authService.resendConfirmationCode(_username!);

    if (!mounted) return;
    setState(() => _isResendingCode = false);

    if (success) {
       CustomSnackBar.showSuccess(context, "Nouveau code de confirmation envoyé à $_username.");
    } else {
       CustomSnackBar.showError(context, authService.error ?? "Erreur lors du renvoi du code.");

       if (authService.error?.contains("déjà confirmé") ?? false) {
           await Future.delayed(Duration(seconds: 2));
           if (mounted) Navigator.pushNamedAndRemoveUntil(context, Routes.login, (route) => false);
       }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirmer l'inscription"),
        actions: [const ThemeToggleButton()],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Un code de confirmation a été envoyé à :",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                       Center(
                         child: Text(
                           _username ?? "Email inconnu",
                           style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                         ),
                       ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: "Code de confirmation",
                          prefixIcon: Icon(Icons.pin_outlined),
                          hintText: "Entrez le code à 6 chiffres",
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => Validators.validateNotEmpty(value, "Code requis"),
                        maxLength: 6,
                        enabled: !authService.isLoading,
                        autofocus: true,
                         textInputAction: TextInputAction.done,
                         onFieldSubmitted: (_) => _submitConfirmation(),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: authService.isLoading ? null : _submitConfirmation,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: authService.isLoading && !_isResendingCode
                            ? const LoadingIndicator(size: 20, color: Colors.white)
                            : const Text("Confirmer", style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: (authService.isLoading || _isResendingCode) ? null : _resendCode,
                        child: _isResendingCode
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LoadingIndicator(size: 16),
                                SizedBox(width: 8),
                                Text("Renvoi en cours...")
                              ],
                            )
                          : const Text("Renvoyer le code"),
                      ),
                    ],
                  ),
                ),
              ),

              if (authService.isLoading && !_isResendingCode)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: LoadingIndicator(size: 40)),
                  ),
            ],
          );
        }
      ),
    );
  }
}