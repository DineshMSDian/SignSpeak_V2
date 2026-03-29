// mediapipe_service.dart
// Uses Native Android Platform Channel to run com.google.mediapipe:tasks-vision API.
// Normalizes and bridges data directly from Kotlin to Dart.

import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/landmark_data.dart';

class MediaPipeService {
  static const MethodChannel _channel = MethodChannel('com.example.signspeak_v2/mediapipe');

  bool _isInitialized = false;
  bool _isProcessing = false;

  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;

  /// Initialize the MediaPipe models via Native Android code
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final bool? success = await _channel.invokeMethod<bool>('init');
      _isInitialized = success ?? false;
      if (_isInitialized) {
        debugPrint('✅ Native MediaPipe SDK Initialized');
      } else {
        debugPrint('❌ Native MediaPipe Initialization returned false');
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Failed to initialize Native MediaPipe: $e');
      return false;
    }
  }

  /// Convert CameraImage (YUV420 on Android) to RGB byte array
  Uint8List? convertCameraImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _yuv420ToRgb(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return _bgra8888ToRgb(image);
      }
      debugPrint('Unsupported image format: ${image.format.group}');
      return null;
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }

  /// Convert YUV420 to flat RGB (3 bytes per pixel)
  Uint8List _yuv420ToRgb(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final rgb = Uint8List(width * height * 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

        final yVal = yPlane.bytes[yIndex];
        final uVal = uPlane.bytes[uvIndex];
        final vVal = vPlane.bytes[uvIndex];

        int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
        int g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128)).round().clamp(0, 255);
        int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

        final idx = (y * width + x) * 3;
        rgb[idx] = r;
        rgb[idx + 1] = g;
        rgb[idx + 2] = b;
      }
    }
    return rgb;
  }

  /// Convert BGRA8888 to RGB
  Uint8List _bgra8888ToRgb(CameraImage image) {
    final bytes = image.planes[0].bytes;
    final width = image.width;
    final height = image.height;
    final rgb = Uint8List(width * height * 3);

    for (int i = 0, j = 0; i < bytes.length; i += 4, j += 3) {
      rgb[j] = bytes[i + 2]; // R
      rgb[j + 1] = bytes[i + 1]; // G
      rgb[j + 2] = bytes[i]; // B
    }
    return rgb;
  }

  void dispose() {
    _channel.invokeMethod('dispose');
    _isInitialized = false;
  }

  /// Send image directly to Android SDK via MethodChannel and parse JSON
  Future<LandmarkData> processFrame(CameraImage image) async {
    if (!_isInitialized || _isProcessing) {
      return const LandmarkData();
    }

    _isProcessing = true;

    try {
      final rgbBytes = convertCameraImage(image);
      if (rgbBytes == null) {
        return const LandmarkData();
      }

      final jsonResult = await _channel.invokeMethod<String>('processImage', {
        'bytes': rgbBytes,
        'width': image.width,
        'height': image.height,
      });

      if (jsonResult == null || jsonResult == '{}') {
        return const LandmarkData();
      }

      final data = jsonDecode(jsonResult) as Map<String, dynamic>;

      // Parse Left Hand (Bug #3 fixed natively in Kotlin)
      List<LandmarkPoint>? leftHandLms;
      if (data.containsKey('leftHand')) {
        leftHandLms = (data['leftHand'] as List).map((p) => LandmarkPoint.fromJson(p)).toList();
      }

      // Parse Right Hand
      List<LandmarkPoint>? rightHandLms;
      if (data.containsKey('rightHand')) {
        rightHandLms = (data['rightHand'] as List).map((p) => LandmarkPoint.fromJson(p)).toList();
      }

      // Parse Pose
      List<LandmarkPoint>? poseLms;
      if (data.containsKey('pose')) {
        poseLms = (data['pose'] as List).map((p) => LandmarkPoint.fromJson(p)).toList();
      }

      return LandmarkData(
        poseLandmarks: poseLms,
        leftHand: leftHandLms,
        rightHand: rightHandLms,
        poseConfidence: (data['poseConfidence'] as num?)?.toDouble() ?? 0.0,
        leftHandConfidence: (data['leftHandConfidence'] as num?)?.toDouble() ?? 0.0,
        rightHandConfidence: (data['rightHandConfidence'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      debugPrint('Error processing native frame: $e');
      return const LandmarkData();
    } finally {
      _isProcessing = false;
    }
  }
}
