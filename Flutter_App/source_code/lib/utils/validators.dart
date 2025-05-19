
import 'constants.dart';

/// Fournit des méthodes de validation statiques pour les formulaires.
class Validators {

  /// Valide qu'une chaîne de caractères n'est pas nulle ou vide (après trim).
  ///
  /// Retourne un message d'erreur si invalide, sinon `null`.
  /// [message] optionnel pour personnaliser le message d'erreur.
  static String? validateNotEmpty(String? value, [String? message]) {
    if (value == null || value.trim().isEmpty) {
      return message ?? AppTexts.requiredField;
    }
    return null;
  }

  /// Valide un format d'email simple.
  ///
  /// Vérifie d'abord si le champ est vide, puis utilise une regex.
  /// Retourne un message d'erreur si invalide, sinon `null`.
  static String? validateEmail(String? value) {
    final notEmptyValidation = validateNotEmpty(value, AppTexts.invalidEmail);
    if (notEmptyValidation != null) {
      return notEmptyValidation; // Retourne l'erreur "champ requis" ou "email invalide" si vide
    }

    final emailRegex = RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$");
    if (!emailRegex.hasMatch(value!)) {
      return AppTexts.invalidEmail;
    }
    return null;
  }

  /// Valide un mot de passe basé sur une longueur minimale.
  ///
  /// La longueur minimale est définie dans `AppTexts.passwordTooShort`.
  /// Retourne un message d'erreur si invalide, sinon `null`.
  /// Note: La politique de complexité réelle est définie dans AWS Cognito.
  static String? validatePassword(String? value) {
    final notEmptyValidation = validateNotEmpty(value, AppTexts.passwordTooShort);
    if (notEmptyValidation != null) {
      return notEmptyValidation;
    }
    // Utiliser la longueur définie dans les constantes pour le message d'erreur
    // La vraie validation de complexité est faite par Cognito.
    // On vérifie juste la longueur minimale affichée à l'utilisateur.
    if (value!.length < 8) { // Correspond à la politique Cognito par défaut (8 caractères)
      return AppTexts.passwordTooShort;
    }
    return null;
  }

  /// Valide que le mot de passe de confirmation correspond à l'original.
  ///
  /// Retourne un message d'erreur si invalide, sinon `null`.
  static String? validateConfirmPassword(String? confirmValue, String originalValue) {
    final notEmptyValidation = validateNotEmpty(confirmValue, AppTexts.passwordsDoNotMatch);
     if (notEmptyValidation != null) {
      return notEmptyValidation; // Retourne "champ requis" si vide, ou "ne correspond pas" si différent
    }
    if (confirmValue != originalValue) {
      return AppTexts.passwordsDoNotMatch;
    }
    return null;
  }

  /// Valide un code de confirmation (doit être non vide et d'une certaine longueur).
  ///
  /// Retourne un message d'erreur si invalide, sinon `null`.
  static String? validateConfirmationCode(String? value, {int length = 6}) {
     final notEmptyValidation = validateNotEmpty(value, AppTexts.invalidCode);
     if (notEmptyValidation != null) {
       return notEmptyValidation;
     }
     if (value!.length != length) {
        return AppTexts.invalidCode; // Ou message plus précis: "Le code doit faire $length chiffres"
     }
     // Pourrait ajouter une regex pour vérifier que ce sont des chiffres: RegExp(r'^[0-9]+$')
     return null;
  }

}