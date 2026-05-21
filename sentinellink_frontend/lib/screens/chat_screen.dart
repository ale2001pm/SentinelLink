import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
  int _lastAlertVersion = 0;
  int _lastMessageCount = 0;
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
      if (bytes.length > 1500000) {
        _showErrorSnackBar(context, 'Imagen demasiado grande (max 1.5 MB)');
        return;
      }
      await auth.sendImageMessage(base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, 'Error enviando imagen: $e');
    }
  }

  void _selectPanel(_MainPanel panel) {
    setState(() => _activePanel = panel);
  }

  void _showSystemAlertIfNeeded(AuthProvider auth) {
    if (auth.systemAlertVersion == _lastAlertVersion) return;
    _lastAlertVersion = auth.systemAlertVersion;
    final String? alert = auth.systemAlertMessage;
    if (alert == null || alert.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final int id = _alertIdCounter++;
      final _AlertItem item = _AlertItem(id: id, message: alert);
      item.timer = Timer(const Duration(seconds: 10), () => _removeAlert(id));
      setState(() => _activeAlerts.add(item));
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
    final int count = auth.selectedMessages.length;
    if (count <= _lastMessageCount) return;
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

  Future<void> _exportChat(BuildContext context) async {
    try {
      final String path = await context.read<AuthProvider>().exportSelectedChannelToXml();
      if (!mounted) return;
      _showInfoSnackBar(context, 'Chat exportado en: $path');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, 'No se pudo exportar: $e');
    }
  }

  Future<void> _showCreateChannelDialog(BuildContext context) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController nameController = TextEditingController();
    bool isPrivate = false;
    bool canSubmit = false;

    try {
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
        _selectPanel(_MainPanel.chat);
        _showInfoSnackBar(this.context, 'Canal creado correctamente');
      } else {
        _showErrorSnackBar(this.context, auth.errorMessage ?? 'No se pudo crear el canal');
      }
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _showRenameChannelDialog(BuildContext context, ChatChannel channel) async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController nameController = TextEditingController(text: channel.name);
    bool canSubmit = nameController.text.trim().isNotEmpty;

    try {
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
    } finally {
      nameController.dispose();
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
            const SizedBox(width: 10),
            Text('SentinelLink', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: Theme.of(context).dividerColor),
            const SizedBox(width: 12),
            Icon(
              auth.selectedChannel?.isPrivate == true ? Icons.lock_outline : Icons.tag,
              size: 20,
              color: AppTheme.primaryOrange,
            ),
            const SizedBox(width: 8),
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
          );

          final Widget panel = switch (_activePanel) {
            _MainPanel.chat => chatArea,
            _MainPanel.monitor => const MonitorPanel(),
            _MainPanel.ai => const AIPanel(),
            _MainPanel.settings => _SettingsPanel(
                onExport: () => _exportChat(context),
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
                    onClose: () => _removeAlert(item.id),
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
    required this.onOpenDm,
    required this.onRenameChannel,
    required this.onDeleteChannel,
  });

  final AuthProvider auth;
  final _MainPanel activePanel;
  final ValueChanged<_MainPanel> onSelectPanel;
  final ValueChanged<int> onSelectChannel;
  final VoidCallback onCreateChannel;
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
                      onRename: () => onRenameChannel(channel),
                      onDelete: () => onDeleteChannel(channel),
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
    this.onRename,
    this.onDelete,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int unreadCount;
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
                if (onRename != null || onDelete != null)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (String value) {
                      if (value == 'rename') onRename?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
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
  const _SettingsPanel({required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.watch<ThemeController>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text('Configuracion', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
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
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Exportar chat a XML'),
            subtitle: const Text('Guarda el chat actual en un archivo XML'),
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
  });

  final AuthProvider auth;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  String _formatTime(DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageBody(BuildContext context, ChatMessage message, bool isMine) {
    if (message.messageType == 'IMAGE' && message.imageBase64 != null) {
      try {
        final Uint8List bytes = base64Decode(message.imageBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 320),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              frameBuilder: (BuildContext ctx, Widget child, int? frame, bool sync) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: frame == null
                      ? const SizedBox(
                          width: 200,
                          height: 120,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : child,
                );
              },
            ),
          ),
        );
      } catch (_) {
        return Text(
          'Imagen no disponible',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isMine
                ? AppTheme.primaryOrangeForeground
                : Theme.of(context).colorScheme.onSurface,
          ),
        );
      }
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
  _AlertItem({required this.id, required this.message});
  final int id;
  final String message;
  Timer? timer;
}

class _AlertToast extends StatefulWidget {
  const _AlertToast({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

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
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(14),
          shadowColor: AppTheme.warning.withValues(alpha: 0.35),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppTheme.warning,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Alerta del sistema',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.warning,
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
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
