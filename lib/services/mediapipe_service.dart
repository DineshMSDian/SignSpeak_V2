// mediapipe_service.dart
// Runs MediaPipe Tasks API — Hand Landmarker + Pose Landmarker
// Extracts: 25 upper body pose pts + 21 left hand pts + 21 right hand pts
// Normalizes: wrist-relative coords + scale normalize + nose-relative pose
// Output: 225-dim feature vector (Float32)
//
// CRITICAL: All landmark data must be Float32, not Float64 (TFLite requirement)
// CRITICAL: Normalization is non-negotiable — model accuracy depends on it

import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/landmark_data.dart';

class MediaPipeService {
  Interpreter? _handLandmarkInterpreter;
  Interpreter? _poseLandmarkInterpreter;

  bool _isInitialized = false;
  bool _isProcessing = false;

  /// Whether the service has been successfully initialized
  bool get isInitialized => _isInitialized;

  /// Whether a frame is currently being processed
  bool get isProcessing => _isProcessing;

  /// Initialize the MediaPipe models from assets
  /// Returns true if at least one model loaded successfully
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Try to load hand landmark model
      try {
        _handLandmarkInterpreter = await Interpreter.fromAsset(
          'models/hand_landmarker.task',
          options: InterpreterOptions()..threads = 2,
        );
        debugPrint('✅ Hand landmark model loaded');
      } catch (e) {
        debugPrint('⚠️ Hand landmark model not found: $e');
      }

      // Try to load pose landmark model
      try {
        _poseLandmarkInterpreter = await Interpreter.fromAsset(
          'models/pose_landmarker_lite.task',
          options: InterpreterOptions()..threads = 2,
        );
        debugPrint('✅ Pose landmark model loaded');
      } catch (e) {
        debugPrint('⚠️ Pose landmark model not found: $e');
      }

      _isInitialized =
          _handLandmarkInterpreter != null ||
          _poseLandmarkInterpreter != null;

      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Failed to initialize MediaPipe: $e');
      return false;
    }
  }

  /// Convert CameraImage (YUV420 on Android) to RGB byte array
  /// Returns null if conversion fails.
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

  /// Convert YUV420 (Android camera format) to RGB
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

        // YUV to RGB conversion
        int r = (yVal + 1.370705 * (vVal - 128)).round().clamp(0, 255);
        int g =
            (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
                .round()
                .clamp(0, 255);
        int b = (yVal + 1.732446 * (uVal - 128)).round().clamp(0, 255);

        final idx = (y * width + x) * 3;
        rgb[idx] = r;
        rgb[idx + 1] = g;
        rgb[idx + 2] = b;
      }
    }
    return rgb;
  }

  /// Convert BGRA8888 (iOS camera format) to RGB
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

  /// Release all resources
  void dispose() {
    _handLandmarkInterpreter?.close();
    _poseLandmarkInterpreter?.close();
    _handLandmarkInterpreter = null;
    _poseLandmarkInterpreter = null;
    _isInitialized = false;
  }

  // TODO: Implement processFrame() and feature extraction logic
}
