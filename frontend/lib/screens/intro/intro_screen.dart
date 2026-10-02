import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

class IntroScreen extends StatefulWidget {
  final VoidCallback? onNext;
  const IntroScreen({super.key, this.onNext});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _hintPlayer = AudioPlayer();
  Timer? _holdTimer;
  bool _isPlayingInstruction = false;
  int _secondsHeld = 0;

  @override
  void initState() {
    super.initState();
    _playHintLoop();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _hintPlayer.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _playHintLoop() async {
    try {
      if (_isPlayingInstruction) {
        return;
      }

      await _hintPlayer.setReleaseMode(ReleaseMode.stop);

      // วนลูปเล่นเสียง 2 รอบ
      for (int i = 0; i < 2; i++) {
        if (!mounted || _isPlayingInstruction) break;

        await _hintPlayer.play(AssetSource('audio/hint.mp3'));
        await _hintPlayer.onPlayerComplete.first;

        if (i == 0 && mounted) await Future.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint("Hint Audio Error: $e");
    }
  }

  /// เริ่มจับเวลาเมื่อผู้ใช้กดค้างที่หน้าจอ
  void _startHolding() {
    if (_isPlayingInstruction) return;
    _hintPlayer.stop();
    _holdTimer?.cancel();
    _secondsHeld = 0;

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsHeld++;

      // สั่นเตือน 2 จังหวะ (ตึบ-ตึบ) เพื่อบอกผู้ใช้ว่าผ่านไปแล้ว 1 วินาทีแล้วนะ
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) HapticFeedback.heavyImpact();
      });

      if (_secondsHeld >= 3) {
        _holdTimer?.cancel();
        _playInstructionAudio();
      }
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    _secondsHeld = 0;

    // หากปล่อยมือก่อนครบกำหนด และยังไม่ได้เล่นเสียงอธิบายให้กลับไปเล่นเสียงบอกใบ้ใหม่
    if (!_isPlayingInstruction) {
      _playHintLoop();
    }
  }

  Future<void> _playInstructionAudio() async {
    try {
      setState(() => _isPlayingInstruction = true);
      HapticFeedback.heavyImpact();
      await _audioPlayer.play(AssetSource('audio/instruction.mp3'));
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      debugPrint("Error playing audio: $e");
    } finally {
      if (mounted) setState(() => _isPlayingInstruction = false);
    }
  }

  void _triggerNextPage() {
    _holdTimer?.cancel();
    _hintPlayer.stop();
    _audioPlayer.stop();
    widget.onNext?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        // SafeArea กันไม่ให้เนื้อหาไปทับแถบสถานะมือถือ
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < 0) {
                HapticFeedback.heavyImpact();
                _triggerNextPage();
              }
            },
            onLongPressDown: (_) => _startHolding(),
            onLongPressUp: () => _stopHolding(),
            onLongPressCancel: () => _stopHolding(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: _isPlayingInstruction
                    ? const Color(0xFFDAA520)
                    : const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/one-finger-tap.svg',
                    width: 100,
                    height: 100,
                    colorFilter: const ColorFilter.mode(
                      Colors.black87,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "กดค้าง 3 วินาที",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const Text(
                    "เพื่อฟังคำอธิบาย",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Opacity(
                    opacity: 0.5,
                    child: const Text(
                      "(ปัดซ้ายเพื่อเริ่มใช้งาน)",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
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
}
