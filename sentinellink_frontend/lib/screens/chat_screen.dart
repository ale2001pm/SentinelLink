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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(BuildContext context) async {
    final String content = _messageController.text.trim();
    if (content.isEmpty) {
      return;
    }

    try {
      await context.read<AuthProvider>().sendMessage(content);
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(context, 'Error enviando mensaje: $e');
    }
  }

  void _openMonitor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<MonitorScreen>(
        builder: (BuildContext context) => const MonitorScreen(),
      ),
    );
  }

  void _openAssistant(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<AIScreen>(
        builder: (BuildContext context) => const AIScreen(),
      ),
    );
  }

  void _showSystemAlertIfNeeded(AuthProvider auth) {
    if (auth.systemAlertVersion == _lastAlertVersion) {
      return;
    }
    _lastAlertVersion = auth.systemAlertVersion;
    final String? alert = auth.systemAlertMessage;
    if (alert == null || alert.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
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

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
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
            Text(
              'SentinelLink',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 20,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(width: 12),
            Icon(
              auth.selectedChannel?.isPrivate == true
                  ? Icons.lock_outline
                  : Icons.tag,
              size: 20,
              color: AppTheme.primaryOrange,
            ),
            const SizedBox(width: 8),
            Text(
              auth.selectedChannel?.name ?? 'Chat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Exportar chat a XML',
            onPressed: () => _exportChat(context),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Cambiar tema',
            onPressed: () => context.read<ThemeController>().toggle(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'Asistente IA',
            onPressed: () => _openAssistant(context),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          IconButton(
            tooltip: 'Monitor del Sistema',
            onPressed: () => _openMonitor(context),
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    Text(
                      auth.role!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => _handleLogout(context),
            child: const Text('Salir'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: wideLayout
          ? null
          : Drawer(
              child: _Sidebar(
                auth: auth,
                onOpenMonitor: () => _openMonitor(context),
                onOpenAssistant: () => _openAssistant(context),
              ),
            ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget chatArea = _ChatPanel(
            auth: auth,
            messageController: _messageController,
            scrollController: _scrollController,
            onSend: () => _sendMessage(context),
          );

          if (wideLayout) {
            return Row(
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                    child: _Sidebar(
                      auth: auth,
                      onOpenMonitor: () => _openMonitor(context),
                      onOpenAssistant: () => _openAssistant(context),
                    ),
                  ),
                ),
                Expanded(child: chatArea),
              ],
            );
          }

          return chatArea;
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.auth,
    required this.onOpenMonitor,
    required this.onOpenAssistant,
  });

  final AuthProvider auth;
  final VoidCallback onOpenMonitor;
  final VoidCallback onOpenAssistant;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          _SidebarSection(
            icon: Icons.monitor_heart_outlined,
            title: 'Monitor del Sistema',
            subtitle: 'CPU, RAM, Disco',
            onTap: onOpenMonitor,
          ),
          const SizedBox(height: 8),
          _SidebarSection(
            icon: Icons.smart_toy_outlined,
            title: 'Asistente IA',
            subtitle: 'Chat con inteligencia',
            onTap: onOpenAssistant,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'CANALES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (auth.channels.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Text(
                'No hay canales',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...auth.channels.map(
              (ChatChannel channel) => _SidebarChannel(
                channel: channel,
                isSelected: auth.selectedChannelId == channel.id,
                onTap: () =>
                    context.read<AuthProvider>().selectChannel(channel.id),
              ),
            ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'USUARIOS ONLINE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (auth.onlineUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Text(
                'Nadie conectado',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ...auth.onlineUsers.map(
              (String user) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: AppTheme.primaryOrange),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SidebarChannel extends StatelessWidget {
  const _SidebarChannel({
    required this.channel,
    required this.isSelected,
    required this.onTap,
  });

  final ChatChannel channel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  channel.isPrivate ? Icons.lock_outline : Icons.tag,
                  size: 18,
                  color: isSelected
                      ? AppTheme.primaryOrange
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    channel.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? AppTheme.primaryOrange
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.auth,
    required this.messageController,
    required this.scrollController,
    required this.onSend,
  });

  final AuthProvider auth;
  final TextEditingController messageController;
  final ScrollController scrollController;
  final VoidCallback onSend;

  String _formatTime(DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
                                  : Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
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
                                              ? AppTheme
                                                  .primaryOrangeForeground
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
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
                                Text(
                                  message.content,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    color: isMine
                                        ? AppTheme.primaryOrangeForeground
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                ),
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
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
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
                    onSubmitted: auth.selectedChannelId != null
                        ? (_) => onSend()
                        : null,
                    decoration: InputDecoration(
                      hintText: auth.selectedChannel == null
                          ? 'Selecciona un canal'
                          : 'Mensaje en ${auth.selectedChannel!.name}',
                      prefixIcon: const Icon(Icons.message_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed:
                      auth.selectedChannelId == null ? null : onSend,
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
