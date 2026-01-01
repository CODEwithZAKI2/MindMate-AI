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

  // Premium colors
  static const _primaryGradient = [Color(0xFF667EEA), Color(0xFF764BA2)];
  static const _moodColors = [
    Color(0xFFE879F9),
    Color(0xFFFB923C),
    Color(0xFF60A5FA),
    Color(0xFF34D399),
    Color(0xFF818CF8),
  ];

  final List<String> _availableTags = [
    'Gratitude',
    'Reflection',
    'Goals',
    'Dreams',
    'Growth',
    'Peace',
    'Family',
    'Work',
    'Health',
    'Love',
    'Mindful',
    'Joy',
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _loadEntry() async {
    if (widget.entryId == null) return;
    setState(() => _isLoading = true);
    try {
      final entry = await ref
          .read(journalNotifierProvider.notifier)
          .getEntry(widget.entryId!);
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _saveEntry() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      _showSnackBar('Please add a title or content', isError: true);
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(journalNotifierProvider.notifier);
      final now = DateTime.now();

      if (_existingEntry != null) {
        await notifier.updateEntry(
          _existingEntry!.copyWith(
            title: title.isEmpty ? 'Untitled' : title,
            content: content,
            moodScore: _selectedMood,
            tags: _selectedTags,
            updatedAt: now,
            isFavorite: _isFavorite,
          ),
        );
      } else {
        await notifier.createEntry(
          JournalEntry(
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
          ),
        );
      }
      if (mounted) {
        _showSnackBar(
          _existingEntry != null ? 'Entry updated ✨' : 'Entry saved ✨',
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : _primaryGradient[0],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _deleteEntry() async {
    if (_existingEntry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Delete Entry?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: const Text('This reflection will be gone forever.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep it'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
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
        _showSnackBar('Entry deleted');
        context.pop();
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showAIPrompts() {
    final prompts = ref.read(aiJournalPromptsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: _primaryGradient),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Writing Prompts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: prompts.length,
                    itemBuilder:
                        (_, i) => GestureDetector(
                          onTap: () {
                            setState(() {
                              _promptText = prompts[i];
                              _titleController.text = prompts[i];
                            });
                            Navigator.pop(context);
                            _contentFocus.requestFocus();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: _primaryGradient[0],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    prompts[i],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: _primaryGradient[0],
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entryId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _handleBack,
        ),
        title: Text(
          isEditing ? 'Edit Entry' : 'New Entry',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color:
                  _isFavorite ? Colors.red.shade400 : const Color(0xFF94A3B8),
            ),
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          if (!isEditing)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _primaryGradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _showAIPrompts,
              ),
            ),
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
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI prompt badge
                    if (_promptText != null) _buildPromptBadge(),

                    // TITLE FIELD - Premium styled container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryGradient[0].withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: _primaryGradient[0].withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Title your reflection...',
                          hintStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF94A3B8).withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _contentFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CONTENT FIELD - Premium styled container
                    Container(
                      constraints: const BoxConstraints(minHeight: 200),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _contentController,
                        focusNode: _contentFocus,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF475569),
                          height: 1.7,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Let your thoughts flow freely...',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            color: const Color(0xFF94A3B8).withOpacity(0.6),
                            height: 1.7,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                        maxLines: null,
                        minLines: 8,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Mood section
                    _buildSectionHeader(
                      'How are you feeling?',
                      Icons.favorite_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildMoodSelector(),
                    const SizedBox(height: 28),

                    // Tags section
                    _buildSectionHeader('Add tags', Icons.tag_rounded),
                    const SizedBox(height: 16),
                    _buildTagsSelector(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  void _handleBack() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Discard changes?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Keep editing'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
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
  }

  Widget _buildPromptBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryGradient[0].withOpacity(0.1),
            _primaryGradient[1].withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _primaryGradient),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 12,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Writing from AI prompt',
            style: TextStyle(
              color: _primaryGradient[0],
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        ShaderMask(
          shaderCallback:
              (b) => LinearGradient(colors: _primaryGradient).createShader(b),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodSelector() {
    return Row(
      children: List.generate(5, (i) {
        final score = i + 1;
        final isSelected = _selectedMood == score;
        final color = _moodColors[i];

        return Expanded(
          child: GestureDetector(
            onTap:
                () => setState(() {
                  _selectedMood = isSelected ? null : score;
                  _hasChanges = true;
                }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < 4 ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient:
                    isSelected
                        ? LinearGradient(
                          colors: [color, color.withOpacity(0.85)],
                        )
                        : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color:
                      isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isSelected
                            ? color.withOpacity(0.35)
                            : Colors.black.withOpacity(0.03),
                    blurRadius: isSelected ? 14 : 8,
                    offset: Offset(0, isSelected ? 6 : 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _getMoodIcon(score),
                    size: 28,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getMoodLabel(score),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color:
                          isSelected ? Colors.white : const Color(0xFF64748B),
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

  Widget _buildTagsSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _availableTags.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap:
                  () => setState(() {
                    isSelected
                        ? _selectedTags.remove(tag)
                        : _selectedTags.add(tag);
                    _hasChanges = true;
                  }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient:
                      isSelected
                          ? LinearGradient(colors: _primaryGradient)
                          : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isSelected
                            ? Colors.transparent
                            : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isSelected
                              ? _primaryGradient[0].withOpacity(0.3)
                              : Colors.black.withOpacity(0.03),
                      blurRadius: isSelected ? 12 : 6,
                      offset: Offset(0, isSelected ? 4 : 2),
                    ),
                  ],
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: _isLoading ? null : _saveEntry,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _primaryGradient),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _primaryGradient[0].withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.entryId != null
                                ? 'Save Changes'
                                : 'Save Entry',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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

  IconData _getMoodIcon(int s) {
    switch (s) {
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

  String _getMoodLabel(int s) {
    switch (s) {
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
