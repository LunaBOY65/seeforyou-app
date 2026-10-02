import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CameraOverlay extends StatefulWidget {
  final bool isFlashOn;
  final VoidCallback onToggleFlash;
  final Future<void> Function() onGalleryTap;

  const CameraOverlay({
    super.key,
    required this.isFlashOn,
    required this.onToggleFlash,
    required this.onGalleryTap,
  });

  @override
  State<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends State<CameraOverlay> {
  DateTime? _lastTapTime;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _handleGalleryTap() async {
    final now = DateTime.now();
    bool isDoubleTap = false;

    if (_lastTapTime != null) {
      int timePassed = now.difference(_lastTapTime!).inMilliseconds;

      isDoubleTap = timePassed < 1500;
    }

    HapticFeedback.heavyImpact();

    if (isDoubleTap) {
      _lastTapTime = null;

      await _audioPlayer.stop();
      await widget.onGalleryTap();
      await _audioPlayer.play(AssetSource('audio/closeGallery.mp3'));
    } else {
      _lastTapTime = now;
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/openGallery.mp3'));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ปุ่ม Flash
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 20,
          child: IconButton(
            icon: Icon(
              widget.isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
              size: 30,
            ),
            onPressed: widget.onToggleFlash,
          ),
        ),

        // ปุ่ม Gallery
        Positioned(
          bottom: 60,
          right: 40,
          child: GestureDetector(
            onTap: _handleGalleryTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SvgPicture.asset(
                  'assets/icons/folder_icon.svg',
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
