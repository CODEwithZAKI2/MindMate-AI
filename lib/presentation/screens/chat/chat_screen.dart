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
      // Don't create session yet - it will be created when user sends first message
      // This prevents empty sessions from cluttering the history
      // Set a placeholder that indicates we need to create session on first message
      await Future.microtask(() {
        ref.read(currentSessionIdProvider.notifier).state = 'pending_new_session';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    var sessionId = ref.read(currentSessionIdProvider);

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send messages.')),
      );
      return;
    }

    // If session is pending, create it now on first message
    if (sessionId == null || sessionId == 'pending_new_session') {
      try {
        final newSession = ChatSession(
          id: '',
          userId: userId,
          startedAt: DateTime.now(),
          messageCount: 0,
          messages: const [],
        );
        sessionId = await ref
            .read(chatNotifierProvider.notifier)
            .createChatSession(newSession);
        ref.read(currentSessionIdProvider.notifier).state = sessionId;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating chat session: $e')),
          );
        }
        return;
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating chat: $e')));
      }
    }
  }

  /// Start voice call - passes current session ID if available
  void _startVoiceCall() {
    final sessionId = ref.read(currentSessionIdProvider);
    // Only pass sessionId if it's a real session (not pending)
    if (sessionId != null && sessionId != 'pending_new_session') {
      context.push('/voice-call', extra: {'sessionId': sessionId});
    } else {
      // No existing session - voice call will create its own
      context.push('/voice-call');
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
    // Filter out empty sessions (sessions with no messages)
    final nonEmptySessions = sessions.where((s) => s.messageCount > 0).toList();
    
    if (nonEmptySessions.isEmpty) {
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

    final grouped = _groupSessionsByDate(nonEmptySessions);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children:
          grouped.entries.map((entry) {
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
                ...entry.value.map(
                  (session) => _buildSessionTile(theme, session),
                ),
              ],
            );
          }).toList(),
    );
  }

  /// Group sessions by date
  Map<String, List<ChatSession>> _groupSessionsByDate(
    List<ChatSession> sessions,
  ) {
    final Map<String, List<ChatSession>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final session in sessions) {
      final sessionDate = session.lastMessageAt ?? session.startedAt;
      final dateOnly = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
      );

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
            color:
                isSelected
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 18,
            color:
                isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        title: Text(
          session.title ?? session.summary ?? 'New Conversation',
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

  /// Build a calming suggestion chip for empty state (UI only)
  Widget _buildSuggestionChip(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build welcome empty state for new chat
  Widget _buildWelcomeEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    theme.colorScheme.secondary.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.psychology_rounded,
                size: 50,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your Safe Space',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Share what's on your mind today. I'm here to listen.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            // Suggestion chips
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('I need to talk', theme),
                _buildSuggestionChip('Help me relax', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the input area widget
  Widget _buildInputArea(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share your thoughts...',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Send button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded),
                  color: theme.colorScheme.onPrimary,
                  iconSize: 24,
                  onPressed: _sendMessage,
                ),
              ),
            ],
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

    // Handle pending new session - show empty chat without loading from Firestore
    if (sessionId == null || sessionId == 'pending_new_session') {
      return Scaffold(
        key: _scaffoldKey,
        drawer: _buildHistoryDrawer(context, theme),
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.psychology_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MindMate AI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Your safe space',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.call_outlined),
              onPressed: _startVoiceCall,
              tooltip: 'Voice Call',
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              onPressed: () => context.push('/journal'),
              tooltip: 'Journal',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _buildWelcomeEmptyState(theme),
            ),
            _buildInputArea(theme),
          ],
        ),
      );
    }

    final sessionAsync = ref.watch(chatSessionStreamProvider(sessionId));

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildHistoryDrawer(context, theme),
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer.withOpacity(0.3),
                theme.colorScheme.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.9),
                    theme.colorScheme.secondary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MindMate AI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Your safe space',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Voice Call Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.call_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              onPressed: _startVoiceCall,
              tooltip: 'Voice Call',
            ),
          ),
          // New Chat Button
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.edit_square,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              onPressed: () => _startNewSession(),
              tooltip: 'New Chat',
            ),
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
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Calming gradient icon container
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primaryContainer
                                          .withOpacity(0.4),
                                      theme.colorScheme.secondaryContainer
                                          .withOpacity(0.3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.08),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.spa_rounded,
                                  size: 56,
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.7,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Welcome to Your Safe Space',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Take a deep breath. Share what\'s on your mind\nwhenever you\'re ready. I\'m here to listen.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Subtle suggestion chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildSuggestionChip(
                                    'How are you feeling?',
                                    theme,
                                  ),
                                  _buildSuggestionChip('I need to talk', theme),
                                  _buildSuggestionChip('Help me relax', theme),
                                ],
                              ),
                            ],
                          ),
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

              // Premium calming message input area
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surface,
                      theme.colorScheme.primaryContainer.withOpacity(0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.08,
                                ),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _messageController,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Share your thoughts...',
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.4),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                              maxLines: 4,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Calming gradient send button
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary.withOpacity(0.9),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.25,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isLoading ? null : _sendMessage,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                // AI Avatar - calming therapeutic design
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondary.withOpacity(0.9),
                        theme.colorScheme.primary.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
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
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient:
                              isUser
                                  ? LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.primary.withOpacity(
                                        0.85,
                                      ),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : LinearGradient(
                                    colors: [
                                      theme.colorScheme.surfaceContainerHighest,
                                      theme.colorScheme.surfaceContainerHighest
                                          .withOpacity(0.9),
                                    ],
                                  ),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(22),
                            topRight: const Radius.circular(22),
                            bottomLeft: Radius.circular(isUser ? 22 : 6),
                            bottomRight: Radius.circular(isUser ? 6 : 22),
                          ),
                          border:
                              isUser
                                  ? null
                                  : Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.06),
                                    width: 1,
                                  ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isUser
                                      ? theme.colorScheme.primary.withOpacity(
                                        0.12,
                                      )
                                      : theme.colorScheme.shadow.withOpacity(
                                        0.04,
                                      ),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
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

// Typing indicator as a message bubble - calming therapeutic design
class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Matching AI avatar with spa icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondary.withOpacity(0.9),
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.secondary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.spa_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          // Calming bubble container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.9),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(22),
              ),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
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
