import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:seeforyou_app/services/audio_feedback_service.dart';
import 'package:seeforyou_app/services/expiry_scanner_service.dart';

class ScanLogicController {
  final AudioFeedbackService _feedbackService;
  int _consecutiveFoundCount = 0;
  final ExpiryScannerService _scannerService = ExpiryScannerService();
  final Function(String path) onFound;
  Timer? _scanTimer;
  bool _isBusy = false;

  ScanLogicController(this._feedbackService, {required this.onFound});

  void startLoop(CameraController controller) {
    stopLoop();

    debugPrint(">>> START SCAN LOOP");
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) async {
      await _processScan(controller);
    });
  }

  void stopLoop() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _isBusy = false;
  }

  void dispose() {
    stopLoop();
    _scannerService.dispose();
  }

  Future<void> _processScan(CameraController controller) async {
    if (_isBusy || !controller.value.isInitialized) return;

    _isBusy = true;

    try {
      final imageFile = await controller.takePicture();

      final result = await _scannerService.processImageSmart(imageFile.path);

      if (result.expiryDate != null) {
        debugPrint("SCAN RESULT: Found ${result.expiryDate}");
        if (result.isWrongAngle) debugPrint("Angle: WRONG (${result.angle})");
      }

      if (result.expiryDate != null) {
        if (result.isWrongAngle) {
          // ถ้าภาพเอียงเกินไป -> รีเซ็ตตัวนับ -> เตือนให้หมุน
          _consecutiveFoundCount = 0;
          _feedbackService.playRotateWarning();
        } else {
          // ถ้าภาพตรงและเจอวันที่ -> นับคะแนนความมั่นใจเพิ่ม +1
          _consecutiveFoundCount++;
          debugPrint(
            "Found: ${result.expiryDate} (Count: $_consecutiveFoundCount)",
          );

          // ถ้ามั่นใจครบ 2 ครั้งติดกัน
          if (_consecutiveFoundCount >= 2) {
            stopLoop();
            _feedbackService.playFoundDate();
            onFound(imageFile.path); // ส่งรูปกลับใช้งานจริง
            return;
          }
        }
      } else {
        _consecutiveFoundCount = 0;

        if (result.hasText) {
          _feedbackService.triggerHapticLight();
        }
      }
      try {
        await File(imageFile.path).delete();
      } catch (_) {}
    } catch (e) {
      debugPrint("Scan Loop Error: $e");
    } finally {
      if (_scanTimer != null) {
        _isBusy = false;
      }
    }
  }
}
