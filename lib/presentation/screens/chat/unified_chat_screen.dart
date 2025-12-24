import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../../domain/entities/chat_session.dart';
import '../../../domain/services/cloud_functions_service.dart';
import '../../widgets/custom_illustrations.dart';

// Provider for Cloud Functions Service
final _cloudFunctionsServiceProvider = Provider<CloudFunctionsService>((ref) {
  return CloudFunctionsService();
});

/// Unified Chat Screen with ChatGPT-style drawer sidebar
class UnifiedChatScreen extends ConsumerStatefulWidget {
  const UnifiedChatScreen({super.key});

  @override
  ConsumerState<UnifiedChatScreen> createState() => _UnifiedChatScreenState();
}

class _UnifiedChatScreenState extends ConsumerState<UnifiedChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showScrollToBottom = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isTyping = false;
  List<ChatMessage> _localMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _scrollController.addListener(_onScroll);
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      final isNowOnline = !results.contains(ConnectivityResult.none);
      if (mounted) {
        setState(() => _isOnline = isNowOnline);
      }
      if (wasOffline && isNowOnline) {
        _processPendingMessages();
      }
    });

    Connectivity().checkConnectivity().then((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
  }

  Future<void> _processPendingMessages() async {
    final pendingMessages = ref.read(pendingMessagesProvider);
    final sessionId = ref.read(currentSessionIdProvider);
    if (sessionId == null || pendingMessages.isEmpty) return;

    for (final pending in pendingMessages) {
      if (pending.sessionId == sessionId) {
        await _sendPendingMessage(pending);
      }
    }
  }

  Future<void> _sendPendingMessage(PendingMessage pending) async {
    final cloudFunctions = ref.read(_cloudFunctionsServiceProvider);
    try {
      final result = await cloudFunctions.sendChatMessage(
        sessionId: pending.sessionId,
        userId: pending.userId,
        message: pending.content,
        conversationHistory: _localMessages,
      );

      if (mounted) {
        ref.read(pendingMessagesProvider.notifier).removePendingMessage(pending.id);
        _updateMessageStatus(pending.id, MessageSendStatus.sent);
        _addAssistantMessage(result.response);
      }
    } catch (e) {
      // Keep in pending queue for retry
    }
  }

  void _updateMessageStatus(String messageId, MessageSendStatus status) {
    setState(() {
      final index = _localMessages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _localMessages[index] = _localMessages[index].copyWith(sendStatus: status);
      }
    });
  }

  void _addAssistantMessage(String content) {
    setState(() {
      _localMessages.add(ChatMessage(
        id: const Uuid().v4(),
        role: 'assistant',
        content: content,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _onScroll() {
    final showButton = _scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200;
    if (showButton != _showScrollToBottom) {
      setState(() => _showScrollToBottom = showButton);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    }
  }

  Future<void> _initializeChat() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) {
      await _startNewSession(userId);
    }
  }

  Future<void> _startNewSession(String userId) async {
    final newSession = ChatSession(
      id: '',
      userId: userId,
      startedAt: DateTime.now(),
      messageCount: 0,
      messages: const [],
    );

    try {
      final sessionId = await ref
          .read(chatNotifierProvider.notifier)
          .createChatSession(newSession);
      ref.read(currentSessionIdProvider.notifier).state = sessionId;
      setState(() => _localMessages = []);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating session: $e')),
        );
      }
    }
  }

  void _startNewChat() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    _startNewSession(userId);
    Navigator.of(context).pop();
  }

  void _selectSession(ChatSession session) {
    ref.read(currentSessionIdProvider.notifier).state = session.id;
    setState(() => _localMessages = List.from(session.messages));
    Navigator.of(context).pop();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    final sessionId = ref.read(currentSessionIdProvider);

    if (userId == null || sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session not ready. Please try again.')),
      );
      return;
    }

    _messageController.clear();
    final messageId = const Uuid().v4();

    // Add user message immediately
    final userMessage = ChatMessage(
      id: messageId,
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
      sendStatus: _isOnline ? MessageSendStatus.sending : MessageSendStatus.sending,
    );

    setState(() => _localMessages.add(userMessage));
    _scrollToBottom();

    if (!_isOnline) {
      ref.read(pendingMessagesProvider.notifier).addPendingMessage(
        PendingMessage(
          id: messageId,
          content: text,
          timestamp: DateTime.now(),
          userId: userId,
          sessionId: sessionId,
        ),
      );
      return;
    }

    // Send message
    setState(() => _isTyping = true);
    try {
      final cloudFunctions = ref.read(_cloudFunctionsServiceProvider);
      final result = await cloudFunctions.sendChatMessage(
        sessionId: sessionId,
        userId: userId,
        message: text,
        conversationHistory: _localMessages,
      );

      if (mounted) {
        _updateMessageStatus(messageId, MessageSendStatus.sent);
        _addAssistantMessage(result.response);
      }
    } catch (e) {
      if (mounted) {
        _updateMessageStatus(messageId, MessageSendStatus.failed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Text('Please sign in to chat', style: theme.textTheme.bodyLarge),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.colorScheme.surface,
      drawer: _buildHistoryDrawer(theme, userId),
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          if (!_isOnline) _buildOfflineBanner(theme),
          Expanded(
            child: _localMessages.isEmpty
                ? _buildEmptyState(theme)
                : _buildMessagesList(theme),
          ),
          _buildInputArea(theme),
        ],
      ),
      floatingActionButton: _showScrollToBottom
          ? FloatingActionButton.small(
              onPressed: () => _scrollToBottom(),
              child: const Icon(Icons.keyboard_arrow_down),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.menu_rounded, color: theme.colorScheme.primary, size: 22),
        ),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('MindMate AI', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () {
              final userId = ref.read(currentUserIdProvider);
              if (userId != null) _startNewSession(userId);
            },
            tooltip: 'New Chat',
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryDrawer(ThemeData theme, String userId) {
    final sessionsAsync = ref.watch(chatSessionsStreamProvider(userId));

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Text('Chat History', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: _startNewChat,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Chat'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) => _buildSessionsList(theme, sessions),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList(ThemeData theme, List<ChatSession> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: theme.colorScheme.primary.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text('No conversations yet', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
            ],
          ),
        ),
      );
    }

    final grouped = _groupSessionsByDate(sessions);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Text(
                entry.key,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...entry.value.map((session) => _buildSessionTile(theme, session)),
          ],
        );
      }).toList(),
    );
  }

  Map<String, List<ChatSession>> _groupSessionsByDate(List<ChatSession> sessions) {
    final Map<String, List<ChatSession>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final session in sessions) {
      final sessionDate = session.lastMessageAt ?? session.startedAt;
      final dateOnly = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

      String label;
      if (dateOnly == today) {
        label = 'Today';
      } else if (dateOnly == yesterday) {
        label = 'Yesterday';
      } else if (now.difference(dateOnly).inDays < 7) {
        label = 'This Week';
      } else if (now.difference(dateOnly).inDays < 30) {
        label = 'This Month';
      } else {
        label = DateFormat('MMMM yyyy').format(sessionDate);
      }

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(session);
    }

    return grouped;
  }

  Widget _buildSessionTile(ThemeData theme, ChatSession session) {
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final isSelected = session.id == currentSessionId;
    final displayTime = session.lastMessageAt ?? session.startedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: () => _selectSession(session),
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.2)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 18,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        title: Text(
          session.summary ?? 'New Conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
        ),
        subtitle: Text(
          DateFormat('h:mm a').format(displayTime),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error.withOpacity(0.7)),
          onPressed: () => ref.read(chatNotifierProvider.notifier).deleteChatSession(session.id),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: theme.colorScheme.errorContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            'You\'re offline. Messages will be sent when connected.',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ChatPlantIllustration(size: 180),
            const SizedBox(height: 32),
            Text(
              'Start a Conversation',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'I\'m here to listen and support you.\nShare what\'s on your mind.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _localMessages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _localMessages.length && _isTyping) {
          return _buildTypingIndicator(theme);
        }
        return _buildMessageBubble(theme, _localMessages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ThemeData theme, ChatMessage message) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12, left: isUser ? 60 : 0, right: isUser ? 0 : 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: (isUser ? theme.colorScheme.primary : theme.colorScheme.shadow).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(message.content, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.4))
            else
              MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet(p: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, height: 1.5)),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isUser ? Colors.white.withOpacity(0.7) : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.sendStatus == MessageSendStatus.sent
                        ? Icons.done_all_rounded
                        : message.sendStatus == MessageSendStatus.sending
                            ? Icons.access_time_rounded
                            : Icons.error_outline_rounded,
                    size: 14,
                    color: message.sendStatus == MessageSendStatus.failed
                        ? theme.colorScheme.error
                        : Colors.white.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 400 + (index * 150)),
              builder: (context, value, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.3 + (value * 0.5)),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(color: theme.colorScheme.shadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
