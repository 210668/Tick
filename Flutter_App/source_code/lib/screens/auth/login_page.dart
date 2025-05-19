import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/alert_card.dart'; // Pour CustomSnackBar
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/loading_indicator.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Soumet le formulaire de connexion.
  Future<void> _submitLogin() async {
    // Masquer le clavier
    FocusScope.of(context).unfocus();

    // Valider le formulaire
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Appeler le service d'authentification
    final loginSuccess = await authService.login(email, password);

    if (!mounted) return; // Vérifier après l'appel asynchrone

    if (loginSuccess) {

      Navigator.pushNamedAndRemoveUntil(context, Routes.tickList, (route) => false);
    } else {
      // Gérer les erreurs spécifiques renvoyées par AuthService
      if (authService.needsConfirmation) {
        // L'utilisateur doit confirmer son compte
        CustomSnackBar.showError(context, authService.error ?? ErrorMessages.userNotConfirmed);
        // Naviguer vers la page de confirmation, en passant l'email
        Navigator.pushNamed(context, Routes.confirmSignUp, arguments: email);
      } else {
        // Autre erreur de connexion (mot de passe incorrect, etc.)
        CustomSnackBar.showError(context, authService.error ?? ErrorMessages.unknownError);
      }
    }
  }

  /// Gère la demande de réinitialisation de mot de passe.
  Future<void> _handleForgotPassword() async {
    FocusScope.of(context).unfocus();
    final authService = Provider.of<AuthService>(context, listen: false);


    String? initialEmail = _emailController.text.trim();
    if (Validators.validateEmail(initialEmail) != null) { // Vérifier si c'est un email valide
       initialEmail = null;
    }

    // Afficher la boîte de dialogue pour entrer l'email
    final resultEmail = await showDialog<String>(
      context: context,
      builder: (context) => _buildForgotPasswordDialog(context, initialEmail: initialEmail),
    );

    // Si l'utilisateur a confirmé avec un email valide
    if (resultEmail != null && resultEmail.isNotEmpty) {
      final success = await authService.requestPasswordReset(resultEmail);
      if (!mounted) return;

      if (success) {
        CustomSnackBar.showSuccess(context, "Email de réinitialisation envoyé à $resultEmail. Vérifiez votre boîte mail.");
        // Naviguer vers la page de saisie du code et du nouveau mot de passe
        Navigator.pushNamed(context, Routes.passwordRecovery, arguments: resultEmail);
      } else {
        // Afficher l'erreur renvoyée par AuthService
        CustomSnackBar.showError(context, authService.error ?? ErrorMessages.unknownError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Accès au thème actuel
    final bool isDarkMode = theme.brightness == Brightness.dark; // Vérifie si le mode sombre est actif
    // Détermine le chemin d'accès au logo en fonction du thème
    final String logoAssetPath = isDarkMode
        ? 'assets/icon/icon_foreground_dark_mode.png'
        : 'assets/icon/icon_foreground.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTexts.login),
        actions: const [ThemeToggleButton()],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {

          return Stack(
            children: [

              AbsorbPointer(
                absorbing: authService.isLoading,
                child: Center( // Centrer le formulaire verticalement
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            Padding(
                              padding: const EdgeInsets.only(bottom: 48.0),
                              child: Hero(
                                tag: 'logo',
                                child: Image.asset(
                                  logoAssetPath,
                                  height: 150,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 100),
                                ),
                              ),
                            ),

                            // Champ Email
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: AppTexts.email,
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.validateEmail,
                              textInputAction: TextInputAction.next,
                              enabled: !authService.isLoading,
                              autofillHints: const [AutofillHints.email, AutofillHints.username],
                            ),
                            const SizedBox(height: 16),

                            // Champ Mot de passe
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: AppTexts.password,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: Validators.validatePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitLogin(),
                              enabled: !authService.isLoading,
                              autofillHints: const [AutofillHints.password],
                            ),
                            const SizedBox(height: 8),

                            // Lien Mot de passe oublié
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: authService.isLoading ? null : _handleForgotPassword,
                                child: const Text(AppTexts.forgotPassword),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Bouton de Connexion
                            ElevatedButton(
                              onPressed: authService.isLoading ? null : _submitLogin,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                              ),
                              child: authService.isLoading
                                  ? const LoadingIndicator(size: 20, color: Colors.white)
                                  : const Text(
                                      AppTexts.login,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                            const SizedBox(height: 32),

                            // Lien vers l'Inscription
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(AppTexts.noAccount),
                                TextButton(
                                  onPressed: authService.isLoading
                                      ? null
                                      : () => Navigator.pushNamed(context, Routes.register),
                                  child: const Text(AppTexts.register),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Indicateur de chargement global superposé
              if (authService.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: LoadingIndicator(size: 40)),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Construit la boîte de dialogue pour la récupération de mot de passe.
  Widget _buildForgotPasswordDialog(BuildContext context, {String? initialEmail}) {
    final emailController = TextEditingController(text: initialEmail ?? '');
    final dialogFormKey = GlobalKey<FormState>();

    return AlertDialog(
      title: const Text(AppTexts.passwordRecovery),
      content: Form(
        key: dialogFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppTexts.passwordRecoveryInstructions),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: AppTexts.email,
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.validateEmail,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppTexts.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            // Valider le formulaire de la boîte de dialogue avant de fermer
            if (dialogFormKey.currentState?.validate() ?? false) {
              Navigator.pop(context, emailController.text.trim()); // Renvoie l'email
            }
          },
          child: const Text(AppTexts.sendRecoveryLink),
        ),
      ],
    );
  }
}