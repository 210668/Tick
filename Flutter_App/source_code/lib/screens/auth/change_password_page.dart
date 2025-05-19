import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/theme_toggle_button.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isChangingPassword = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitChangePassword() async {
    print("[ChangePasswordPage._submit] Submit button pressed.");
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      print("[ChangePasswordPage._submit] Form validation failed.");
      return;
    }

    print("[ChangePasswordPage._submit] Setting _isChangingPassword = true");
    setState(() => _isChangingPassword = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;

    print("[ChangePasswordPage._submit] Calling authService.changePassword...");
    final bool success = await authService.changePassword(oldPassword, newPassword);
    print("[ChangePasswordPage._submit] authService.changePassword returned: $success");

    if (!mounted) {
      print("[ChangePasswordPage._submit] Widget not mounted after await. Aborting.");
      return;
    }

    print("[ChangePasswordPage._submit] Setting _isChangingPassword = false");
    setState(() => _isChangingPassword = false);

    if (success) {
      print("[ChangePasswordPage._submit] Success branch. Showing SnackBar and popping.");
      CustomSnackBar.showSuccess(context, "Mot de passe modifié avec succès !");
      Navigator.pop(context);
    } else {
      print("[ChangePasswordPage._submit] Failure branch. Showing error SnackBar.");
      CustomSnackBar.showError(context, authService.error ?? ErrorMessages.unknownError);
    }
    print("[ChangePasswordPage._submit] Submit function finished.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Changer le mot de passe"),
        actions: const [ThemeToggleButton()],
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _isChangingPassword,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      TextFormField(
                        controller: _oldPasswordController,
                        decoration: InputDecoration(
                          labelText: "Ancien mot de passe",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscureOld = !_obscureOld),
                          ),
                        ),
                        obscureText: _obscureOld,
                        validator: (value) => Validators.validateNotEmpty(value, "Ancien mot de passe requis"),
                        textInputAction: TextInputAction.next,
                        enabled: !_isChangingPassword,
                      ),
                      const SizedBox(height: 16),


                      TextFormField(
                        controller: _newPasswordController,
                        decoration: InputDecoration(
                          labelText: AppTexts.newPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                        obscureText: _obscureNew,
                        validator: Validators.validatePassword,
                        textInputAction: TextInputAction.next,
                        enabled: !_isChangingPassword,
                      ),
                      const SizedBox(height: 16),


                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: AppTexts.confirmPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        obscureText: _obscureConfirm,

                        validator: (value) => Validators.validateConfirmPassword(value, _newPasswordController.text),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitChangePassword(),
                        enabled: !_isChangingPassword,
                      ),
                      const SizedBox(height: 32),

                      // Bouton Enregistrer
                      ElevatedButton.icon(
                        onPressed: _isChangingPassword ? null : _submitChangePassword,
                        icon: _isChangingPassword
                            ? Container()
                            : const Icon(Icons.save_outlined, size: 20),
                        label: _isChangingPassword
                            ? const LoadingIndicator(size: 20, color: Colors.white)
                            : const Text(AppTexts.save),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isChangingPassword)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: LoadingIndicator(size: 40)),
            ),
        ],
      ),
    );
  }
}