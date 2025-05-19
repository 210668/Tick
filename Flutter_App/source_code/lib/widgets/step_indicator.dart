import 'package:flutter/material.dart';

/// Un widget indicateur d'étapes horizontal simple.
/// Affiche des cercles connectés par des lignes, avec des états visuels pour
/// les étapes actives, complétées, inactives et en erreur.
class StepIndicator extends StatelessWidget {
  final int stepCount; // Nombre total d'étapes
  final int currentStep; // Index (0-based) de l'étape actuelle
  final Color activeColor; // Couleur pour l'étape active et les lignes complétées
  final Color inactiveColor; // Couleur pour les étapes/lignes inactives
  final Color? errorColor; // Couleur pour une étape en erreur (utilise theme.error si null)
  final int? errorStep; // Index (0-based) de l'étape en erreur, si applicable
  final int? doneStep; // Index (0-based) de la dernière étape explicitement marquée comme terminée

  const StepIndicator({
    Key? key,
    required this.stepCount,
    required this.currentStep,
    required this.activeColor,
    required this.inactiveColor,
    this.errorColor,
    this.errorStep,
    this.doneStep,
  }) : assert(stepCount > 0),
       assert(currentStep >= 0 && currentStep < stepCount),
       assert(errorStep == null || (errorStep >= 0 && errorStep < stepCount)),
       assert(doneStep == null || (doneStep >= 0 && doneStep < stepCount)),
       super(key: key);

  @override
  Widget build(BuildContext context) {

    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Centre l'indicateur
      children: List.generate(stepCount * 2 - 1, (index) {

        if (index.isEven) {
          final stepIndex = index ~/ 2;
          return _buildStepCircle(context, stepIndex);
        }

        else {
          final stepIndex = index ~/ 2;
          return _buildConnectorLine(context, stepIndex);
        }
      }),
    );
  }

  /// Construit un cercle représentant une étape.
  Widget _buildStepCircle(BuildContext context, int index) {
    Color circleColor = inactiveColor; // Couleur par défaut
    Widget child = const SizedBox.shrink(); // Pas d'icône par défaut

    // Déterminer les états de l'étape
    final bool isError = errorStep == index;
    // Une étape est considérée comme 'done' si elle est avant ou égale à doneStep
    final bool isDone = doneStep != null && index <= doneStep!;
    // Une étape est active si c'est l'étape courante ET qu'elle n'est pas en erreur
    final bool isActive = index == currentStep && !isError;
    // Une étape est complétée si elle est avant l'étape actuelle (et pas en erreur)
    // OU si elle est explicitement marquée comme done (et pas en erreur)
    final bool isCompleted = (index < currentStep || isDone) && !isError;

    // Définir la couleur d'erreur effective
    final Color effectiveErrorColor = errorColor ?? Theme.of(context).colorScheme.error;

    // Appliquer les styles en fonction de l'état
    if (isError) {
      circleColor = effectiveErrorColor;
      // Icône X pour erreur
      child = Icon(Icons.close, color: Theme.of(context).colorScheme.onError, size: 14);
    } else if (isCompleted) {
      circleColor = activeColor;
      // Icône Coche pour étape complétée
      child = Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 14);
    } else if (isActive) {
      circleColor = activeColor;

    }

    // Construction du cercle avec décoration
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        // Ajouter une bordure pour mieux délimiter, surtout pour les étapes inactives
        border: Border.all(
          color: isCompleted || isActive ? activeColor : (isError ? effectiveErrorColor : inactiveColor.withOpacity(0.5)),
          width: 1.5,
        ),
      ),
      child: Center(child: child), // Centrer l'icône/texte à l'intérieur
    );
  }

  /// Construit une ligne connectant deux étapes.
  Widget _buildConnectorLine(BuildContext context, int precedingStepIndex) {

    final bool isPreviousStepCompleted =
        (precedingStepIndex < currentStep || (doneStep != null && precedingStepIndex <= doneStep!)) &&
        (errorStep == null || precedingStepIndex < errorStep!);

    // Si une erreur est survenue à l'étape précédente ou avant, la ligne reste inactive.
    final bool isAfterError = errorStep != null && precedingStepIndex >= errorStep!;

    return Expanded( // Prend l'espace disponible entre les cercles
      child: Container(
        height: 2, // Épaisseur de la ligne
        // La ligne est active si l'étape précédente est complétée, sinon inactive (sauf si après une erreur)
        color: isAfterError ? inactiveColor : (isPreviousStepCompleted ? activeColor : inactiveColor),
        margin: const EdgeInsets.symmetric(horizontal: 4), // Petit espace autour de la ligne
      ),
    );
  }
}