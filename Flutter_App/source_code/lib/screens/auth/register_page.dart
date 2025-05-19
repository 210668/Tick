import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/loading_indicator.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Soumet le formulaire d'inscription.
  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    // Appeler le service d'inscription
    final registerSuccess = await authService.register(email, password, name);

    if (!mounted) return;

    if (registerSuccess) {
      if (authService.needsConfirmation) {
        // Inscription réussie, mais nécessite confirmation
        CustomSnackBar.show(
          context,
          message: "${AppTexts.checkEmailForCode} ($email).",
          type: AlertType.info,
          duration: AppDurations.longDelay * 2,
        );
        // Naviguer vers la page de confirmation, en remplaçant la page actuelle
        Navigator.pushReplacementNamed(context, Routes.confirmSignUp, arguments: email);
      } else {
        // Inscription réussie ET auto-confirmée (moins courant)
        CustomSnackBar.showSuccess(context, "Inscription réussie ! Vous pouvez maintenant vous connecter.");
        // Rediriger vers la page de connexion, en retirant les pages précédentes
        Navigator.pushNamedAndRemoveUntil(context, Routes.login, (route) => false);
      }
    } else {
      // Afficher l'erreur renvoyée par AuthService (ex: email déjà utilisé)
      CustomSnackBar.showError(context, authService.error ?? ErrorMessages.unknownError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    // Détermine le chemin d'accès au logo en fonction du thème
    final String logoAssetPath = isDarkMode
        ? 'assets/icon/icon_foreground_dark_mode.png'
        : 'assets/icon/icon_foreground.png';

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTexts.register),
        actions: const [ThemeToggleButton()],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          return Stack(
            children: [

              AbsorbPointer(
                absorbing: authService.isLoading,
                child: Center(
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
                              padding: const EdgeInsets.only(bottom: 32.0),
                              child: Hero(
                                tag: 'logo',
                                child: Image.asset(
                                  logoAssetPath,
                                  height: 150,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 100),
                                ),
                              ),
                            ),


                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: AppTexts.name,
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) => Validators.validateNotEmpty(value, "Veuillez entrer votre nom"),
                              textInputAction: TextInputAction.next,
                              enabled: !authService.isLoading,
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 16),

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
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              validator: Validators.validatePassword,
                              textInputAction: TextInputAction.next,
                              enabled: !authService.isLoading,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: 16),

                            // Champ Confirmation Mot de passe
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: AppTexts.confirmPassword,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              // Validation comparant avec le champ mot de passe
                              validator: (value) => Validators.validateConfirmPassword(value, _passwordController.text),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitRegistration(),
                              enabled: !authService.isLoading,
                              autofillHints: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: 32),

                            // Bouton d'Inscription
                            ElevatedButton(
                              onPressed: authService.isLoading ? null : _submitRegistration,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                              ),
                              child: authService.isLoading
                                  ? const LoadingIndicator(size: 20, color: Colors.white)
                                  : const Text(
                                      AppTexts.register,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                            const SizedBox(height: 32),

                            // Lien vers la Connexion
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(AppTexts.alreadyAccount),
                                TextButton(
                                  onPressed: authService.isLoading
                                      ? null
                                      : () => Navigator.pushReplacementNamed(context, Routes.login),
                                  child: const Text(AppTexts.login),
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

              // Indicateur de chargement global
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
}