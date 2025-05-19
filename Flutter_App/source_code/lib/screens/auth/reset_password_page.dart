import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/alert_card.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({Key? key}) : super(key: key);

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _username;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is String && arguments.isNotEmpty) {
      _username = arguments;
    } else {

      _username = Provider.of<AuthService>(context, listen: false).pendingUsername;
    }

    if (_username == null || _username!.isEmpty) {
      print("ERREUR: Aucun username trouvé pour la page de réinitialisation.");

      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) {
           CustomSnackBar.showError(context, ErrorMessages.unknownError);
           Navigator.pop(context);
         }
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Soumet la demande de confirmation de réinitialisation.
  Future<void> _submitResetPassword() async {
    FocusScope.of(context).unfocus();
    if (_username == null) {
      CustomSnackBar.showError(context, "Impossible de réinitialiser sans email.");
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final code = _codeController.text.trim();
    final newPassword = _passwordController.text;

    final success = await authService.confirmPasswordReset(_username!, newPassword, code);

    if (!mounted) return;

    if (success) {
      CustomSnackBar.showSuccess(context, "Mot de passe réinitialisé avec succès. Vous pouvez maintenant vous connecter.");
      // Rediriger vers la page de connexion
      Navigator.pushNamedAndRemoveUntil(context, Routes.login, (route) => false);
    } else {
      // Afficher l'erreur renvoyée par AuthService (ex: code invalide, politique mdp)
      CustomSnackBar.showError(context, authService.error ?? "Erreur de réinitialisation.");
    }
  }



  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isLoading = authService.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTexts.resetPassword),
        actions: const [ThemeToggleButton()],
      ),
      body: Stack(
        children: [

          AbsorbPointer(
            absorbing: isLoading,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      const Icon(Icons.lock_reset_outlined, size: 60, color: AppTheme.primaryColor),
                      const SizedBox(height: 24),

                      Text(
                        "${AppTexts.checkEmailForCode} (${_username ?? AppTexts.unknownUser}).",
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Champ Code
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: AppTexts.enterResetCode,
                          prefixIcon: Icon(Icons.pin_outlined),
                          counterText: "",
                        ),
                        keyboardType: TextInputType.number,
                        validator: Validators.validateConfirmationCode,
                        maxLength: 6,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, letterSpacing: 4),
                      ),
                      const SizedBox(height: 16),
                      // Champ Nouveau Mot de Passe
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: AppTexts.newPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: Validators.validatePassword,
                        textInputAction: TextInputAction.next,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: 16),
                      // Champ Confirmer Mot de Passe
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: AppTexts.confirmPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        obscureText: _obscureConfirmPassword,
                        validator: (value) => Validators.validateConfirmPassword(value, _passwordController.text),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitResetPassword(),
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: 32),
                      // Bouton Confirmer
                      ElevatedButton(
                        onPressed: isLoading ? null : _submitResetPassword,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: isLoading
                            ? const LoadingIndicator(size: 20, color: Colors.white)
                            : const Text(AppTexts.confirm, style: TextStyle(fontSize: 16)),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
          // Indicateur de chargement global
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: LoadingIndicator(size: 40)),
            ),
        ],
      ),
    );
  }
}