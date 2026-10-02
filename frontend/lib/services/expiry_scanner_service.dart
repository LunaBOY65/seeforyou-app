import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanResult {
  final String? expiryDate;
  final bool hasText;
  final bool isWrongAngle;
  final Rect? boundingBox;
  final double? angle;

  ScanResult({
    this.expiryDate,
    this.hasText = false,
    this.isWrongAngle = false,
    this.boundingBox,
    this.angle,
  });
}

class ExpiryScannerService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<ScanResult> processImageSmart(String imagePath) async {
    final stopwatch = Stopwatch()..start();
    debugPrint("\n=======================================================");
    debugPrint("[OCR_PIPELINE] START -> Processing Image...");
    debugPrint("[OCR_PIPELINE] File Path: $imagePath");

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      debugPrint(
        "[OCR_PIPELINE] Text Blocks Detected: ${recognizedText.blocks.length}",
      );

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          double currentAngle = _calculateAngle(line.cornerPoints);
          bool lineIsAngled = currentAngle.abs() > 20;

          String? dateInLine = _extractDateFromText(line.text);

          if (dateInLine != null) {
            stopwatch.stop();
            debugPrint(
              "[RESULT] SUCCESS (Line-by-Line) -> Extracted Date: $dateInLine",
            );
            debugPrint(
              "[OCR_PIPELINE] END -> Processing Time: ${stopwatch.elapsedMilliseconds} ms",
            );
            debugPrint(
              "=======================================================\n",
            );

            return ScanResult(
              expiryDate: dateInLine,
              hasText: true,
              isWrongAngle: lineIsAngled,
              boundingBox: line.boundingBox,
              angle: currentAngle,
            );
          }
        }
      }

      debugPrint(
        "[OCR_PIPELINE] Line-by-Line failed. Switching to Global Fallback strategy.",
      );

      StringBuffer buffer = StringBuffer();
      for (TextBlock block in recognizedText.blocks) {
        buffer.write(block.text);
        buffer.write(" ");
      }

      String filteredText = buffer.toString();

      if (filteredText.trim().isEmpty) {
        stopwatch.stop();
        debugPrint("[OCR_PIPELINE] No valid text found in image.");
        return ScanResult(hasText: false);
      }

      String? date = _extractDateFromText(filteredText);

      stopwatch.stop();
      if (date != null) {
        debugPrint(
          "[RESULT] SUCCESS (Global Fallback) -> Extracted Date: $date",
        );
      } else {
        debugPrint("[RESULT] FAILED -> No valid expiry date format found.");
      }
      debugPrint(
        "[OCR_PIPELINE] END -> Processing Time: ${stopwatch.elapsedMilliseconds} ms",
      );
      debugPrint("=======================================================\n");

      return ScanResult(expiryDate: date, hasText: true, isWrongAngle: false);
    } catch (e) {
      debugPrint("[ERROR] Scanner Service Exception: $e");
      return ScanResult(hasText: false);
    }
  }

  /// คำนวณหาความเอียงของตัวหนังสือจากจุด 4 มุม
  double _calculateAngle(List<Point<int>> corners) {
    if (corners.length < 2) return 0;
    final p1 = corners[0]; // Top-Left
    final p2 = corners[1]; // Top-Right
    return atan2(p2.y - p1.y, p2.x - p1.x) * 180 / pi;
  }

  String? _extractDateFromText(String text) {
    String consoleRawText = text.replaceAll('\n', ' ').trim();
    if (consoleRawText.length > 50) {
      consoleRawText = "${consoleRawText.substring(0, 50)}...";
    }
    debugPrint("[DATA_CLEANING] Input Text: '$consoleRawText'");

    String upperText = text.toUpperCase();

    // แปลงตัวอักษรที่คล้ายเลขให้เป็นเลข
    String correctedText = upperText
        .replaceAll(RegExp(r'[OQD]'), '0')
        .replaceAll(RegExp(r'[IL]'), '1')
        .replaceAll('B', '8')
        .replaceAll('S', '5')
        .replaceAll('Z', '2')
        .replaceAll('G', '6');

    String spacedText = correctedText.replaceAll(RegExp(r'[.:/\-]'), ' ');

    // Keyword
    final keywords = [
      'EXP',
      'MFD',
      'MFG',
      'BBE',
      'BBF',
      'BEST',
      'BEFORE',
      'DATE',
    ];

    final keywordStr = keywords.join('|');

    // ประกอบร่าง [กลุ่ม Keyword] + [\W{0,10}เครื่องหมายแปลกๆ 0-10 ตัว] + [รูปแบบวันที่]
    final anchorPattern = RegExp(
      r'(' +
          keywordStr +
          r')\W{0,10}(\d{1,2}[\.\/\-\s]?\d{1,2}[\.\/\-\s]?\d{2,4})',
    );

    final matchesAnchor = anchorPattern.allMatches(upperText);
    if (matchesAnchor.isNotEmpty) {
      debugPrint(
        "[STRATEGY_2] Found ${matchesAnchor.length} matches using Keyword Anchor Pattern.",
      );
    }

    for (final match in matchesAnchor) {
      String dateRaw = match.group(2)!;
      final subParts = dateRaw.split(RegExp(r'[\.\/\-\s]'));
      if (subParts.length >= 3) {
        int? v1 = int.tryParse(subParts[0]);
        int? v2 = int.tryParse(subParts[1]);
        int? v3 = int.tryParse(subParts[2]);

        // ตรวจสอบตามลำดับ วัน/เดือน/ปี (DD/MM/YY)
        if (v1 != null && v2 != null && v3 != null) {
          if (_isValidDate(v1, v2, v3)) {
            debugPrint("[STRATEGY_2] Match Validated: $v1/$v2/$v3");
            return "$v1/$v2/$v3";
          }
        }
      }
    }

    // มีเครื่องหมายคั่น ( / . - ) เช่น 25/12/2025 หรือ 25.10.2024
    // [ \d{1,2} เลขวัน 1-2ตัว] + [คั่น?] + [\d{1,2} เลขเดือน1-2ตัว] + [คั่น?] + [\d{2,4} ปี2-4ตัว]
    final loosePattern = RegExp(
      r'\b(\d{1,2})[\.\/\-\s]?(\d{1,2})[\.\/\-\s]?(\d{2,4})\b',
    );

    final matchesLoose = loosePattern.allMatches(correctedText);

    if (matchesLoose.isNotEmpty) {
      debugPrint(
        "[STRATEGY_1] Found ${matchesLoose.length} matches using Loose Pattern.",
      );
    }

    for (final match in matchesLoose) {
      int? v1 = int.tryParse(match.group(1)!);
      int? v2 = int.tryParse(match.group(2)!);
      int? v3 = int.tryParse(match.group(3)!);

      if (v1 != null && v2 != null && v3 != null) {
        if (_isValidDate(v1, v2, v3)) {
          debugPrint("[STRATEGY_1] Match Validated: $v1/$v2/$v3");
          return "$v1/$v2/$v3";
        }
      }
    }

    // วิธีที่ 3 หาเลขล้วนๆ เช่น 231025 หรือ 20231023
    String lineDigits = correctedText.replaceAll(RegExp(r'[^0-9]'), '');

    if (lineDigits.length > 10) lineDigits = "";

    final digitGroups = RegExp(r'(\d{6,8})').allMatches(lineDigits);

    if (digitGroups.isNotEmpty) {
      debugPrint(
        "[STRATEGY_3] Testing ${digitGroups.length} digit-only groups (Fallback).",
      );
    }

    for (final match in digitGroups) {
      String raw = match.group(0)!;

      if (raw.length == 6) {
        // แบ่งเป็น วัน/เดือน/ปี (2ตัว/2ตัว/2ตัว)
        int v1 = int.parse(raw.substring(0, 2));
        int v2 = int.parse(raw.substring(2, 4));
        int v3 = int.parse(raw.substring(4, 6));

        if (_isValidDate(v1, v2, v3)) {
          debugPrint("[STRATEGY_3] Match Validated (6-digits): $v1/$v2/$v3");
          return "$v1/$v2/$v3";
        }
      } else if (raw.length == 8) {
        // แบ่งเป็น วัน/เดือน/ปี (2ตัว/2ตัว/4ตัว)
        int d = int.parse(raw.substring(0, 2));
        int m = int.parse(raw.substring(2, 4));
        int y = int.parse(raw.substring(4, 8));

        if (_isValidDate(d, m, y)) {
          debugPrint("[STRATEGY_3] Match Validated (8-digits): $d/$m/$y");
          return "$d/$m/$y";
        }
      }
    }

    // มีเว้นวรรคแต่ไม่มีเครื่องหมายอื่น เช่น 25 12 25
    final spacedPattern = RegExp(r'\b(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})\b');
    final matchesSpaced = spacedPattern.allMatches(spacedText);

    for (final match in matchesSpaced) {
      int s1 = int.parse(match.group(1)!);
      int s2 = int.parse(match.group(2)!);
      int s3 = int.parse(match.group(3)!);

      if (_isValidDate(s1, s2, s3)) {
        debugPrint("[STRATEGY_3] Spaced format Validated: $s1/$s2/$s3");
        return "$s1/$s2/$s3";
      }
    }

    return null;
  }

  bool _isValidDate(int d, int m, int y) {
    if (d < 1 || d > 31) return false;
    if (m < 1 || m > 12) return false;

    int fullYear = y;

    if (y >= 10 && y < 100) {
      fullYear = 2000 + y;
    } else if (y >= 2500) {
      fullYear = y - 543;
    }

    return fullYear >= 2018 && fullYear <= 2040;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
