import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_channel.dart';
import '../models/chat_message.dart';
import '../services/auth_provider.dart';
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

    await context.read<AuthProvider>().sendMessage(content);
    _messageController.clear();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alert),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    _showSystemAlertIfNeeded(auth);
    final bool wideLayout = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text('SentinelLink - ${auth.selectedChannel?.name ?? 'Chat'}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Asistente IA',
            onPressed: () => _openAssistant(context),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          IconButton(
            tooltip: 'Monitor',
            onPressed: () => _openMonitor(context),
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                auth.username == null ? 'Invitado' : '${auth.username} · ${auth.role ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<LoginScreen>(
                  builder: (BuildContext context) => const LoginScreen(),
                ),
              );
            },
            child: const Text('Salir'),
          ),
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
                  child: _Sidebar(
                    auth: auth,
                    onOpenMonitor: () => _openMonitor(context),
                    onOpenAssistant: () => _openAssistant(context),
                  ),
                ),
                const VerticalDivider(width: 1),
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
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Monitor del sistema'),
              subtitle: const Text('CPU, RAM, Disco y alertas'),
              onTap: onOpenMonitor,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Asistente IA'),
              subtitle: const Text('Chat con IA integrado'),
              onTap: onOpenAssistant,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Canales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (auth.channels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No hay canales disponibles'),
            )
          else
            ...auth.channels.map(
              (ChatChannel channel) => Card(
                child: ListTile(
                  selected: auth.selectedChannelId == channel.id,
                  leading: Icon(channel.isPrivate ? Icons.lock_outline : Icons.tag),
                  title: Text(channel.name),
                  subtitle: Text(channel.isPrivate ? 'Canal privado' : 'Canal publico'),
                  onTap: () => context.read<AuthProvider>().selectChannel(channel.id),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text('Usuarios online', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (auth.onlineUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nadie conectado todavia'),
            )
          else
            ...auth.onlineUsers.map(
              (String user) => ListTile(
                dense: true,
                leading: const Icon(Icons.circle, size: 10, color: Colors.green),
                title: Text(user),
              ),
            ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final List<ChatMessage> messages = auth.selectedMessages;

    return Column(
      children: <Widget>[
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      auth.selectedChannel == null
                          ? 'Selecciona un canal para empezar'
                          : 'No hay mensajes aun en ${auth.selectedChannel!.name}',
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ChatMessage message = messages[index];
                      final bool isMine = message.sender == auth.username;

                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: const BoxConstraints(maxWidth: 640),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Text(
                                    message.sender,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    message.channelName,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatTime(message.timestamp),
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(message.content),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: auth.selectedChannel == null
                          ? 'Selecciona un canal'
                          : 'Escribe un mensaje en ${auth.selectedChannel!.name}',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: auth.selectedChannelId == null ? null : onSend,
                  child: const Text('Enviar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime timestamp) {
    final DateTime local = timestamp.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
