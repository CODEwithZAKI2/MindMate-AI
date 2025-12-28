import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';

class JournalEntryScreen extends ConsumerStatefulWidget {
  final String? entryId;

  const JournalEntryScreen({super.key, this.entryId});

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();

  int? _selectedMood;
  List<String> _selectedTags = [];
  bool _isFavorite = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  String? _promptText;
  JournalEntry? _existingEntry;

  final List<String> _availableTags = [
    'Gratitude',
    'Reflection',
    'Goals',
    'Dreams',
    'Anxiety',
    'Joy',
    'Growth',
    'Challenges',
    'Family',
    'Work',
    'Health',
    'Love',
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadEntry() async {
    if (widget.entryId == null) return;

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(journalNotifierProvider.notifier);
      final entry = await notifier.getEntry(widget.entryId!);

      setState(() {
        _existingEntry = entry;
        _titleController.text = entry.title;
        _contentController.text = entry.content;
        _selectedMood = entry.moodScore;
        _selectedTags = List.from(entry.tags);
        _isFavorite = entry.isFavorite;
        _promptText = entry.promptText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading entry: $e')));
      }
    }
  }

  Future<void> _saveEntry() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title or content')),
      );
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(journalNotifierProvider.notifier);
      final now = DateTime.now();

      if (_existingEntry != null) {
        // Update existing
        final updated = _existingEntry!.copyWith(
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
          moodScore: _selectedMood,
          tags: _selectedTags,
          updatedAt: now,
          isFavorite: _isFavorite,
        );
        await notifier.updateEntry(updated);
      } else {
        // Create new
        final entry = JournalEntry(
          id: '',
          userId: userId,
          title: title.isEmpty ? 'Untitled' : title,
          content: content,
          moodScore: _selectedMood,
          tags: _selectedTags,
          createdAt: now,
          updatedAt: now,
          promptText: _promptText,
          isFavorite: _isFavorite,
        );
        await notifier.createEntry(entry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  _existingEntry != null ? 'Entry updated!' : 'Entry saved!',
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  Future<void> _deleteEntry() async {
    if (_existingEntry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Entry?'),
            content: const Text('This action cannot be undone.'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(journalNotifierProvider.notifier)
          .deleteEntry(_existingEntry!.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  void _showAIPrompts() {
    final prompts = ref.read(aiJournalPromptsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'AI Writing Prompts',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: prompts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final prompt = prompts[index];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _promptText = prompt;
                            _titleController.text = prompt;
                          });
                          Navigator.pop(context);
                          _contentFocus.requestFocus();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prompt,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.entryId != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              if (_hasChanges) {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Discard changes?'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Keep editing'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.pop();
                            },
                            child: const Text('Discard'),
                          ),
                        ],
                      ),
                );
              } else {
                context.pop();
              }
            },
          ),
        ),
        title: Text(
          isEditing ? 'Edit Entry' : 'New Entry',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          // Favorite toggle
          IconButton(
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isFavorite ? Colors.red.shade400 : null,
            ),
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          // AI prompts button
          if (!isEditing)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary,
                ),
                onPressed: _showAIPrompts,
                tooltip: 'AI Prompts',
              ),
            ),
          // Delete button (only for existing entries)
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteEntry,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI prompt indicator
                    if (_promptText != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.tertiary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: theme.colorScheme.tertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Writing from AI prompt',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Title field
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _contentFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),

                    // Content field
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocus,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
                      decoration: InputDecoration(
                        hintText: 'Start writing your thoughts...',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      minLines: 10,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 32),

                    // Mood selector
                    _buildSectionTitle(
                      theme,
                      'How are you feeling?',
                      Icons.mood_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildMoodSelector(theme),
                    const SizedBox(height: 24),

                    // Tags
                    _buildSectionTitle(theme, 'Add tags', Icons.label_rounded),
                    const SizedBox(height: 12),
                    _buildTagsSelector(theme),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildSaveButton(theme),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSelector(ThemeData theme) {
    return Row(
      children: List.generate(5, (index) {
        final score = index + 1;
        final isSelected = _selectedMood == score;
        final color = _getMoodColor(score);

        return Expanded(
          child: GestureDetector(
            onTap:
                () => setState(() {
                  _selectedMood = isSelected ? null : score;
                  _hasChanges = true;
                }),
            child: Container(
              margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient:
                    isSelected
                        ? LinearGradient(
                          colors: [color, color.withOpacity(0.8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                        : null,
                color:
                    isSelected
                        ? null
                        : theme.colorScheme.surfaceContainerHighest.withOpacity(
                          0.5,
                        ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isSelected
                          ? color.withOpacity(0.5)
                          : theme.colorScheme.outline.withOpacity(0.1),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : null,
              ),
              child: Column(
                children: [
                  Icon(
                    _getMoodIcon(score),
                    size: 24,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getMoodLabel(score),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTagsSelector(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          _availableTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                  _hasChanges = true;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  tag,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color:
                        isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: _isLoading ? null : _saveEntry,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child:
            _isLoading
                ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      widget.entryId != null ? 'Save Changes' : 'Save Entry',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Color _getMoodColor(int score) {
    switch (score) {
      case 1:
        return const Color(0xFFB5838D);
      case 2:
        return const Color(0xFFE5989B);
      case 3:
        return const Color(0xFFB8C0A9);
      case 4:
        return const Color(0xFF8CB369);
      case 5:
        return const Color(0xFF6A9B7E);
      default:
        return const Color(0xFFB8C0A9);
    }
  }

  IconData _getMoodIcon(int score) {
    switch (score) {
      case 1:
        return Icons.sentiment_very_dissatisfied_rounded;
      case 2:
        return Icons.sentiment_dissatisfied_rounded;
      case 3:
        return Icons.sentiment_neutral_rounded;
      case 4:
        return Icons.sentiment_satisfied_rounded;
      case 5:
        return Icons.sentiment_very_satisfied_rounded;
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }

  String _getMoodLabel(int score) {
    switch (score) {
      case 1:
        return 'Sad';
      case 2:
        return 'Low';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Great';
      default:
        return 'Okay';
    }
  }
}
