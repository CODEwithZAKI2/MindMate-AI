import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../data/services/journal_ai_service.dart';
import '../../../data/services/voice_recording_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../widgets/voice_recording_widget.dart';

/// Journal Entry Editor Screen
/// Follows specification: slow and intentional experience, calm interface
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
  bool _isLocked = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  String? _promptText;
  String? _voiceNotePath;
  JournalEntry? _existingEntry;

  // Calming colors
  static const _primaryColor = Color(0xFF6366F1);
  static const _secondaryColor = Color(0xFF8B5CF6);
  static const _surfaceColor = Color(0xFFFAFAFC);

  static const _moodColors = [
    Color(0xFFEF4444), // Sad - Red
    Color(0xFFF97316), // Low - Orange
    Color(0xFFEAB308), // Okay - Yellow
    Color(0xFF22C55E), // Good - Green
    Color(0xFF6366F1), // Great - Indigo
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
      if (mounted) _showSnackBar('Error loading entry', isError: true);
    }
  }

  Future<void> _saveEntry() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty && _voiceNotePath == null) {
      _showSnackBar('Please write something first', isError: true);
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(journalNotifierProvider.notifier);
      final aiService = ref.read(journalAIServiceProvider);
      final now = DateTime.now();
      String? entryId;

      // Upload voice recording to Firebase Storage if exists
      String? voiceDownloadUrl;
      if (_voiceNotePath != null) {
        final voiceService = VoiceRecordingService();
        voiceDownloadUrl = await voiceService.uploadToStorage(
          _voiceNotePath!,
          userId,
        );
        if (voiceDownloadUrl == null) {
          _showSnackBar('Failed to upload voice note', isError: true);
        }
      }

      if (_existingEntry != null) {
        await notifier.updateEntry(
          _existingEntry!.copyWith(
            title: title.isEmpty ? 'Untitled' : title,
            content: content,
            moodScore: _selectedMood,
            tags: _selectedTags,
            updatedAt: now,
            isFavorite: _isFavorite,
            isLocked: _isLocked,
            hasVoiceRecording: voiceDownloadUrl != null,
            voiceFilePath: voiceDownloadUrl,
          ),
        );
        entryId = _existingEntry!.id;
      } else {
        entryId = await notifier.createEntry(
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
            isLocked: _isLocked,
            hasVoiceRecording: voiceDownloadUrl != null,
            voiceFilePath: voiceDownloadUrl,
          ),
        );
      }

      // Generate AI reflection (only for new entries with sufficient content)
      if (_existingEntry == null && content.length >= 50) {
        final result = await aiService.generateReflection(
          entryId: entryId,
          content: content,
          userId: userId,
        );

        if (mounted) {
          setState(() => _isLoading = false);
          if (result.isCrisis) {
            await _showCrisisDialog(result.crisisResponse ?? '');
          } else if (result.hasReflection) {
            await _showReflectionDialog(
              result.toneSummary!,
              result.reflectionQuestions!,
            );
          }
          context.pop();
        }
      } else {
        if (mounted) {
          _showSnackBar(
            _existingEntry != null ? 'Entry updated ✨' : 'Entry saved ✨',
          );
          context.pop();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to save', isError: true);
    }
  }

  Future<void> _showReflectionDialog(
    String toneSummary,
    List<String> questions,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, _primaryColor.withOpacity(0.03)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI Reflection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      toneSummary,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...questions.map(
                    (q) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 18,
                            color: _primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _showCrisisDialog(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite, color: Colors.red.shade400, size: 28),
            ),
            title: const Text(
              'We\'re Here For You',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('I Understand'),
                ),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade400 : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete this entry?'),
            content: const Text('You can recover it within 30 days.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                ),
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
      _showSnackBar('Failed to delete', isError: true);
    }
  }

  void _showPromptsSheet() {
    final prompts = ref.read(aiJournalPromptsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildPromptsSheet(prompts),
    );
  }

  Widget _buildPromptsSheet(List<Map<String, dynamic>> prompts) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Writing Prompts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      'Choose one to inspire you',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: prompts.length,
              itemBuilder: (_, i) {
                final prompt = prompts[i];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _promptText = prompt['prompt'];
                      _titleController.text = prompt['prompt'];
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
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.lightbulb_outline_rounded,
                            color: _primaryColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            prompt['prompt'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entryId != null;
    final tags = ref.watch(availableTagsProvider);

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: _buildAppBar(isEditing),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_promptText != null) _buildPromptBadge(),
                    _buildTitleField(),
                    _buildContentField(),
                    const SizedBox(height: 20),
                    _buildVoiceRecordingSection(),
                    const SizedBox(height: 32),
                    _buildMoodSection(),
                    const SizedBox(height: 28),
                    _buildTagsSection(tags),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isEditing) {
    return AppBar(
      backgroundColor: _surfaceColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: _handleBack,
      ),
      title: Text(
        isEditing ? 'Edit Entry' : 'New Entry',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 17,
          color: Colors.grey.shade800,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            _isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: _isFavorite ? Colors.red.shade400 : Colors.grey.shade400,
          ),
          onPressed: () => setState(() => _isFavorite = !_isFavorite),
        ),
        IconButton(
          icon: Icon(
            _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: _isLocked ? _primaryColor : Colors.grey.shade400,
          ),
          onPressed:
              () => setState(() {
                _isLocked = !_isLocked;
                _hasChanges = true;
              }),
          tooltip: _isLocked ? 'Entry locked' : 'Lock this entry',
        ),
        if (!isEditing)
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
              onPressed: _showPromptsSheet,
            ),
          ),
        if (isEditing)
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.grey.shade500,
            ),
            onPressed: _deleteEntry,
          ),
      ],
    );
  }

  void _handleBack() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Discard changes?'),
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
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withOpacity(0.1),
            _secondaryColor.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: _primaryColor),
          const SizedBox(width: 6),
          Text(
            'AI Prompt',
            style: TextStyle(
              color: _primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocus,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade900,
          height: 1.3,
        ),
        decoration: InputDecoration(
          hintText: 'Title your reflection...',
          hintStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade300,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _contentFocus.requestFocus(),
      ),
    );
  }

  Widget _buildContentField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocus,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade700,
          height: 1.8,
        ),
        decoration: InputDecoration(
          hintText:
              'Let your thoughts flow...\n\nTake your time. This is your space.',
          hintStyle: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade300,
            height: 1.8,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: null,
        minLines: 10,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  Widget _buildVoiceRecordingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice Note',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          if (_voiceNotePath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryColor.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic_rounded, color: _primaryColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Voice note recorded',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _voiceNotePath = null),
                      child: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          VoiceRecordingWidget(
            onRecordingComplete: (filePath) {
              if (filePath != null) {
                setState(() {
                  _hasChanges = true;
                  _voiceNotePath = filePath;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Voice note saved ✨'),
                    backgroundColor: _primaryColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: color.withOpacity(0.25),
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
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(List<String> tags) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add tags',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                tags.map((tag) {
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
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient:
                            isSelected
                                ? LinearGradient(
                                  colors: [_primaryColor, _secondaryColor],
                                )
                                : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade200,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color:
                              isSelected ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: _isLoading ? null : _saveEntry,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.entryId != null
                                ? 'Save Changes'
                                : 'Save Entry',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
        return '';
    }
  }
}
