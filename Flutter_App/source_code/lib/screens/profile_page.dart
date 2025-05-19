import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

import '../../models/user.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../utils/theme.dart';
import '../../widgets/theme_toggle_button.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/alert_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // États pour l'édition du nom
  bool _isEditingName = false;
  final _nameController = TextEditingController();
  final _nameFormKey = GlobalKey<FormState>();
  bool _isSavingName = false;

  // Référence au service d'authentification
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    // Obtenir la référence au service
    _authService = Provider.of<AuthService>(context, listen: false);
    // Initialiser le contrôleur avec le nom actuel de l'utilisateur connecté
    _nameController.text = _authService.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Gère la déconnexion de l'utilisateur.
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppTexts.logout),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppTexts.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppTexts.logout),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
         Navigator.pushNamedAndRemoveUntil(context, Routes.welcome, (route) => false);
      }
    }
  }

  /// Sauvegarde le nouveau nom d'utilisateur via AuthService.
  Future<void> _saveName() async {
    if (!(_nameFormKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSavingName = true);
    final newName = _nameController.text.trim();

    // Appeler la méthode d'update d'AuthService (qui utilise Amplify)
    bool success = await _authService.updateUserName(newName);

    if (mounted) {
      setState(() {
        _isSavingName = false;
        if (success) {
          _isEditingName = false;
          CustomSnackBar.showSuccess(context, "Nom mis à jour.");

        } else {
          // Afficher l'erreur renvoyée par AuthService
          CustomSnackBar.showError(context, _authService.error ?? AppTexts.updateError);
        }
      });
    }
  }

  /// Navigue vers la page de changement de mot de passe (à implémenter).
  void _navigateToChangePassword() {
    Navigator.pushNamed(context, Routes.changePassword);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppTexts.profile),
        actions: const [ThemeToggleButton()],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          final user = authService.currentUser;

          // Gérer le cas où l'utilisateur n'est plus connecté
          if (user == null) {
            return const Center(child: Text(AppTexts.notConnected));
          }


          if (!_isEditingName && _nameController.text != user.displayName) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _nameController.text = user.displayName;
             });
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Section Informations Utilisateur ---
              _buildProfileHeader(context, user),
              const SizedBox(height: 32),

              // Affichage/Édition du nom
              _buildNameTile(user, authService.isLoading),
              const SizedBox(height: 8),

              // Affichage de l'email (non modifiable)
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text(AppTexts.email),
                subtitle: Text(user.email),
                dense: true,
              ),
              const Divider(height: 32),

              // --- Section Sécurité ---
              _buildSectionTitle(context, AppTexts.security),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Changer le mot de passe'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _navigateToChangePassword,
              ),
              const Divider(height: 32),

              // --- Bouton Déconnexion ---
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text(AppTexts.logout),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                  onPressed: authService.isLoading ? null : _logout,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Construit l'en-tête du profil avec l'avatar.
  Widget _buildProfileHeader(BuildContext context, User user) {
    final theme = Theme.of(context);

    String initials = user.displayName.isNotEmpty
        ? user.displayName.trim().split(' ').map((part) => part.isNotEmpty ? part[0] : '').join().toUpperCase()
        : '?';
    if (initials.length > 2) initials = initials.substring(0, 2);

    return Center(
      child: CircleAvatar(
        radius: 50,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(fontSize: 40, color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }

  /// Construit le ListTile pour afficher/éditer le nom.
  Widget _buildNameTile(User user, bool isAuthLoading) {
    if (_isEditingName) {
      return Form(
        key: _nameFormKey,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: AppTexts.name, isDense: true),
            validator: (value) => Validators.validateNotEmpty(value, "Le nom ne peut pas être vide"),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _saveName(),
            autofocus: true,
            enabled: !_isSavingName && !isAuthLoading,
            textCapitalization: TextCapitalization.words,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: _isSavingName ? const LoadingIndicator(size: 18) : const Icon(Icons.check, color: AppTheme.successColor),
                tooltip: AppTexts.save,
                onPressed: (_isSavingName || isAuthLoading) ? null : _saveName,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: AppTexts.cancel,
                onPressed: (_isSavingName || isAuthLoading) ? null : () => setState(() {
                  _isEditingName = false;
                  _nameController.text = user.displayName;
                  _nameFormKey.currentState?.reset();
                }),
              ),
            ],
          ),
        ),
      );
    } else {
      return ListTile(
        leading: const Icon(Icons.person_outline),
        title: const Text(AppTexts.name),
        subtitle: Text(user.displayName.isNotEmpty ? user.displayName : 'Non défini'),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: AppTexts.edit,
          onPressed: isAuthLoading ? null : () => setState(() => _isEditingName = true),
        ),
        onTap: isAuthLoading ? null : () => setState(() => _isEditingName = true),
        dense: true,
      );
    }
  }

  /// Construit un titre de section.
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
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
}