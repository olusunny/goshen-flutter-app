import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class VoiceRecordingDialog extends StatefulWidget {
  const VoiceRecordingDialog({
    Key? key,
    required this.maxDuration,
    required this.title,
  }) : super(key: key);

  final int maxDuration;
  final String title;

  @override
  State<VoiceRecordingDialog> createState() => _VoiceRecordingDialogState();
}

class _VoiceRecordingDialogState extends State<VoiceRecordingDialog>
    with TickerProviderStateMixin {
  final Record _record = Record();
  Timer? _timer;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  bool _isRecording = false;
  int _recordSeconds = 0;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.9,
      upperBound: 1.15,
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Auto-start recording when screen shows up!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    _record.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted || !await _record.hasPermission()) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record audio.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${widget.title.replaceAll(' ', '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await WakelockPlus.enable();
      await _record.start(
        path: path,
        encoder: AudioEncoder.wav,
        samplingRate: 16000,
        numChannels: 1,
      );

      setState(() {
        _audioPath = path;
        _recordSeconds = 0;
        _isRecording = true;
      });

      _pulseController.repeat(reverse: true);
      _waveController.repeat();

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) return;

        setState(() {
          _recordSeconds++;
        });

        if (_recordSeconds >= widget.maxDuration) {
          await _finishRecording();
        }
      });
    } catch (e) {
      await WakelockPlus.disable();
      print('Error starting record: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _stopOrPause() async {
    if (_isRecording) {
      _timer?.cancel();
      await _record.stop();
      await WakelockPlus.disable();
      _pulseController.stop();
      _waveController.stop();
      setState(() {
        _isRecording = false;
      });
    } else {
      _startRecording();
    }
  }

  Future<void> _finishRecording() async {
    _timer?.cancel();
    final finalPath = await _record.stop();
    await WakelockPlus.disable();
    _pulseController.stop();
    _waveController.stop();

    if (mounted) {
      setState(() {
        _isRecording = false;
        if (finalPath != null) {
          _audioPath = finalPath;
        }
      });

      if (_audioPath != null && _recordSeconds > 0) {
        Navigator.pop(context, {
          'path': _audioPath,
          'duration': _recordSeconds,
        });
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _cancelRecording() async {
    _timer?.cancel();
    await _record.stop();
    await WakelockPlus.disable();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.maxDuration - _recordSeconds;
    final progress = _recordSeconds / widget.maxDuration;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelRecording();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF071224), Color(0xFF0F1A30), Color(0xFF1D1635)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top Header Row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 28),
                        onPressed: _cancelRecording,
                      ),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(
                          width: 48), // Spacer to balance close button
                    ],
                  ),
                ),
                const Spacer(flex: 2),

                // Beautiful Circular Progress & Countdown Animation
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow background circle
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFFF4D67).withValues(alpha: 0.08),
                            blurRadius: 50,
                            spreadRadius: 20,
                          )
                        ],
                      ),
                    ),
                    // Circular Progress ring
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF4D67),
                        ),
                      ),
                    ),
                    // Digital Timer Text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(remaining),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontFamily: 'Courier', // Monospace digital feel
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TIME REMAINING',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // Sleek Animated Soundwave Visualizer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  height: 100,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(12, (index) {
                        return AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            // Unique wave equations for a highly dynamic visualizer
                            double factor = 0.05;
                            if (_isRecording) {
                              final wave = math.sin(
                                  (_waveController.value * 2 * math.pi) +
                                      (index * 0.8));
                              factor = wave.abs();
                            }
                            final maxBarHeight = 65.0;
                            final minBarHeight = 6.0;
                            // Add a random variation to make it look organic
                            final randomAddition = _isRecording
                                ? (math.Random(index).nextDouble() * 12.0)
                                : 0.0;
                            final height = minBarHeight +
                                (factor * (maxBarHeight - minBarHeight)) +
                                randomAddition;

                            return Container(
                              width: 5,
                              height: height,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isRecording
                                      ? [
                                          const Color(0xFFFF4D67),
                                          const Color(0xFFFF8E53)
                                        ]
                                      : [
                                          Colors.white.withValues(alpha: 0.1),
                                          Colors.white.withValues(alpha: 0.15)
                                        ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Controls Action Layout
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Discard / Trash Button
                      GestureDetector(
                        onTap: _cancelRecording,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white70,
                            size: 26,
                          ),
                        ),
                      ),

                      // Primary Pulsing Mic / Stop Button
                      GestureDetector(
                        onTap: _stopOrPause,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale =
                                _isRecording ? _pulseController.value : 1.0;
                            return Transform.scale(
                              scale: scale,
                              child: child,
                            );
                          },
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording
                                  ? const Color(0xFFFF3355)
                                  : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording
                                          ? const Color(0xFFFF3355)
                                          : Colors.white)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                )
                              ],
                            ),
                            child: Icon(
                              _isRecording
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              color: _isRecording
                                  ? Colors.white
                                  : const Color(0xFF0F1A30),
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      // Approve / Save Checkmark Button
                      GestureDetector(
                        onTap: _recordSeconds > 0 ? _finishRecording : null,
                        child: Opacity(
                          opacity: _recordSeconds > 0 ? 1.0 : 0.35,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _recordSeconds > 0
                                  ? const Color(0xFF2EA770)
                                  : Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: _recordSeconds > 0
                                    ? Colors.transparent
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
