import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// Professional audio playback widget with waveform visualization
class AudioPlaybackWidget extends StatefulWidget {
  final String audioPath;
  final VoidCallback? onDelete;

  const AudioPlaybackWidget({
    super.key,
    required this.audioPath,
    this.onDelete,
  });

  @override
  State<AudioPlaybackWidget> createState() => _AudioPlaybackWidgetState();
}

class _AudioPlaybackWidgetState extends State<AudioPlaybackWidget>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;

  late AnimationController _waveController;

  // Generate random waveform bars for visualization
  final List<double> _waveformBars = List.generate(
    35,
    (_) => 0.3 + Random().nextDouble() * 0.7,
  );

  static const _primaryColor = Color(0xFF6366F1);
  static const _secondaryColor = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      if (widget.audioPath.startsWith('http://') ||
          widget.audioPath.startsWith('https://')) {
        await _player.setSourceUrl(widget.audioPath);

        // Manually fetch duration for URL sources
        final dur = await _player.getDuration();
        if (dur != null && mounted) {
          setState(() => _duration = dur);
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      print('Audio player init error: $e');
      setState(() => _isLoading = false);
    }

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _playerState = PlayerState.stopped;
        });
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      // If at end or stopped/completed, restart from beginning
      if (_playerState == PlayerState.stopped ||
          _playerState == PlayerState.completed ||
          (_position.inMilliseconds >= _duration.inMilliseconds - 100 &&
              _duration.inMilliseconds > 0)) {
        setState(() => _position = Duration.zero);
        await _player.play(UrlSource(widget.audioPath));
      } else {
        await _player.resume();
      }
    }
  }

  void _seekTo(double value) {
    final position = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    _player.seek(position);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress =
        _duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor.withOpacity(0.08),
            _secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play/Pause button
              _buildPlayButton(isPlaying),
              const SizedBox(width: 16),

              // Waveform and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mic_rounded,
                                size: 12,
                                color: _primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Voice Note',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Waveform visualization
                    _buildWaveform(isPlaying, progress),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(bool isPlaying) {
    return GestureDetector(
      onTap: _isLoading ? null : _togglePlayPause,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
        child:
            _isLoading
                ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
      ),
    );
  }

  Widget _buildWaveform(bool isPlaying, double progress) {
    return SizedBox(
      height: 40,
      child: GestureDetector(
        onTapDown: (details) {
          if (_duration.inMilliseconds > 0) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final localOffset = box.globalToLocal(details.globalPosition);
            final barWidth = (box.size.width - 80) / _waveformBars.length;
            final tappedIndex = ((localOffset.dx - 68) / barWidth).clamp(
              0,
              _waveformBars.length - 1,
            );
            _seekTo(tappedIndex / _waveformBars.length);
          }
        },
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_waveformBars.length, (index) {
                final isPlayed = index / _waveformBars.length <= progress;
                final barHeight = _waveformBars[index];

                // Add animation when playing
                double animatedHeight = barHeight;
                if (isPlaying && isPlayed) {
                  final wave = sin(
                    (index * 0.3) + (_waveController.value * pi * 2),
                  );
                  animatedHeight = barHeight * (0.7 + wave * 0.3);
                }

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          height: 40 * animatedHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors:
                                  isPlayed
                                      ? [_primaryColor, _secondaryColor]
                                      : [
                                        Colors.grey.shade300,
                                        Colors.grey.shade200,
                                      ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
