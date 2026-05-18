import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_message.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(BuildContext context) async {
    final String prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    try {
      await context.read<AuthProvider>().sendAiPrompt(prompt);
      _promptController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.critical,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final List<AiMessage> messages = auth.aiMessages;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: <Widget>[
            Icon(
              Icons.smart_toy_outlined,
              color: AppTheme.primaryOrange,
            ),
            SizedBox(width: 8),
            Text('Asistente IA'),
          ],
        ),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
            tooltip: 'Cambiar tema',
            onPressed: () => context.read<ThemeController>().toggle(),
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Escribe tu primera pregunta',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'El asistente responderá en tiempo real',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      final AiMessage message = messages[index];
                      final bool isUser = message.isUser;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? AppTheme.primaryOrange
                                    : Theme.of(context)
                                        .colorScheme
                                        .surface,
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: isUser
                                    ? null
                                    : Border.all(
                                        color: Theme.of(context)
                                            .dividerColor,
                                      ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(
                                        isUser
                                            ? Icons
                                                .person_outline
                                            : Icons
                                                .smart_toy_outlined,
                                        size: 18,
                                        color: isUser
                                            ? AppTheme
                                                .primaryOrangeForeground
                                            : AppTheme
                                                .primaryOrange,
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Text(
                                        isUser
                                            ? 'Tú'
                                            : 'Asistente IA',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                          color: isUser
                                              ? AppTheme
                                                  .primaryOrangeForeground
                                              : AppTheme
                                                  .primaryOrange,
                                          fontWeight:
                                              FontWeight.w600,
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
                                      color: isUser
                                          ? AppTheme
                                              .primaryOrangeForeground
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
                      controller: _promptController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendPrompt(context),
                      enabled: !auth.isAiLoading,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Pregunta algo...',
                        prefixIcon:
                            const Icon(Icons.question_answer_outlined),
                        suffixIcon: auth.isAiLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryOrange,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: auth.isAiLoading
                        ? null
                        : () => _sendPrompt(context),
                    icon: const Icon(Icons.send),
                    label: const Text('Enviar'),
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
