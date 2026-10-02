import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:seeforyou_app/screens/camera/components/camera_overlay.dart';
import 'package:seeforyou_app/screens/camera/controllers/scan_logic_controller.dart';
import 'package:seeforyou_app/services/audio_feedback_service.dart';

class CameraScreen extends StatefulWidget {
  final Function(String path)? onImageSelected;

  const CameraScreen({super.key, this.onImageSelected});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isFlashOn = false;
  bool _isTogglingFlash = false;

  late ScanLogicController _scanController;
  final AudioFeedbackService _feedbackService = AudioFeedbackService();

  @override
  void initState() {
    super.initState();

    _scanController = ScanLogicController(
      _feedbackService,
      onFound: (path) => widget.onImageSelected?.call(path),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    // ตั้งค่ากล้อง
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      // เปิดกล้อง
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;

      // ค่าเริ่มต้น
      await _controller!.setFlashMode(FlashMode.off);
      await _controller?.setFocusMode(FocusMode.auto);
      await _controller?.setExposureMode(ExposureMode.auto);

      _scanController.startLoop(_controller!);
      _feedbackService.playIntro();
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _feedbackService.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) widget.onImageSelected?.call(image.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller!),
                ),
                CameraOverlay(
                  isFlashOn: _isFlashOn,

                  // ฟังก์ชันเปิด-ปิดแฟลช
                  onToggleFlash: () async {
                    // ยุ่งเปิด-ปิดไฟฉายอยู่ไหม
                    if (_isTogglingFlash) return;

                    // ผ่านมาได้คือว่างอยู่ เริ่มอัปเดตหน้า UI
                    setState(() {
                      _isTogglingFlash = true;
                      _isFlashOn = !_isFlashOn;
                    });

                    // เล่นเสียงบอกสถานะ
                    if (_isFlashOn) {
                      _feedbackService.playFlashOn();
                    } else {
                      _feedbackService.playFlashOff();
                    }

                    // สั่งฮาร์ดแวร์เปิด-ปิดตัวมือถือจริงๆ
                    try {
                      await _controller!.setFlashMode(
                        _isFlashOn ? FlashMode.torch : FlashMode.off,
                      );
                    } catch (e) {
                      debugPrint("Flash Toggle Error: $e");
                    } finally {
                      if (mounted) setState(() => _isTogglingFlash = false);
                    }
                  },
                  onGalleryTap: _openGallery,
                ),
              ],
            );
          } else {
            // ระหว่างรอกล้องเปิด ให้แสดงโหลดหมุนๆ
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            );
          }
        },
      ),
    );
  }
}
