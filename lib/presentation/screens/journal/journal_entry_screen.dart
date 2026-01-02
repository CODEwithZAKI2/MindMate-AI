import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../data/services/journal_ai_service.dart';
import '../../../data/services/voice_recording_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';

/// Modern Journal Entry Screen
/// Dribbble-inspired design with clean, minimal aesthetic
class JournalEntryScreen extends ConsumerStatefulWidget {
  final String? entryId;

  const JournalEntryScreen({super.key, this.entryId});

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();

  int _selectedMood = 3; // Default: Good
  List<String> _selectedTags = [];
  bool _isFavorite = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  String? _promptText;
  String? _voiceNotePath;
  JournalEntry? _existingEntry;
  DateTime _selectedDate = DateTime.now();

  // Voice recording state
  bool _isRecording = false;
  bool _showRecordingMode = false;
  String _recordingTime = '00:00';
  String _liveTranscription = '';
  final VoiceRecordingService _voiceService = VoiceRecordingService();
  late AnimationController _waveController;
  late AnimationController _recordButtonController;

  // Waveform data
  final List<double> _waveformBars = List.generate(
    40,
    (_) => Random().nextDouble(),
  );

  // Design colors
  static const _primaryColor = Color(0xFF6366F1);
  static const _secondaryColor = Color(0xFF8B5CF6);
  static const _backgroundColor = Color(0xFFFAF9F7);
  static const _textColor = Color(0xFF2D2D2D);
  static const _subtleColor = Color(0xFF9CA3AF);

  static const _moodLabels = ['Struggling', 'Low', 'Okay', 'Good', 'Great'];
  static const _moodEmojis = ['😔', '😕', '😐', '🙂', '😊'];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _recordButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

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
    _waveController.dispose();
    _recordButtonController.dispose();
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
        _selectedMood = entry.moodScore ?? 3;
        _selectedTags = List.from(entry.tags);
        _isFavorite = entry.isFavorite;
        _promptText = entry.promptText;
        _selectedDate = entry.createdAt;
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

