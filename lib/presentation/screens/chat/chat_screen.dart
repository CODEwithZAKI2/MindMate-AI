import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../../domain/entities/chat_session.dart';
import '../../../domain/services/cloud_functions_service.dart';

// Provider for Cloud Functions Service
final cloudFunctionsServiceProvider = Provider<CloudFunctionsService>((ref) {
  return CloudFunctionsService();
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showScrollToBottom = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isProcessingQueue = false;

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

  /// Setup connectivity listener for auto-retry when back online
  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final wasOffline = !_isOnline;
      final isNowOnline = !results.contains(ConnectivityResult.none);

      print(
        '[ChatScreen] Connectivity changed: $results, isNowOnline: $isNowOnline',
      );

      if (mounted) {
        setState(() {
          _isOnline = isNowOnline;
        });
      }

      // If we just came back online, process pending messages
      if (wasOffline && isNowOnline) {
        print('[ChatScreen] Back online - processing pending messages');
        _processPendingMessages();
      }
    });

    // Check initial connectivity
    Connectivity().checkConnectivity().then((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      print('[ChatScreen] Initial connectivity: $results, isOnline: $isOnline');
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });
  }

  /// Process all pending messages in queue
  Future<void> _processPendingMessages() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    final pendingMessages = ref.read(pendingMessagesProvider);
    final sessionId = ref.read(currentSessionIdProvider);

    for (final pending in pendingMessages) {
      if (pending.sessionId == sessionId && !pending.isSending) {
        await _sendPendingMessage(pending);
        // Small delay between messages
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    _isProcessingQueue = false;
  }

  /// Send a pending message
  Future<void> _sendPendingMessage(PendingMessage pending) async {
    ref.read(pendingMessagesProvider.notifier).markAsSending(pending.id);

    try {
      final sessionAsync = ref.read(
        chatSessionStreamProvider(pending.sessionId),
      );
      final conversationHistory = sessionAsync.value?.messages ?? [];

      final cloudFunctions = ref.read(cloudFunctionsServiceProvider);
      final aiResult = await cloudFunctions.sendChatMessage(
        userId: pending.userId,
        sessionId: pending.sessionId,
        message: pending.content,
        conversationHistory: conversationHistory,
      );

      // Success - remove from pending
      ref
          .read(pendingMessagesProvider.notifier)
          .removePendingMessage(pending.id);

      // Show crisis warning if detected
      if (aiResult.isCrisis && mounted) {
        // Crisis is handled by the banner in the message bubble
      }
    } catch (e) {
      print('[ChatScreen] Failed to send pending message: $e');
      ref.read(pendingMessagesProvider.notifier).markAsNotSending(pending.id);
    }
  }

  void _onScroll() {
    // In reversed ListView, position 0 is bottom (latest messages)
    // Show button when scrolled UP (offset > 200 means we're away from bottom)
    final showButton =
        _scrollController.hasClients && _scrollController.offset > 200;
    if (showButton != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = showButton;
      });
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!mounted || !_scrollController.hasClients) return;

    // In reversed ListView, position 0 is the bottom (latest messages)
    if (animate) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  Future<void> _initializeChat() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Check if there's an active session
    final currentSessionId = ref.read(currentSessionIdProvider);
    if (currentSessionId == null) {
      // Delay to avoid modifying provider during build
      await Future.microtask(() async {
        // Create a new session
        final newSession = ChatSession(
          id: '', // Will be generated by Firestore
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
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error creating chat session: $e')),
            );
          }
        }
      });
    }
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

    // Clear input immediately
    _messageController.clear();

    // Generate a unique ID for tracking this message
    final messageId = const Uuid().v4();

    await _sendMessageInternal(
      messageId: messageId,
      text: text,
      userId: userId,
      sessionId: sessionId,
    );
  }

  /// Internal method to send a message (WhatsApp-style: always show message, queue if offline)
  Future<void> _sendMessageInternal({
    required String messageId,
    required String text,
    required String userId,
    required String sessionId,
    bool isRetry = false,
  }) async {
    // Create user message
    final userMessage = ChatMessage(
      id: messageId,
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
      sendStatus: MessageSendStatus.sending,
    );

    // Save user message to Firestore for instant display
    if (!isRetry) {
      try {
        await ref
            .read(chatRepositoryProvider)
            .addMessageToSession(sessionId: sessionId, message: userMessage);
      } catch (e) {
        print('Error saving user message: $e');
      }
    }

    // If offline, add to pending queue (clock icon) and return
    if (!_isOnline) {
      ref
          .read(pendingMessagesProvider.notifier)
          .addPendingMessage(
            PendingMessage(
              id: messageId,
              content: text,
              timestamp: DateTime.now(),
              sessionId: sessionId,
              userId: userId,
            ),
          );
      return;
    }

    // Online - send directly (no pending queue, shows checkmark immediately)
    ref.read(chatLoadingProvider.notifier).state = true;

    try {
      // Use current session messages for context
      final sessionAsync = ref.read(chatSessionStreamProvider(sessionId));
      final conversationHistory = sessionAsync.value?.messages ?? [];

      // Call Cloud Function to get AI response
      final cloudFunctions = ref.read(cloudFunctionsServiceProvider);
      await cloudFunctions.sendChatMessage(
        userId: userId,
        sessionId: sessionId,
        message: text,
        conversationHistory: conversationHistory,
      );

      // Success - message sent, checkmark shows automatically
    } catch (e) {
      // Add to pending queue for retry (shows clock icon)
      ref
          .read(pendingMessagesProvider.notifier)
          .addPendingMessage(
            PendingMessage(
              id: messageId,
              content: text,
              timestamp: DateTime.now(),
              sessionId: sessionId,
              userId: userId,
            ),
          );
    } finally {
      ref.read(chatLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _endSession() async {
    final sessionId = ref.read(currentSessionIdProvider);
    if (sessionId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('End Conversation'),
            content: const Text(
              'Are you sure you want to end this conversation?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('End'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(chatNotifierProvider.notifier)
            .endChatSession(sessionId: sessionId);
        ref.read(currentSessionIdProvider.notifier).state = null;
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error ending session: $e')));
        }
      }
    }
  }

  /// Start a new chat session (UI action)
  Future<void> _startNewSession() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating chat: $e')),
        );
      }
    }
  }

  /// Build the chat history drawer (UI only)
  Widget _buildHistoryDrawer(BuildContext context, ThemeData theme) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Drawer(child: Center(child: Text('Please sign in')));
    }

    final sessionsAsync = ref.watch(chatSessionsStreamProvider(userId));

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Chat History',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startNewSession();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Chat'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // Sessions List
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

  /// Build sessions list grouped by date
  Widget _buildSessionsList(ThemeData theme, List<ChatSession> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No conversations yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
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

  /// Group sessions by date
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
      } else {
        label = DateFormat('MMMM yyyy').format(sessionDate);
      }

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(session);
    }

    return grouped;
  }

  /// Build session tile
  Widget _buildSessionTile(ThemeData theme, ChatSession session) {
    final currentSessionId = ref.watch(currentSessionIdProvider);
    final isSelected = session.id == currentSessionId;
    final displayTime = session.lastMessageAt ?? session.startedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: () {
          ref.read(currentSessionIdProvider.notifier).state = session.id;
          Navigator.pop(context);
        },
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
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        title: Text(
          session.summary ?? 'New Conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          DateFormat('h:mm a').format(displayTime),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionId = ref.watch(currentSessionIdProvider);
    final isLoading = ref.watch(chatLoadingProvider);
    final pendingMessages = ref.watch(pendingMessagesProvider);

    if (sessionId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sessionAsync = ref.watch(chatSessionStreamProvider(sessionId));

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildHistoryDrawer(context, theme),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('MindMate AI Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => _startNewSession(),
            tooltip: 'New Chat',
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _endSession,
            tooltip: 'End Conversation',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // WhatsApp-style connectivity banner - only show when offline
              if (!_isOnline)
                _ConnectivityBanner(
                  isOnline: _isOnline,
                  pendingCount: pendingMessages.length,
                ),
              // Messages list
              Expanded(
                child: sessionAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, stack) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text('Error: $error'),
                          ],
                        ),
                      ),
                  data: (session) {
                    final messages = session.messages;

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start a conversation',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 48.0),
                              child: Text(
                                'Share what\'s on your mind. I\'m here to listen and support you.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final totalItems = messages.length + (isLoading ? 1 : 0);

                    // For few messages, use Column at top
                    if (totalItems <= 5) {
                      return SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...messages.map(
                              (message) => _MessageBubble(message: message),
                            ),
                            if (isLoading) _TypingIndicatorBubble(),
                          ],
                        ),
                      );
                    }

                    // Many messages - use reversed ListView (latest at bottom)
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: totalItems,
                      itemBuilder: (context, index) {
                        // In reversed list: index 0 is at visual bottom
                        if (isLoading && index == 0) {
                          return _TypingIndicatorBubble();
                        }
                        final messageIndex = isLoading ? index - 1 : index;
                        final actualIndex = messages.length - 1 - messageIndex;
                        if (actualIndex < 0 || actualIndex >= messages.length) {
                          return const SizedBox();
                        }
                        return _MessageBubble(message: messages[actualIndex]);
                      },
                    );
                  },
                ),
              ),

              // Enhanced message input with pill-shape
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts...',
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                              width: 2.5,
                            ),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        onPressed: isLoading ? null : _sendMessage,
                        mini: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: const Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Scroll to bottom button
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 80,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  Icons.arrow_downward_rounded,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// WhatsApp-style connectivity banner
class _ConnectivityBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;

  const _ConnectivityBanner({
    required this.isOnline,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    // Only show when offline
    if (isOnline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4A574).withOpacity(0.15),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFF4A574).withOpacity(0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: const Color(0xFFF4A574),
          ),
          const SizedBox(width: 10),
          Text(
            pendingCount > 0
                ? 'No internet · $pendingCount message${pendingCount > 1 ? 's' : ''} pending'
                : 'No internet connection',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFFC86A48),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  /// Check if the AI response contains crisis resources
  bool _containsCrisisResources(String content) {
    final lowerContent = content.toLowerCase();
    final crisisIndicators = [
      'crisis',
      'suicide prevention',
      'hotline',
      'emergency:',
      '988',
      '110',
      '119',
      '911',
      'lifeline',
      'immediate support',
      'reach out to',
      'crisis text line',
      'mental health crisis',
    ];
    return crisisIndicators.any(
      (indicator) => lowerContent.contains(indicator),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    final timeFormat = DateFormat('h:mm a');
    final isCrisisResponse =
        !isUser && _containsCrisisResources(message.content);

    // Check if this message is pending (WhatsApp-style)
    final pendingMessages = ref.watch(pendingMessagesProvider);
    final isPending = isUser && pendingMessages.any((m) => m.id == message.id);
    final pendingMsg =
        isPending
            ? pendingMessages.firstWhere((m) => m.id == message.id)
            : null;
    final isSending = pendingMsg?.isSending ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondary,
                        theme.colorScheme.secondary.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Icon(
                      Icons.psychology_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              isUser
                                  ? LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.primary.withOpacity(0.85),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : null,
                          color: isUser ? null : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 6),
                            bottomRight: Radius.circular(isUser ? 6 : 20),
                          ),
                          border: isUser ? null : Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isUser
                                  ? theme.colorScheme.primary.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isUser)
                              SelectableText(
                                message.content,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              )
                            else
                              MarkdownBody(
                                data: message.content,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: theme.textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[900],
                                    height: 1.4,
                                  ),
                                  listBullet: theme.textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey[900]),
                                ),
                              ),
                            if (message.safetyFlagged) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Crisis keywords detected',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeFormat.format(message.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          // WhatsApp-style status icons for user messages
                          if (isUser) ...[
                            const SizedBox(width: 4),
                            if (isPending && isSending)
                              // Sending animation
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation(
                                    theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.6),
                                  ),
                                ),
                              )
                            else if (isPending)
                              // Clock icon for pending
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.6),
                              )
                            else
                              // Single check for sent
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: Icon(
                    Icons.person_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
          // Crisis warning banner for AI responses with crisis resources
          if (isCrisisResponse) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 48),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.health_and_safety_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help is Available',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'You are not alone. Please reach out to the resources above if you need support.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Animated typing indicator widget
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (math.sin(value * math.pi) * 0.6 + 0.4);
            final scale = (math.sin(value * math.pi) * 0.3 + 0.7);

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// Typing indicator as a message bubble
class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondary,
                  theme.colorScheme.secondary.withOpacity(0.7),
                ],
              ),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _TypingIndicator(),
          ),
        ],
      ),
    );
  }
}
