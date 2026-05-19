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
  _MainPanel _activePanel = _MainPanel.chat;
  double _sidebarWidth = 300;
  bool _sidebarVisible = true;

  @override
  void dispose() {
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
      _showErrorSnackBar(context, alert, isAlert: true);
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
    );

    return Scaffold(
      appBar: AppBar(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    auth.username ?? 'Invitado',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (auth.role != null)
                    Text(auth.role!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => _handleLogout(context),
            child: const Text('Salir'),
          ),
          if (wideLayout)
            IconButton(
              tooltip: _sidebarVisible ? 'Ocultar panel' : 'Mostrar panel',
              onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
              icon: Icon(
                _sidebarVisible
                    ? Icons.keyboard_arrow_right_outlined
                    : Icons.keyboard_arrow_left_outlined,
              ),
            )
          else
            Builder(
              builder: (BuildContext ctx) => IconButton(
                tooltip: 'Panel lateral',
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                icon: const Icon(Icons.menu_outlined),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      endDrawer: wideLayout
          ? null
          : Drawer(child: sidebar),
      body: LayoutBuilder(
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
                Expanded(child: panel),
                if (_sidebarVisible) ...<Widget>[
                  _SidebarResizer(
                    onDrag: (double delta) {
                      setState(() {
                        _sidebarWidth = (_sidebarWidth - delta).clamp(240.0, 420.0);
                      });
                    },
                  ),
                  SizedBox(
                    width: _sidebarWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                      ),
                      child: sidebar,
                    ),
                  ),
                ],
              ],
            );
          }

          return panel;
        },
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
  });

  final AuthProvider auth;
  final _MainPanel activePanel;
  final ValueChanged<_MainPanel> onSelectPanel;
  final ValueChanged<int> onSelectChannel;
  final VoidCallback onCreateChannel;
  final ValueChanged<String> onOpenDm;

  @override
  Widget build(BuildContext context) {
    final String myUsername = auth.username ?? '';
    final List<ChatChannel> groups = auth.groupChannels;
    final List<ChatChannel> dms = auth.dmChannels;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          _SidebarSection(
            icon: Icons.monitor_heart_outlined,
            title: 'Monitor del Sistema',
            subtitle: 'CPU, RAM, Disco',
            isSelected: activePanel == _MainPanel.monitor,
            onTap: () => onSelectPanel(_MainPanel.monitor),
          ),
          const SizedBox(height: 8),
          _SidebarSection(
            icon: Icons.smart_toy_outlined,
            title: 'Asistente IA',
            subtitle: 'Chat con inteligencia artificial',
            isSelected: activePanel == _MainPanel.ai,
            onTap: () => onSelectPanel(_MainPanel.ai),
          ),
          const SizedBox(height: 8),
          _SidebarSection(
            icon: Icons.settings_outlined,
            title: 'Configuracion',
            subtitle: 'Tema, exportaciones',
            isSelected: activePanel == _MainPanel.settings,
            onTap: () => onSelectPanel(_MainPanel.settings),
          ),
          const SizedBox(height: 20),
          _sectionHeader(context, 'CANALES', trailing: IconButton(
            tooltip: 'Nuevo canal',
            onPressed: onCreateChannel,
            icon: const Icon(Icons.add_circle_outline),
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
                onTap: () => onSelectChannel(channel.id),
              ),
            ),
          const SizedBox(height: 20),
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
                onTap: () => onSelectChannel(dm.id),
              ),
            ),
          const SizedBox(height: 20),
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

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: AppTheme.primaryOrange),
        tileColor: isSelected ? AppTheme.primaryOrange.withValues(alpha: 0.08) : null,
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        onTap: onTap,
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
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

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
          child: Image.memory(bytes, fit: BoxFit.cover),
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

    return Column(
      children: <Widget>[
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
