import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_channel.dart';
import '../models/chat_message.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'ai_screen.dart';
import 'login_screen.dart';
import 'monitor_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _SoundService _soundService = _SoundService();
  int _lastAlertVersion = 0;
  int _lastMessageCount = 0;
  int? _lastMessageChannelId;
  _MainPanel _activePanel = _MainPanel.chat;
  double _sidebarWidth = 300;
  bool _sidebarVisible = true;
  int _alertIdCounter = 0;
  final List<_AlertItem> _activeAlerts = <_AlertItem>[];

  @override
  void dispose() {
    for (final _AlertItem item in _activeAlerts) {
      item.timer?.cancel();
    }
    _soundService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(BuildContext context) async {
    final String content = _messageController.text.trim();
    if (content.isEmpty) return;
    try {
      await context.read<AuthProvider>().sendMessage(content);
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, 'Error enviando mensaje: $e');
    }
  }

  Future<void> _pickAndSendImage(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    if (auth.selectedChannelId == null) {
      _showErrorSnackBar(context, 'Selecciona un canal primero');
      return;
    }
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.first;
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        _showErrorSnackBar(context, 'No se pudo leer la imagen');
        return;
      }
      if (bytes.length > 5000000) {
        _showErrorSnackBar(context, 'Imagen demasiado grande (max 5 MB)');
        return;
      }
      await auth.sendImageMessage(base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, 'Error enviando imagen: $e');
    }
  }

  Future<void> _pickAndSendFile(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    if (auth.selectedChannelId == null) {
      _showErrorSnackBar(context, 'Selecciona un canal primero');
      return;
    }
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.first;
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        _showErrorSnackBar(this.context, 'No se pudo leer el archivo');
        return;
      }
      if (bytes.length > 10000000) {
        if (!mounted) return;
        _showErrorSnackBar(this.context, 'Archivo demasiado grande (max 10 MB)');
        return;
      }
      await auth.sendFileMessage(file.name, base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(this.context, 'Error enviando archivo: $e');
    }
  }

  void _selectPanel(_MainPanel panel) {
    setState(() => _activePanel = panel);
  }

  void _showSystemAlertIfNeeded(AuthProvider auth) {
    if (auth.systemAlertVersion == _lastAlertVersion) return;
    _lastAlertVersion = auth.systemAlertVersion;
    final String level = auth.systemAlertLevel;
    final String? alert = auth.systemAlertMessage;

    // Resolved — clear all active toasts immediately
    if (level == 'resolved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          for (final _AlertItem item in _activeAlerts) {
            item.timer?.cancel();
          }
          _activeAlerts.clear();
        });
      });
      return;
    }

    if (alert == null || alert.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final int id = _alertIdCounter++;
      final int autoDispose = level == 'warning' ? 8 : 10;
      final _AlertItem item = _AlertItem(id: id, message: alert, level: level);
      item.timer = Timer(Duration(seconds: autoDispose), () => _removeAlert(id));
      setState(() => _activeAlerts.add(item));
      final AuthProvider authForSound = context.read<AuthProvider>();
      if (authForSound.soundEnabled) _soundService.playAlert();
    });
  }

  void _removeAlert(int id) {
    if (!mounted) return;
    setState(() {
      final int idx = _activeAlerts.indexWhere((_AlertItem a) => a.id == id);
      if (idx != -1) {
        _activeAlerts[idx].timer?.cancel();
        _activeAlerts.removeAt(idx);
      }
    });
  }

  void _scrollToBottomIfNeeded(AuthProvider auth) {
    final int? channelId = auth.selectedChannelId;
    final int count = auth.selectedMessages.length;

    // Channel switched — reset baseline without playing sound
    if (channelId != _lastMessageChannelId) {
      _lastMessageChannelId = channelId;
      _lastMessageCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients &&
            _scrollController.position.hasContentDimensions) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
      return;
    }

    if (count <= _lastMessageCount) return;
    // Play sound only for genuinely new incoming messages (not history load)
    if (_lastMessageCount > 0 && auth.soundEnabled) _soundService.playMessage();
    _lastMessageCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(BuildContext context, String message, {bool isAlert = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isAlert ? AppTheme.warning : AppTheme.critical,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryOrange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController currentCtrl = TextEditingController();
    final TextEditingController newCtrl = TextEditingController();
    final TextEditingController confirmCtrl = TextEditingController();
    bool canSubmit = false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, void Function(void Function()) setS) => AlertDialog(
          title: const Text('Cambiar contraseña'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onChanged: (_) => setS(() => canSubmit = currentCtrl.text.isNotEmpty &&
                      newCtrl.text.length >= 4 &&
                      newCtrl.text == confirmCtrl.text),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  onChanged: (_) => setS(() => canSubmit = currentCtrl.text.isNotEmpty &&
                      newCtrl.text.length >= 4 &&
                      newCtrl.text == confirmCtrl.text),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nueva contraseña',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  onChanged: (_) => setS(() => canSubmit = currentCtrl.text.isNotEmpty &&
                      newCtrl.text.length >= 4 &&
                      newCtrl.text == confirmCtrl.text),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: canSubmit ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Cambiar'),
              ),
            ],
          ),
        ),
    );

    if (confirmed != true) return;
    final bool ok = await auth.changePassword(
      currentPassword: currentCtrl.text,
      newPassword: newCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      _showInfoSnackBar(this.context, 'Contraseña cambiada correctamente');
    } else {
      _showErrorSnackBar(this.context, auth.errorMessage ?? 'Error al cambiar contraseña');
    }
  }

  Future<void> _showChangeUrlDialog(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController ctrl = TextEditingController(text: auth.webSocketUrl);
    final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('URL del servidor'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'WebSocket URL',
              prefixIcon: Icon(Icons.cloud_outlined),
              hintText: 'ws://192.168.1.1:8080/ws',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await auth.setWebSocketUrl(ctrl.text);
      if (!mounted) return;
      _showInfoSnackBar(this.context, 'URL guardada. Se aplicará en el próximo inicio de sesión.');
  }

  Future<void> _exportChat(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    try {
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar exportación de chats',
        fileName: 'sentinellink_chats.txt',
        allowedExtensions: <String>['txt'],
        type: FileType.custom,
      );
      if (path == null) {
        if (kIsWeb && mounted) {
          _showErrorSnackBar(this.context, 'Exportación a archivo no disponible en el navegador');
        }
        return;
      }
      await auth.exportAllChannelsToTxt(path);
      if (!mounted) return;
      _showInfoSnackBar(this.context, 'Chats exportados en: $path');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(this.context, 'No se pudo exportar: $e');
    }
  }

  Future<void> _showInviteToChannelDialog(BuildContext context, ChatChannel channel) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController ctrl = TextEditingController();
    bool canSubmit = false;

    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => StatefulBuilder(
          builder: (BuildContext dialogCtx, void Function(void Function()) setS) => AlertDialog(
            title: Text('Invitar a «${channel.name}»'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre de usuario',
                prefixIcon: Icon(Icons.person_add_outlined),
              ),
              onChanged: (String v) => setS(() => canSubmit = v.trim().isNotEmpty),
              onSubmitted: canSubmit ? (_) => Navigator.pop(dialogCtx, true) : null,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: canSubmit ? () => Navigator.pop(dialogCtx, true) : null,
                child: const Text('Invitar'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) return;
      await auth.inviteToPrivateChannel(channel.name, ctrl.text.trim());
      if (!mounted) return;
      _showInfoSnackBar(this.context, 'Invitación enviada a ${ctrl.text.trim()}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(this.context, 'Error al invitar: $e');
    }
  }

  Future<void> _showSearchPrivateChannelDialog(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController ctrl = TextEditingController();
    bool canSubmit = false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, void Function(void Function()) setS) => AlertDialog(
          title: const Text('Buscar canal privado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Escribe el nombre exacto del canal privado para unirte.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre del canal',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onChanged: (String v) => setS(() => canSubmit = v.trim().isNotEmpty),
                onSubmitted: canSubmit ? (_) => Navigator.pop(dialogCtx, true) : null,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: canSubmit ? () => Navigator.pop(dialogCtx, true) : null,
              child: const Text('Buscar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final int? channelId = await auth.searchChannel(ctrl.text.trim());
    if (!mounted) return;
    if (channelId != null) {
      auth.selectChannel(channelId);
      _selectPanel(_MainPanel.chat);
      _showInfoSnackBar(this.context, 'Canal encontrado y seleccionado');
    } else {
      _showErrorSnackBar(this.context, auth.errorMessage ?? 'Canal no encontrado');
    }
  }

  Future<void> _showCreateChannelDialog(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController nameController = TextEditingController();
    bool isPrivate = false;
    bool canSubmit = false;

    final bool? shouldCreate = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, void Function(void Function()) setS) {
            return AlertDialog(
              title: const Text('Nuevo canal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del canal',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    onChanged: (String value) => setS(() => canSubmit = value.trim().isNotEmpty),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isPrivate,
                    onChanged: (bool value) => setS(() => isPrivate = value),
                    title: const Text('Canal privado'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: canSubmit ? () => Navigator.of(dialogContext).pop(true) : null,
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldCreate != true) return;

    final int? channelId = await auth.createChannel(
      name: nameController.text.trim(),
      isPrivate: isPrivate,
    );

    if (!mounted) return;

    if (channelId != null) {
      await auth.selectChannel(channelId);
      _selectPanel(_MainPanel.chat);
      _showInfoSnackBar(this.context, 'Canal creado correctamente');
    } else {
      _showErrorSnackBar(this.context, auth.errorMessage ?? 'No se pudo crear el canal');
    }
  }

  Future<void> _showRenameChannelDialog(BuildContext context, ChatChannel channel) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController nameController = TextEditingController(text: channel.name);
    bool canSubmit = nameController.text.trim().isNotEmpty;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext dialogCtx, void Function(void Function()) setS) => AlertDialog(
          title: const Text('Renombrar canal'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nuevo nombre',
              prefixIcon: Icon(Icons.tag),
            ),
            onChanged: (String v) => setS(() => canSubmit = v.trim().length >= 3),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: canSubmit ? () => Navigator.pop(dialogCtx, true) : null,
              child: const Text('Renombrar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final bool ok = await auth.renameChannel(channel.id, nameController.text.trim());
    if (!mounted) return;
    if (ok) {
      _showInfoSnackBar(this.context, 'Canal renombrado');
    } else {
      _showErrorSnackBar(this.context, auth.errorMessage ?? 'No se pudo renombrar');
    }
  }

  Future<void> _confirmDeleteChannel(BuildContext context, ChatChannel channel) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Eliminar canal'),
        content: Text('¿Eliminar "#${channel.name}"? Esta acción no se puede deshacer.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.critical),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final bool ok = await auth.deleteChannel(channel.id);
    if (!mounted) return;
    if (ok) {
      _showInfoSnackBar(this.context, 'Canal eliminado');
    } else {
      _showErrorSnackBar(this.context, auth.errorMessage ?? 'No se pudo eliminar');
    }
  }

  Future<void> _openDm(BuildContext context, String targetUser) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final int? channelId = await auth.createDm(targetUser);
    if (!mounted) return;
    if (channelId != null) {
      _selectPanel(_MainPanel.chat);
    } else {
      _showErrorSnackBar(this.context, auth.errorMessage ?? 'No se pudo abrir el DM');
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Cerrar Sesion'),
        content: const Text('¿Estas seguro de que deseas cerrar sesion?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<LoginScreen>(
          builder: (BuildContext context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    _showSystemAlertIfNeeded(auth);
    _scrollToBottomIfNeeded(auth);
    final bool wideLayout = MediaQuery.of(context).size.width >= 900;

    final Widget sidebar = _Sidebar(
      auth: auth,
      activePanel: _activePanel,
      onSelectPanel: _selectPanel,
      onSelectChannel: (int id) {
        context.read<AuthProvider>().selectChannel(id);
        _selectPanel(_MainPanel.chat);
      },
      onCreateChannel: () {
        if (!wideLayout) Navigator.of(context).pop();
        _showCreateChannelDialog(context);
      },
      onSearchPrivateChannel: () {
        if (!wideLayout) Navigator.of(context).pop();
        _showSearchPrivateChannelDialog(context);
      },
      onInviteToChannel: (ChatChannel ch) {
        if (!wideLayout) Navigator.of(context).pop();
        _showInviteToChannelDialog(context, ch);
      },
      onOpenDm: (String user) {
        if (!wideLayout) Navigator.of(context).pop();
        _openDm(context, user);
      },
      onRenameChannel: (ChatChannel ch) {
        if (!wideLayout) Navigator.of(context).pop();
        _showRenameChannelDialog(context, ch);
      },
      onDeleteChannel: (ChatChannel ch) {
        if (!wideLayout) Navigator.of(context).pop();
        _confirmDeleteChannel(context, ch);
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: wideLayout
            ? IconButton(
                tooltip: _sidebarVisible ? 'Ocultar panel' : 'Mostrar panel',
                onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
                icon: Icon(
                  _sidebarVisible
                      ? Icons.keyboard_arrow_left_outlined
                      : Icons.keyboard_arrow_right_outlined,
                ),
              )
            : null,
        title: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.apartment,
                color: AppTheme.primaryOrangeForeground,
                size: 18,
              ),
            ),
            if (wideLayout) ...<Widget>[
              const SizedBox(width: 10),
              Text('SentinelLink', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 12),
              Container(width: 1, height: 20, color: Theme.of(context).dividerColor),
            ],
            const SizedBox(width: 10),
            Icon(
              auth.selectedChannel?.isPrivate == true ? Icons.lock_outline : Icons.tag,
              size: 20,
              color: AppTheme.primaryOrange,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _activePanel == _MainPanel.chat
                    ? (auth.selectedChannel?.name ?? 'Chat')
                    : _activePanel.label,
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          // User avatar + info
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryOrange,
                child: Text(
                  (auth.username ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryOrangeForeground,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (wideLayout) ...<Widget>[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      auth.username ?? 'Invitado',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (auth.role != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          auth.role!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: wideLayout
          ? null
          : Drawer(child: sidebar),
      body: Stack(
        children: <Widget>[
          LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget chatArea = _ChatPanel(
            auth: auth,
            messageController: _messageController,
            scrollController: _scrollController,
            onSend: () => _sendMessage(context),
            onPickImage: () => _pickAndSendImage(context),
            onPickFile: () => _pickAndSendFile(context),
          );

          final Widget panel = switch (_activePanel) {
            _MainPanel.chat => chatArea,
            _MainPanel.monitor => const MonitorPanel(),
            _MainPanel.ai => const AIPanel(),
            _MainPanel.settings => _SettingsPanel(
                onExport: () => _exportChat(context),
                onChangePassword: () => _showChangePasswordDialog(context),
                onChangeUrl: () => _showChangeUrlDialog(context),
              ),
          };

          if (wideLayout) {
            return Row(
              children: <Widget>[
                if (_sidebarVisible) ...<Widget>[
                  SizedBox(
                    width: _sidebarWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                      ),
                      child: sidebar,
                    ),
                  ),
                  _SidebarResizer(
                    onDrag: (double delta) {
                      setState(() {
                        _sidebarWidth = (_sidebarWidth + delta).clamp(240.0, 420.0);
                      });
                    },
                  ),
                ],
                Expanded(child: panel),
              ],
            );
          }

          return panel;
        },
      ),
          // Alert overlay — stacked toasts, top-right
          Positioned(
            top: 16,
            right: 16,
            width: 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _activeAlerts.map((_AlertItem item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: ValueKey<int>(item.id),
                  direction: DismissDirection.startToEnd,
                  onDismissed: (_) => _removeAlert(item.id),
                  child: _AlertToast(
                    key: ValueKey<int>(item.id),
                    message: item.message,
                    level: item.level,
                    onClose: () => _removeAlert(item.id),
                    onTap: () {
                      _removeAlert(item.id);
                      _selectPanel(_MainPanel.monitor);
                    },
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MainPanel {
  chat('Chat'),
  monitor('Monitor'),
  ai('IA'),
  settings('Configuracion');

  const _MainPanel(this.label);

  final String label;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.auth,
    required this.activePanel,
    required this.onSelectPanel,
    required this.onSelectChannel,
    required this.onCreateChannel,
    required this.onSearchPrivateChannel,
    required this.onInviteToChannel,
    required this.onOpenDm,
    required this.onRenameChannel,
    required this.onDeleteChannel,
  });

  final AuthProvider auth;
  final _MainPanel activePanel;
  final ValueChanged<_MainPanel> onSelectPanel;
  final ValueChanged<int> onSelectChannel;
  final VoidCallback onCreateChannel;
  final VoidCallback onSearchPrivateChannel;
  final ValueChanged<ChatChannel> onInviteToChannel;
  final ValueChanged<String> onOpenDm;
  final ValueChanged<ChatChannel> onRenameChannel;
  final ValueChanged<ChatChannel> onDeleteChannel;

  @override
  Widget build(BuildContext context) {
    final String myUsername = auth.username ?? '';
    final List<ChatChannel> groups = auth.groupChannels;
    final List<ChatChannel> dms = auth.dmChannels;

    return SafeArea(
      child: Column(
        children: <Widget>[
          // ── Scrollable top section: channels, DMs, users ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              children: <Widget>[
                _sectionHeader(context, 'CANALES', trailing: IconButton(
                  tooltip: 'Nuevo canal',
                  onPressed: onCreateChannel,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                )),
                const SizedBox(height: 4),
                if (groups.isEmpty)
                  _emptyHint(context, 'No hay canales')
                else
                  ...groups.map(
                    (ChatChannel channel) => _SidebarChannel(
                      label: channel.name,
                      icon: channel.isPrivate ? Icons.lock_outline : Icons.tag,
                      isSelected: auth.selectedChannelId == channel.id,
                      unreadCount: auth.unreadCounts[channel.id] ?? 0,
                      onTap: () => onSelectChannel(channel.id),
                      onInvite: channel.isPrivate ? () => onInviteToChannel(channel) : null,
                      onRename: () => onRenameChannel(channel),
                      onDelete: () => onDeleteChannel(channel),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.search, size: 15),
                    label: const Text('Buscar canal privado', style: TextStyle(fontSize: 12)),
                    onPressed: onSearchPrivateChannel,
                  ),
                ),
                const SizedBox(height: 16),
                _sectionHeader(context, 'MENSAJES DIRECTOS'),
                const SizedBox(height: 4),
                if (dms.isEmpty)
                  _emptyHint(context, 'Sin mensajes directos')
                else
                  ...dms.map(
                    (ChatChannel dm) => _SidebarChannel(
                      label: dm.dmOtherUser(myUsername),
                      icon: Icons.person_outline,
                      isSelected: auth.selectedChannelId == dm.id,
                      unreadCount: auth.unreadCounts[dm.id] ?? 0,
                      onTap: () => onSelectChannel(dm.id),
                    ),
                  ),
                const SizedBox(height: 16),
                _sectionHeader(context, 'USUARIOS ONLINE'),
                const SizedBox(height: 4),
                if (auth.onlineUsers.isEmpty)
                  _emptyHint(context, 'Nadie conectado')
                else
                  ...auth.onlineUsers.map(
                    (String user) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: user != myUsername ? () => onOpenDm(user) : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.online,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    user,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user != myUsername)
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // ── Fixed bottom nav: Monitor, IA, Settings ──
          Divider(height: 1, color: Theme.of(context).dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              children: <Widget>[
                _NavButton(
                  icon: Icons.monitor_heart_outlined,
                  label: 'Monitor',
                  isSelected: activePanel == _MainPanel.monitor,
                  onTap: () => onSelectPanel(_MainPanel.monitor),
                ),
                _NavButton(
                  icon: Icons.smart_toy_outlined,
                  label: 'Asistente IA',
                  isSelected: activePanel == _MainPanel.ai,
                  onTap: () => onSelectPanel(_MainPanel.ai),
                ),
                _NavButton(
                  icon: Icons.settings_outlined,
                  label: 'Configuracion',
                  isSelected: activePanel == _MainPanel.settings,
                  onTap: () => onSelectPanel(_MainPanel.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _emptyHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppTheme.primaryOrange.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppTheme.primaryOrange
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? AppTheme.primaryOrange
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarChannel extends StatelessWidget {
  const _SidebarChannel({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.unreadCount = 0,
    this.onInvite,
    this.onRename,
    this.onDelete,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int unreadCount;
  final VoidCallback? onInvite;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected
            ? AppTheme.primaryOrange.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppTheme.primaryOrange
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? AppTheme.primaryOrange
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0 && !isSelected)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: AppTheme.primaryOrangeForeground,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (onInvite != null || onRename != null || onDelete != null)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (String value) {
                      if (value == 'invite') onInvite?.call();
                      if (value == 'rename') onRename?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                      if (onInvite != null)
                        const PopupMenuItem<String>(
                          value: 'invite',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.person_add_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Invitar usuario'),
                            ],
                          ),
                        ),
                      if (onRename != null)
                        const PopupMenuItem<String>(
                          value: 'rename',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Renombrar'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.delete_outline, size: 16, color: AppTheme.critical),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: AppTheme.critical)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarResizer extends StatelessWidget {
  const _SidebarResizer({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (DragUpdateDetails details) => onDrag(details.delta.dx),
        child: Container(
          width: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              height: double.infinity,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.onExport,
    required this.onChangePassword,
    required this.onChangeUrl,
  });

  final VoidCallback onExport;
  final VoidCallback onChangePassword;
  final VoidCallback onChangeUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.watch<ThemeController>();
    final AuthProvider auth = context.watch<AuthProvider>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text('Configuracion', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        // ── Cuenta ──
        Text('Cuenta', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_reset_outlined),
            title: const Text('Cambiar contraseña'),
            subtitle: const Text('Actualiza tu contraseña de acceso'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onChangePassword,
          ),
        ),
        const SizedBox(height: 20),

        // ── Conexión ──
        Text('Conexion', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('URL del servidor'),
            subtitle: Text(auth.webSocketUrl, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: onChangeUrl,
          ),
        ),
        const SizedBox(height: 20),

        // ── Apariencia ──
        Text('Apariencia', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Tema claro/oscuro'),
            subtitle: Text(theme.isDark ? 'Modo oscuro' : 'Modo claro'),
            trailing: Switch(
              value: theme.isDark,
              onChanged: (_) => theme.toggle(),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Notificaciones ──
        Text('Notificaciones', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.volume_up_outlined),
            title: const Text('Sonido de notificaciones'),
            subtitle: const Text('Reproduce un sonido al recibir alertas o mensajes'),
            trailing: Switch(
              value: auth.soundEnabled,
              onChanged: (bool v) => auth.setSoundEnabled(v),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Datos ──
        Text('Datos', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar todos los chats a TXT'),
            subtitle: const Text('Guarda todos los canales y DMs en un archivo de texto'),
            onTap: onExport,
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Asistente IA'),
            subtitle: Text('Requiere Ollama instalado y activo'),
          ),
        ),
      ],
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.auth,
    required this.messageController,
    required this.scrollController,
    required this.onSend,
    required this.onPickImage,
    required this.onPickFile,
  });

  final AuthProvider auth;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;

  String _formatTime(DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static const Set<String> _imageExtensions = <String>{
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
  };

  bool _isImageFile(String fileName) {
    final String ext = fileName.split('.').last.toLowerCase();
    return _imageExtensions.contains(ext);
  }

  Widget _buildMessageBody(BuildContext context, ChatMessage message, bool isMine) {
    if (message.messageType == 'IMAGE' && message.imageBase64 != null) {
      try {
        final Uint8List bytes = base64Decode(message.imageBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 320),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        );
      } catch (_) {
        return Text(
          'Imagen no disponible',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isMine ? AppTheme.primaryOrangeForeground : Theme.of(context).colorScheme.onSurface,
          ),
        );
      }
    }

    if (message.messageType == 'FILE' && message.imageBase64 != null) {
      final String fileName = message.content;

      // Image files: render inline
      if (_isImageFile(fileName)) {
        try {
          final Uint8List bytes = base64Decode(message.imageBase64!);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400, maxHeight: 320),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fileName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isMine
                      ? AppTheme.primaryOrangeForeground.withValues(alpha: 0.75)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        } catch (_) {}
      }

      // Non-image files: show save card
      return _FileAttachmentCard(
        fileName: fileName,
        fileBase64: message.imageBase64!,
        isMine: isMine,
      );
    }

    // Invitation card — content starts with 🔒INVITE:<channelName>
    const String invitePrefix = '\u{1F512}INVITE:';
    if (message.content.startsWith(invitePrefix)) {
      final int newline = message.content.indexOf('\n');
      final String channelName = newline > invitePrefix.length
          ? message.content.substring(invitePrefix.length, newline)
          : message.content.substring(invitePrefix.length);
      final String body = newline >= 0 ? message.content.substring(newline + 1) : '';
      return _InviteCard(channelName: channelName, body: body, isMine: isMine);
    }

    return Text(
      message.content,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: isMine
            ? AppTheme.primaryOrangeForeground
            : Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ChatMessage> messages = auth.selectedMessages;
    final ChatChannel? channel = auth.selectedChannel;
    final bool isDm = channel?.isDm == true;
    final String myUsername = auth.username ?? '';

    return Column(
      children: <Widget>[
        if (isDm && channel != null)
          _DmHeader(
            otherUser: channel.dmOtherUser(myUsername),
            isOnline: auth.onlineUsers.contains(channel.dmOtherUser(myUsername)),
          ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.chat_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        auth.selectedChannel == null
                            ? 'Selecciona un canal para empezar'
                            : 'No hay mensajes en ${auth.selectedChannel!.name}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ChatMessage message = messages[index];
                    final bool isMine = message.sender == auth.username;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? AppTheme.primaryOrange
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: isMine
                                  ? null
                                  : Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Flexible(
                                      child: Text(
                                        message.sender,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                          color: isMine
                                              ? AppTheme.primaryOrangeForeground
                                              : Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(message.timestamp),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                        color: isMine
                                            ? AppTheme.primaryOrangeForeground
                                                .withValues(alpha: 0.7)
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildMessageBody(context, message, isMine),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: messageController,
                    enabled: auth.selectedChannelId != null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: auth.selectedChannelId != null ? (_) => onSend() : null,
                    decoration: InputDecoration(
                      hintText: auth.selectedChannel == null
                          ? 'Selecciona un canal'
                          : 'Mensaje en ${auth.selectedChannel!.name}',
                      prefixIcon: const Icon(Icons.message_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Enviar imagen',
                  onPressed: auth.selectedChannelId == null ? null : onPickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                IconButton(
                  tooltip: 'Adjuntar archivo',
                  onPressed: auth.selectedChannelId == null ? null : onPickFile,
                  icon: const Icon(Icons.attach_file_outlined),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: auth.selectedChannelId == null ? null : onSend,
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DmHeader extends StatelessWidget {
  const _DmHeader({required this.otherUser, required this.isOnline});

  final String otherUser;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: <Widget>[
          Stack(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.15),
                child: Text(
                  otherUser.isNotEmpty ? otherUser[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline ? AppTheme.online : AppTheme.offline,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(otherUser, style: Theme.of(context).textTheme.titleSmall),
              Text(
                isOnline ? 'En línea' : 'Desconectado',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isOnline ? AppTheme.online : AppTheme.offline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertItem {
  _AlertItem({required this.id, required this.message, required this.level});
  final int id;
  final String message;
  final String level; // 'critical', 'warning', 'resolved'
  Timer? timer;
}

class _AlertToast extends StatefulWidget {
  const _AlertToast({
    super.key,
    required this.message,
    required this.level,
    required this.onClose,
    required this.onTap,
  });

  final String message;
  final String level;
  final VoidCallback onClose;
  final VoidCallback onTap;

  @override
  State<_AlertToast> createState() => _AlertToastState();
}

class _AlertToastState extends State<_AlertToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (widget.level) {
      'critical' => AppTheme.critical,
      'warning'  => const Color(0xFFF59E0B),
      _          => AppTheme.warning,
    };
    final IconData icon = switch (widget.level) {
      'critical' => Icons.error_outline,
      'warning'  => Icons.warning_amber_outlined,
      _          => Icons.notifications_active_outlined,
    };
    final String title = switch (widget.level) {
      'critical' => 'Alerta crítica — ver monitor',
      'warning'  => 'Aviso del sistema — ver monitor',
      _          => 'Alerta del sistema',
    };

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(14),
          shadowColor: accent.withValues(alpha: 0.35),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(widget.message, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.channelName,
    required this.body,
    required this.isMine,
  });

  final String channelName;
  final String body;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final Color fg = isMine
        ? AppTheme.primaryOrangeForeground
        : Theme.of(context).colorScheme.onSurface;
    final Color fgMuted = isMine
        ? AppTheme.primaryOrangeForeground.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Canal privado: $channelName',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (body.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(body, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fgMuted)),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: isMine
                ? AppTheme.primaryOrangeForeground.withValues(alpha: 0.2)
                : AppTheme.primaryOrange,
            foregroundColor: isMine ? AppTheme.primaryOrangeForeground : AppTheme.primaryOrangeForeground,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.login, size: 16),
          label: const Text('Unirse al canal'),
          onPressed: () async {
            final AuthProvider auth = context.read<AuthProvider>();
            final int? channelId = await auth.searchChannel(channelName);
            if (!context.mounted) return;
            if (channelId != null) {
              await auth.selectChannel(channelId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Unido al canal «$channelName»'),
                backgroundColor: AppTheme.primaryOrange,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(auth.errorMessage ?? 'Canal no encontrado'),
                backgroundColor: AppTheme.critical,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
              ));
            }
          },
        ),
      ],
    );
  }
}

class _FileAttachmentCard extends StatelessWidget {
  const _FileAttachmentCard({
    required this.fileName,
    required this.fileBase64,
    required this.isMine,
  });

  final String fileName;
  final String fileBase64;
  final bool isMine;

  IconData _iconForFile(String name) {
    final String ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx': return Icons.description_outlined;
      case 'xls':
      case 'xlsx': return Icons.table_chart_outlined;
      case 'zip':
      case 'rar':
      case '7z': return Icons.folder_zip_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  Future<void> _save(BuildContext context) async {
    try {
      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar archivo',
        fileName: fileName,
      );
      if (path == null) return;
      final Uint8List bytes = base64Decode(fileBase64);
      await File(path).writeAsBytes(bytes);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Guardado en: $path'),
        backgroundColor: AppTheme.primaryOrange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al guardar: $e'),
        backgroundColor: AppTheme.critical,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color fg = isMine
        ? AppTheme.primaryOrangeForeground
        : Theme.of(context).colorScheme.onSurface;
    final Color fgMuted = isMine
        ? AppTheme.primaryOrangeForeground.withValues(alpha: 0.65)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(_iconForFile(fileName), size: 28, color: fg),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                fileName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              GestureDetector(
                onTap: () => _save(context),
                child: Text(
                  'Guardar archivo',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fgMuted,
                    decoration: TextDecoration.underline,
                    decorationColor: fgMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoundService {
  final AudioPlayer _alertPlayer = AudioPlayer();
  final AudioPlayer _messagePlayer = AudioPlayer();

  Future<void> playAlert() async {
    try {
      await _alertPlayer.play(AssetSource('sounds/popup.mp3'));
    } catch (_) {}
  }

  Future<void> playMessage() async {
    try {
      await _messagePlayer.play(AssetSource('sounds/mensaje.mp3'));
    } catch (_) {}
  }

  void dispose() {
    _alertPlayer.dispose();
    _messagePlayer.dispose();
  }
}
