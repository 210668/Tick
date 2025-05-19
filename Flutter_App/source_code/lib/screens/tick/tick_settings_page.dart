
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../models/tick_model.dart';
import '../../services/tick_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/loading_indicator.dart';

class TickSettingsPage extends StatefulWidget {
  /// ID du Tick dont on affiche les paramètres. Requis.
  final String tickId;

  const TickSettingsPage({Key? key, required this.tickId}) : super(key: key);

  @override
  State<TickSettingsPage> createState() => _TickSettingsPageState();
}

class _TickSettingsPageState extends State<TickSettingsPage> {
  // Contrôleurs et clés pour les champs éditables
  final _nameController = TextEditingController();
  final _nameFormKey = GlobalKey<FormState>();

  // États locaux pour gérer l'UI
  bool _isEditingName = false;
  bool _isSavingName = false;
  bool _isUnlinking = false;

  bool _isDisabling = false;
  bool _isEnabling = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _currentlyPlayingSoundIndex;

  // Stocke les données actuelles du Tick (mis à jour via Provider)
  late Tick? _tick;



  @override
  void initState() {
    super.initState();
    _tick = Provider.of<TickService>(context, listen: false).getTickById(widget.tickId);
    _nameController.text = _tick?.name ?? '';

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _currentlyPlayingSoundIndex = null;
        });
      }
    });
    _audioPlayer.setReleaseMode(ReleaseMode.stop);


  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final updatedTick = context.watch<TickService>().getTickById(widget.tickId);
    if (updatedTick == null && mounted && ModalRoute.of(context)?.isCurrent == true) {
      print("TickSettingsPage: Tick ${widget.tickId} no longer found. Popping.");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } else if (_tick != updatedTick && updatedTick != null) {

      _tick = updatedTick;
      if (!_isEditingName) {
        _nameController.text = _tick!.name;
      }

      if(mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _audioPlayer.dispose();

    super.dispose();
  }

  Future<void> _saveName() async {
    if (!(_nameFormKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSavingName = true);
    final newName = _nameController.text.trim();
    final tickService = Provider.of<TickService>(context, listen: false);

    final success = await tickService.updateTickSettings(widget.tickId, name: newName);

    if (mounted) {
      setState(() {
        _isSavingName = false;
        if (success) {
          _isEditingName = false;
          CustomSnackBar.showSuccess(context, "Nom du Tick mis à jour.");
        } else {
          CustomSnackBar.showError(context, tickService.error ?? AppTexts.updateError);
        }
      });
    }
  }


  Future<void> _handleToggleActiveState() async {
    if (_isDisabling || _isEnabling) return;

    final tickService = Provider.of<TickService>(context, listen: false);
    bool success = false;
    String tickId = widget.tickId;

    if (_tick?.status == TickStatus.disabled) {

      setState(() => _isEnabling = true);
      print("TickSettingsPage: Attempting to reactivate Tick $tickId");
      success = await tickService.reactivateTick(tickId);

      if (!mounted) return;
      setState(() => _isEnabling = false);

      if (success) {
        CustomSnackBar.showSuccess(context, "Demande de réactivation envoyée.");
      } else {
        CustomSnackBar.showError(context, tickService.error ?? "Erreur de réactivation.");
      }

    } else {
      final Duration? selectedDuration = await showDialog<Duration>(
          context: context,
          builder: (context) => _buildDurationPickerDialog()
      );

      if (selectedDuration == null) return;
      setState(() => _isDisabling = true);

      if (selectedDuration == Duration.zero) {
        print("TickSettingsPage: Attempting permanent disable for Tick $tickId");
        success = await tickService.disableTickPermanently(tickId);
      } else {
        print("TickSettingsPage: Attempting temporary disable for Tick $tickId (${selectedDuration.inMinutes} mins)");
        success = await tickService.temporaryDisableTick(tickId, selectedDuration);
      }

      if (!mounted) return;
      setState(() => _isDisabling = false);

      if (success) {
        String message = selectedDuration == Duration.zero
            ? "Demande de désactivation envoyée."
            : "Demande de désactivation envoyée (${selectedDuration.inMinutes} minutes).";
        CustomSnackBar.showSuccess(context, message);

      } else {
        CustomSnackBar.showError(context, tickService.error ?? "Erreur de désactivation.");
      }
    }
  }

  Future<void> _unlinkDevice() async {
    if (widget.tickId.isEmpty) {
      print("TickSettingsPage: Cannot unlink, widget.tickId is empty.");
      CustomSnackBar.showError(context, "Impossible de désassocier (ID manquant).");
      setState(() => _isUnlinking = false);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(AppTexts.unlinkDevice),
        content: const Text(AppTexts.unlinkDeviceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppTexts.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppTexts.unlinkDevice),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isUnlinking = true);
      final tickService = Provider.of<TickService>(context, listen: false);
      final success = await tickService.unlinkTick(widget.tickId);

      if (!mounted) return;

      if (success) {
        CustomSnackBar.showSuccess(context, AppTexts.unlinkSuccess);
        await Future.delayed(AppDurations.shortDelay);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() => _isUnlinking = false);
        CustomSnackBar.showError(context, tickService.error ?? "Erreur de désassociation.");
      }
    }
  }

  Future<void> _playPreview(int soundIndex) async {
    await _stopPreview();
    final soundPath = AppSounds.getSoundPath(soundIndex);
    print("Playing preview: $soundPath (Index: $soundIndex)");
    try {
      await _audioPlayer.play(AssetSource(soundPath));
      if (mounted) {
        setState(() {
          _currentlyPlayingSoundIndex = soundIndex;
        });
      }
    } catch (e) {
      print("Error playing sound preview: $e");
      if (mounted) {
        CustomSnackBar.showError(context, "Erreur lors de la lecture de l'aperçu.");
        setState(() {
          _currentlyPlayingSoundIndex = null;
        });
      }
    }
  }

  Future<void> _stopPreview() async {
    if (_currentlyPlayingSoundIndex != null) {
      print("Stopping preview...");
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _currentlyPlayingSoundIndex = null;
        });
      }
    }
  }

  void _showSoundSelectionDialog() {
    _stopPreview();
    final int? currentSelection = _tick?.selectedAlarmSoundIndex;

    showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(AppTexts.selectAlarmSound),
              contentPadding: const EdgeInsets.only(top: 10, bottom: 0, left: 0, right: 0),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: AppSounds.alarmSounds.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final soundIndex = AppSounds.alarmSounds.keys.elementAt(index);
                    final soundName = AppSounds.alarmSounds[soundIndex]!;
                    final bool isSelected = soundIndex == currentSelection;
                    final bool isPlaying = _currentlyPlayingSoundIndex == soundIndex;

                    return ListTile(
                      dense: true,
                      title: Text(soundName),
                      leading: Radio<int>(
                        value: soundIndex,
                        groupValue: currentSelection,
                        onChanged: (value) {
                          Navigator.pop(context, value);
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      trailing: IconButton(
                        icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 24),
                        color: Theme.of(context).colorScheme.secondary,
                        tooltip: isPlaying ? 'Arrêter' : AppTexts.preview,
                        onPressed: () {
                          if (isPlaying) {
                            _stopPreview().then((_) => setDialogState(() {}));
                          } else {
                            _playPreview(soundIndex).then((_) => setDialogState(() {}));
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context, soundIndex);
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _stopPreview();
                    Navigator.pop(context);
                  },
                  child: const Text(AppTexts.cancel),
                ),
              ],
            );
          },
        );
      },
    ).then((selectedValue) {
      _stopPreview();
      final int currentTickSoundIndex = _tick?.selectedAlarmSoundIndex ?? 1;
      if (selectedValue != null && selectedValue != currentTickSoundIndex) {
        print("TickSettingsPage: New sound selected ($selectedValue), updating settings via TickService.");
        Provider.of<TickService>(context, listen: false).updateTickSettings(
          widget.tickId,

          name: _tick?.name,
          alarmSoundIndex: selectedValue,
        );
      } else if (selectedValue != null) {
        print("TickSettingsPage: Same sound selected ($selectedValue), no update needed.");
      } else {
        print("TickSettingsPage: Sound selection cancelled.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tick == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("")),
        body: const Center(child: LoadingIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Paramètres - ${_tick!.name}"),
      ),
      body: AbsorbPointer(
        absorbing: _isUnlinking,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionTitle(context, AppTexts.general),
                _buildNameTile(),
                const SizedBox(height: 8),
                _buildInfoTile(
                  icon: Icons.bluetooth,
                  title: AppTexts.tickMacAddress,
                  subtitle: _tick!.macAddress ?? 'Non disponible',
                ),
                const Divider(height: 32),
                _buildSectionTitle(context, AppTexts.features),
                Builder(
                    builder: (context) {
                      final currentTick = _tick;
                      bool isCurrentlyDisabled = currentTick?.status == TickStatus.disabled;
                      bool isActionRunning = _isDisabling || _isEnabling;

                      String title;
                      IconData icon;
                      String subtitle;
                      Color? tileColor; // Couleur pour le titre et l'icône

                      if (isCurrentlyDisabled) {
                        title = AppTexts.reactivateDevice;
                        icon = Icons.play_circle_outline;
                        tileColor = null; // Pour couleur par défaut (noir/blanc)

                        if (currentTick!.disableEndTime != null && currentTick.disableEndTime!.isAfter(DateTime.now())) {

                          subtitle = "Réactivation prévue à ${DateFormat('HH:mm \'le\' dd/MM/yy', 'fr_FR').format(currentTick.disableEndTime!.toLocal())}";
                        } else if (currentTick.disableEndTime == null) {
                          subtitle = "Désactivé (réactivation manuelle)";
                        } else {
                          subtitle = "Réactivation en attente de confirmation";
                        }
                      } else {
                        title = AppTexts.disableDevice;
                        icon = Icons.pause_circle_outline;
                        subtitle = 'Désactiver la surveillance et les alertes';
                        tileColor = null;
                      }

                      final Widget? trailingWidget = isActionRunning ? const LoadingIndicator(size: 24) : null;

                      return _buildFeatureTile(
                        icon: icon,
                        title: title,
                        subtitle: subtitle,
                        onTap: isActionRunning ? null : _handleToggleActiveState,
                        trailing: trailingWidget,
                        color: tileColor,
                      );
                    }
                ),
                _buildSoundSettingTile(),
                const Divider(height: 32),
                _buildSectionTitle(context, AppTexts.dangerZone, color: AppTheme.errorColor),
                _buildFeatureTile(
                  icon: Icons.link_off,
                  title: AppTexts.unlinkDevice,
                  subtitle: 'Supprimer ce Tick de votre compte (irréversible)',
                  color: AppTheme.errorColor,
                  onTap: _isUnlinking ? null : _unlinkDevice,
                  trailing: SizedBox(
                    width: 48.0,
                    height: 48.0,
                    child: Center(
                      child: _isUnlinking
                          ? const LoadingIndicator(size: 24, color: AppTheme.errorColor)
                          : const Icon(Icons.delete_forever_outlined, color: AppTheme.errorColor),
                    ),
                  ),
                ),
              ],
            ),
            if (_isUnlinking)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: LoadingIndicator(size: 40)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameTile() {
    if (_isEditingName) {
      return Form(
        key: _nameFormKey,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.label_outline),
          title: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: AppTexts.tickName,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            validator: (value) => Validators.validateNotEmpty(value, "Le nom ne peut pas être vide"),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _saveName(),
            autofocus: true,
            enabled: !_isSavingName,
            textCapitalization: TextCapitalization.sentences,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: _isSavingName
                    ? const LoadingIndicator(size: 18)
                    : const Icon(Icons.check, color: AppTheme.successColor),
                tooltip: AppTexts.save,
                onPressed: _isSavingName ? null : _saveName,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: AppTexts.cancel,
                onPressed: _isSavingName ? null : () => setState(() {
                  _isEditingName = false;
                  _nameController.text = _tick?.name ?? '';
                  _nameFormKey.currentState?.reset();
                }),
              ),
            ],
          ),
        ),
      );
    } else {
      return ListTile(
        leading: const Icon(Icons.label_outline),
        title: const Text(AppTexts.tickName),
        subtitle: Text(_tick?.name ?? ''),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: AppTexts.edit,
          onPressed: () => setState(() => _isEditingName = true),
        ),
        onTap: () => setState(() => _isEditingName = true),
      );
    }
  }

  Widget _buildInfoTile({required IconData icon, required String title, required String subtitle}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      dense: true,
    );
  }

  /// Construit un ListTile pour une fonctionnalité ou une action.
  /// La couleur et le contenu (titre, icône, sous-titre) sont maintenant déterminés dans le Builder.
  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? color,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: onTap == null ? theme.disabledColor : color),
      title: Text(title, style: TextStyle(color: onTap == null ? theme.disabledColor : color)),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      trailing: SizedBox(
        width: 48.0,
        height: 48.0,
        child: Center(
          child: trailing ??
              (onTap != null ? Icon(Icons.arrow_forward_ios, size: 16, color: theme.textTheme.bodySmall?.color) : null),
        ),
      ),
      dense: true,
    );
  }

  Widget _buildSoundSettingTile() {
    final selectedIndex = _tick?.selectedAlarmSoundIndex ?? 1;
    final soundName = AppSounds.alarmSounds[selectedIndex] ?? AppTexts.noSoundSelected;
    final displaySubtitle = 'Actuelle: $soundName${selectedIndex == 1 ? " (Défaut)" : ""}';
    final theme = Theme.of(context);

    return ListTile(
      leading: const Icon(Icons.music_note_outlined),
      title: const Text(AppTexts.soundSettings),
      subtitle: Text(displaySubtitle),
      trailing: SizedBox(
        width: 48.0,
        height: 48.0,
        child: Center(
          child: Icon(Icons.arrow_forward_ios, size: 16, color: theme.textTheme.bodySmall?.color),
        ),
      ),
      onTap: _showSoundSelectionDialog,
    );
  } 

  Widget _buildSectionTitle(BuildContext context, String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 16.0, right: 16.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color ?? Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDurationPickerDialog() {
    return SimpleDialog(
      title: const Text("Désactiver l'appareil"),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, Duration.zero),
          child: const Text(AppTexts.untilReactivation),
        ),
        const Divider(),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(minutes: 30)),
          child: const Text('30 minutes'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(hours: 1)),
          child: const Text('1 heure'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(hours: 2)),
          child: const Text('2 heures'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(hours: 4)),
          child: const Text('4 heures'),
        ),
        const Divider(),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppTexts.cancel, style: TextStyle(color: AppTheme.errorColor)),
        ),
      ],
    );
  }
}