    setState(() => _isLoading = true);
    try {
      final userId = ref.read(currentUserIdProvider)!;
      final notifier = ref.read(journalNotifierProvider.notifier);
      final aiService = JournalAIService();
      final now = DateTime.now();
      String? entryId;

      // Upload voice recording if exists
      String? voiceDownloadUrl;
      if (_voiceNotePath != null) {
        final voiceService = VoiceRecordingService();
        voiceDownloadUrl = await voiceService.uploadToStorage(
          _voiceNotePath!,
          userId,
        );
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
            hasVoiceRecording:
                voiceDownloadUrl != null || _existingEntry!.hasVoiceRecording,
            voiceFilePath: voiceDownloadUrl ?? _existingEntry!.voiceFilePath,
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
            hasVoiceRecording: voiceDownloadUrl != null,
            voiceFilePath: voiceDownloadUrl,
          ),
        );
      }

      // Trigger transcription for voice recordings
      if (voiceDownloadUrl != null && entryId != null) {
        aiService.transcribeAudio(
          audioUrl: voiceDownloadUrl,
          entryId: entryId,
          userId: userId,
        );
      }

      // Generate AI reflection for substantial content
      if (_existingEntry == null && content.length >= 50) {
        await aiService.generateReflection(
          entryId: entryId!,
          content: content,
          userId: userId,
        );
      }

      setState(() => _isLoading = false);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to save', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _startRecording() async {
    setState(() {
      _showRecordingMode = true;
      _isRecording = true;
      _recordingTime = '00:00';
      _liveTranscription = '';
    });

    await _voiceService.startRecording();
    _startRecordingTimer();
  }

  void _startRecordingTimer() {
    int seconds = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording || !mounted) return false;
      seconds++;
      setState(() {
        final mins = (seconds ~/ 60).toString().padLeft(2, '0');
        final secs = (seconds % 60).toString().padLeft(2, '0');
        _recordingTime = '$mins:$secs';
      });
      return true;
    });
  }

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);
    final path = await _voiceService.stopRecording();
    if (path != null) {
      setState(() => _voiceNotePath = path);
    }
  }

  void _cancelRecording() async {
    setState(() {
      _isRecording = false;
      _showRecordingMode = false;
    });
    await _voiceService.cancelRecording();
  }

  void _confirmRecording() async {
    await _stopRecording();
    setState(() => _showRecordingMode = false);
    _showSnackBar('Voice note added');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildDateMoodRow(),
                Expanded(child: _buildContentArea()),
                _buildBottomToolbar(),
              ],
            ),
          ),

          // Voice recording overlay
          if (_showRecordingMode) _buildRecordingOverlay(),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _textColor,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _existingEntry != null ? 'Edit Journal' : 'Create New Journal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _isFavorite = !_isFavorite),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: _isFavorite ? Colors.red.shade400 : _subtleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateMoodRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          // Date pill
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: _subtleColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, h:mm a').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 13,
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _subtleColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Mood pill
          GestureDetector(
            onTap: _showMoodPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _moodEmojis[_selectedMood],
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _moodLabels[_selectedMood],
                    style: TextStyle(
                      fontSize: 13,
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _subtleColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Title input - elegant italic serif style like Dribbble
          TextField(
            controller: _titleController,
            focusNode: _titleFocus,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: Color(0xFF5D4E37),
              height: 1.3,
              fontFamily: 'Georgia',
            ),
            decoration: InputDecoration(
              hintText: 'Your journal title...',
              hintStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: Color(0xFF5D4E37).withOpacity(0.3),
                fontFamily: 'Georgia',
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            maxLines: null,
          ),
          const SizedBox(height: 24),
          // Content input - seamless like note app
          TextField(
            controller: _contentController,
            focusNode: _contentFocus,
            style: TextStyle(
              fontSize: 17,
              color: Color(0xFF4A4A4A),
              height: 1.7,
              letterSpacing: 0.2,
            ),
            decoration: InputDecoration(
              hintText: 'What\'s on your mind today? Write freely...',
              hintStyle: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade400,
                height: 1.8,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              fillColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            maxLines: null,
            minLines: 15,
          ),
          // Voice note indicator
          if (_voiceNotePath != null) _buildVoiceNoteIndicator(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildVoiceNoteIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'Voice note attached',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _voiceNotePath = null),
            child: Icon(Icons.close_rounded, color: _subtleColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mic button (voice note)
            _buildToolbarButton(
              icon: Icons.mic_none_rounded,
              onTap: _startRecording,
            ),
            // AI prompt button
            _buildToolbarButton(
              icon: Icons.auto_awesome_rounded,
              onTap: _showAIPrompts,
            ),
            // Record button (main action)
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: _primaryColor,
                  size: 24,
                ),
              ),
            ),
            // Emoji/mood button
            _buildToolbarButton(
              icon: Icons.emoji_emotions_outlined,
              onTap: _showMoodPicker,
            ),
            // Save button
            GestureDetector(
              onTap: _saveEntry,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _textColor, size: 22),
      ),
    );
  }

  Widget _buildRecordingOverlay() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          color: _backgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _cancelRecording,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: _textColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Add Audio Journal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const Spacer(),

                // Live transcription
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: _textColor.withOpacity(0.7),
                      height: 1.5,
                    ),
                    child: Text(
                      _liveTranscription.isEmpty
                          ? 'Start speaking...\nYour words will appear here'
                          : _liveTranscription,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const Spacer(),

                // Animated waveform
                SizedBox(
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(40, (index) {
                      final wave = sin(
                        (index * 0.2) + (_waveController.value * pi * 2),
                      );
                      final height =
                          20 + (wave * 30) + (_waveformBars[index] * 20);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 4,
                        height: _isRecording ? height.abs() : 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [_primaryColor, _secondaryColor],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 40),

                // Record button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Cancel button
                    GestureDetector(
                      onTap: _cancelRecording,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.red.shade400,
                          size: 24,
                        ),
                      ),
                    ),

                    const SizedBox(width: 32),

                    // Main record/stop button
                    GestureDetector(
                      onTap: _isRecording ? _confirmRecording : _startRecording,
                      child: AnimatedBuilder(
                        animation: _recordButtonController,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(
                                    Colors.pink.shade300,
                                    Colors.pink.shade400,
                                    _recordButtonController.value,
                                  )!,
                                  Color.lerp(
                                    Colors.red.shade300,
                                    Colors.red.shade400,
                                    _recordButtonController.value,
                                  )!,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.pink.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    _isRecording
                                        ? BorderRadius.circular(6)
                                        : BorderRadius.circular(14),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 32),

                    // Confirm button
                    GestureDetector(
                      onTap: _confirmRecording,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.green.shade500,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Timer
                Text(
                  _recordingTime,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _subtleColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? _selectedDate.hour,
          time?.minute ?? _selectedDate.minute,
        );
      });
    }
  }

  void _showMoodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'How are you feeling?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final isSelected = _selectedMood == index;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedMood = index);
                        Navigator.pop(ctx);
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? _primaryColor.withOpacity(0.1)
                                      : Colors.grey.shade50,
                              shape: BoxShape.circle,
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: _primaryColor,
                                        width: 2,
                                      )
                                      : null,
                            ),
                            child: Text(
                              _moodEmojis[index],
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _moodLabels[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? _primaryColor : _subtleColor,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  void _showAIPrompts() {
    final prompts = [
      'What brought you joy today?',
      'What are you grateful for?',
      'What\'s something you learned today?',
      'What would you tell your past self?',
      'What are you looking forward to?',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: _primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AI Prompts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...prompts.map(
                  (prompt) => GestureDetector(
                    onTap: () {
                      _contentController.text = '$prompt\n\n';
                      _contentFocus.requestFocus();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 14,
                          color: _textColor.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }
}
