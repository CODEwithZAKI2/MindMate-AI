import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../core/constants/routes.dart';
import '../../providers/journal_provider.dart';

/// Journal Detail Screen - Dribbble-inspired modern design
/// Clean, minimal, photo-forward layout with integrated voice playback
class JournalDetailScreen extends ConsumerStatefulWidget {
  final String entryId;

  const JournalDetailScreen({super.key, required this.entryId});

  @override
  ConsumerState<JournalDetailScreen> createState() =>
      _JournalDetailScreenState();
}

class _JournalDetailScreenState extends ConsumerState<JournalDetailScreen> {
  JournalEntry? _entry;
  bool _isLoading = true;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  // Design colors
  static const _accentColor = Color(0xFFB8860B); // Gold/brown like Dribbble
  static const _backgroundColor = Color(0xFFFAF9F7);
  static const _textColor = Color(0xFF2D2D2D);
  static const _subtleColor = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _loadEntry();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _audioDuration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  Future<void> _loadEntry() async {
    try {
      final entry = await ref
          .read(journalNotifierProvider.notifier)
          .getEntry(widget.entryId);
      setState(() {
        _entry = entry;
        _isLoading = false;
      });

      // Load audio if exists
      if (entry.voiceFilePath != null) {
        await _audioPlayer.setSourceUrl(entry.voiceFilePath!);
        final dur = await _audioPlayer.getDuration();
        if (dur != null && mounted) setState(() => _audioDuration = dur);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_entry?.voiceFilePath != null) {
        if (_audioPosition >=
            _audioDuration - const Duration(milliseconds: 100)) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.play(UrlSource(_entry!.voiceFilePath!));
      }
    }
  }

  void _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Entry?'),
            content: const Text('This entry will be moved to trash.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(journalNotifierProvider.notifier)
          .deleteEntry(widget.entryId);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_entry == null) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(backgroundColor: _backgroundColor, elevation: 0),
        body: const Center(child: Text('Entry not found')),
      );
    }

    final entry = _entry!;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Clean app bar with just back button
              SliverAppBar(
                backgroundColor: _backgroundColor,
                elevation: 0,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: _textColor,
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (entry.isFavorite)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.red.shade400,
                        size: 22,
                      ),
                    ),
                ],
              ),
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Centered date in accent color
                      Center(
                        child: Text(
                          DateFormat('MMMM d, yyyy').format(entry.createdAt),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _accentColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Large bold title
                      Center(
                        child: Text(
                          entry.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tag pills
                      if (entry.tags.isNotEmpty) _buildTagPills(entry.tags),
                      const SizedBox(height: 24),
                      // Image (if exists)
                      if (entry.imageUrl != null) _buildImage(entry.imageUrl!),
                      // Voice player (if exists)
                      if (entry.voiceFilePath != null) _buildVoicePlayer(),
                      const SizedBox(height: 24),
                      // Content text
                      Text(
                        entry.content,
                        style: TextStyle(
                          fontSize: 16,
                          color: _textColor.withOpacity(0.8),
                          height: 1.8,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Voice transcript
                      if (entry.voiceTranscript != null &&
                          entry.voiceTranscript!.isNotEmpty)
                        _buildTranscript(entry.voiceTranscript!),
                      // AI Reflection
                      if (entry.aiReflection != null)
                        _buildAIReflection(entry.aiReflection!),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom action bar
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildTagPills(List<String> tags) {
    return Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children:
            tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 250,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 250,
              color: Colors.grey.shade100,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 250,
              color: Colors.grey.shade100,
              child: Icon(Icons.broken_image, color: _subtleColor, size: 48),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoicePlayer() {
    final progress =
        _audioDuration.inMilliseconds > 0
            ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
            : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accentColor, _accentColor.withOpacity(0.8)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Waveform / progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated waveform bars
                SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(30, (i) {
                      final isActive = i / 30 <= progress;
                      return Container(
                        width: 3,
                        height: 10 + (i % 5) * 4.0 + (i % 3) * 3.0,
                        decoration: BoxDecoration(
                          color: isActive ? _accentColor : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Duration
          Text(
            _formatDuration(_audioDuration),
            style: TextStyle(
              fontSize: 13,
              color: _subtleColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Widget _buildTranscript(String transcript) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 18, color: _subtleColor),
              const SizedBox(width: 8),
              Text(
                'Voice Transcript',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _subtleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            transcript,
            style: TextStyle(
              fontSize: 15,
              color: _textColor.withOpacity(0.7),
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIReflection(AIReflection reflection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.08),
            const Color(0xFF8B5CF6).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Reflection',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            reflection.toneSummary,
            style: TextStyle(
              fontSize: 15,
              color: _textColor.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          if (reflection.reflectionQuestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Reflect on these:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _subtleColor,
              ),
            ),
            const SizedBox(height: 8),
            ...reflection.reflectionQuestions.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: _accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q,
                        style: TextStyle(
                          fontSize: 14,
                          color: _textColor.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 32,
        right: 32,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Edit button
          _buildActionButton(
            icon: Icons.edit_rounded,
            onTap:
                () => context.push('${Routes.journalEntry}/${widget.entryId}'),
          ),
          const SizedBox(width: 32),
          // Share button
          _buildActionButton(
            icon: Icons.share_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share coming soon')),
              );
            },
          ),
          const SizedBox(width: 32),
          // Delete button
          _buildActionButton(
            icon: Icons.delete_outline_rounded,
            onTap: _deleteEntry,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.shade50 : Colors.grey.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 22,
          color: isDestructive ? Colors.red.shade400 : _textColor,
        ),
      ),
    );
  }
}
