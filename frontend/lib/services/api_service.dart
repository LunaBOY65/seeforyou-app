import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  static Future<http.Response> uploadImage(File imageFile) async {
    final uri = Uri.parse('$backendBaseUrl/analyze');

    debugPrint('API Request Uploading to: $uri');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      debugPrint('[API Response] Status: ${response.statusCode}');
      debugPrint('[API Body]: ${response.body}');

      return response;
    } catch (e) {
      debugPrint('[API Error]: $e');
      rethrow;
    }
  }
}
