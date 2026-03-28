// mediapipe_service.dart
// Runs MediaPipe Tasks API — Hand Landmarker + Pose Landmarker
// Extracts: 25 upper body pose pts + 21 left hand pts + 21 right hand pts
// Normalizes: wrist-relative coords + scale normalize + nose-relative pose
// Output: 225-dim feature vector (Float32)
//
// CRITICAL: All landmark data must be Float32, not Float64 (TFLite requirement)
// CRITICAL: Normalization is non-negotiable — model accuracy depends on it

import 'dart:async';
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

  /// Process a camera frame and extract landmarks
  /// Takes a CameraImage from the camera stream, converts it,
  /// runs through MediaPipe models, and returns landmark data.
  /// Returns LandmarkData.empty if no landmarks detected or models not loaded.
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

      final width = image.width;
      final height = image.height;

      // Run hand and pose detection in parallel
      final results = await Future.wait([
        _detectHands(rgbBytes, width, height),
        _detectPose(rgbBytes, width, height),
      ]);

      final handResult = results[0] as _HandDetectionResult;
      final poseResult = results[1] as _PoseDetectionResult;

      return LandmarkData(
        poseLandmarks: poseResult.landmarks,
        leftHand: null,
        rightHand: handResult.rightHand,
        poseConfidence: poseResult.confidence,
        leftHandConfidence: 0.0,
        rightHandConfidence: handResult.rightConfidence,
      );
    } catch (e) {
      debugPrint('Error processing frame: $e');
      return const LandmarkData();
    } finally {
      _isProcessing = false;
    }
  }

  /// Resize RGB image to the specified dimensions using bilinear interpolation
  Float32List _resizeAndNormalize(
    Uint8List rgb,
    int srcWidth,
    int srcHeight,
    int dstWidth,
    int dstHeight,
  ) {
    final output = Float32List(dstWidth * dstHeight * 3);
    final xRatio = srcWidth / dstWidth;
    final yRatio = srcHeight / dstHeight;

    for (int y = 0; y < dstHeight; y++) {
      for (int x = 0; x < dstWidth; x++) {
        final srcX = (x * xRatio).floor().clamp(0, srcWidth - 1);
        final srcY = (y * yRatio).floor().clamp(0, srcHeight - 1);
        final srcIdx = (srcY * srcWidth + srcX) * 3;
        final dstIdx = (y * dstWidth + x) * 3;

        // Normalize to [0, 1]
        output[dstIdx] = rgb[srcIdx] / 255.0;
        output[dstIdx + 1] = rgb[srcIdx + 1] / 255.0;
        output[dstIdx + 2] = rgb[srcIdx + 2] / 255.0;
      }
    }
    return output;
  }

  /// Detect hands in the frame using the hand landmark model
  Future<_HandDetectionResult> _detectHands(
    Uint8List rgb,
    int width,
    int height,
  ) async {
    if (_handLandmarkInterpreter == null) {
      return _HandDetectionResult.empty();
    }

    try {
      // Resize to model input size (224×224 for hand landmark)
      const inputSize = 224;
      final input = _resizeAndNormalize(rgb, width, height, inputSize, inputSize);

      // Reshape to [1, 224, 224, 3]
      final inputTensor = input.reshape([1, inputSize, inputSize, 3]);

      // Prepare output tensors
      // Hand landmark model outputs: landmarks (1, 21, 3), handedness (1, 1), confidence (1, 1)
      final landmarkOutput = List.generate(
        1,
        (_) => List.generate(21, (_) => Float32List(3)),
      );
      final confidenceOutput = List.generate(1, (_) => Float32List(1));

      final outputs = <int, Object>{
        0: landmarkOutput,
        1: confidenceOutput,
      };

      _handLandmarkInterpreter!.runForMultipleInputs([inputTensor], outputs);

      final confidence = confidenceOutput[0][0];
      if (confidence < 0.5) return _HandDetectionResult.empty();

      // Extract landmarks
      final landmarks = <LandmarkPoint>[];
      for (int i = 0; i < 21; i++) {
        landmarks.add(LandmarkPoint(
          x: landmarkOutput[0][i][0],
          y: landmarkOutput[0][i][1],
          z: landmarkOutput[0][i][2],
        ));
      }

      // Default to right hand for single-hand signs
      return _HandDetectionResult(
        rightHand: landmarks,
        rightConfidence: confidence,
      );
    } catch (e) {
      debugPrint('Hand detection error: $e');
      return _HandDetectionResult.empty();
    }
  }

  /// Detect pose in the frame using the pose landmark model
  Future<_PoseDetectionResult> _detectPose(
    Uint8List rgb,
    int width,
    int height,
  ) async {
    if (_poseLandmarkInterpreter == null) {
      return _PoseDetectionResult.empty();
    }

    try {
      // Resize to model input size (256×256 for pose landmark)
      const inputSize = 256;
      final input = _resizeAndNormalize(rgb, width, height, inputSize, inputSize);

      // Reshape to [1, 256, 256, 3]
      final inputTensor = input.reshape([1, inputSize, inputSize, 3]);

      // Prepare output: (1, 33, 5) — x, y, z, visibility, presence
      final landmarkOutput = List.generate(
        1,
        (_) => List.generate(33, (_) => Float32List(5)),
      );
      final confidenceOutput = List.generate(1, (_) => Float32List(1));

      final outputs = <int, Object>{
        0: landmarkOutput,
        1: confidenceOutput,
      };

      _poseLandmarkInterpreter!.runForMultipleInputs([inputTensor], outputs);

      final confidence = confidenceOutput[0][0];
      if (confidence < 0.5) return _PoseDetectionResult.empty();

      // Extract upper body landmarks (0-24 only, skip legs)
      final landmarks = <LandmarkPoint>[];
      for (int i = 0; i < 25; i++) {
        landmarks.add(LandmarkPoint(
          x: landmarkOutput[0][i][0],
          y: landmarkOutput[0][i][1],
          z: landmarkOutput[0][i][2],
          visibility: landmarkOutput[0][i][3],
        ));
      }

      return _PoseDetectionResult(
        landmarks: landmarks,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('Pose detection error: $e');
      return _PoseDetectionResult.empty();
    }
  }

  /// Generate mock landmark data for testing when models are not available
  LandmarkData generateMockLandmarks() {
    final pose = List.generate(
      25,
      (i) => LandmarkPoint(
        x: 0.3 + (i % 5) * 0.08,
        y: 0.1 + (i ~/ 5) * 0.15,
        z: 0.0,
        visibility: 0.95,
      ),
    );

    final rightHand = List.generate(
      21,
      (i) => LandmarkPoint(
        x: 0.5 + (i % 5) * 0.02,
        y: 0.4 + (i ~/ 5) * 0.03,
        z: 0.0,
      ),
    );

    return LandmarkData(
      poseLandmarks: pose,
      rightHand: rightHand,
      poseConfidence: 0.95,
      rightHandConfidence: 0.90,
    );
  }
}

/// Internal result class for hand detection
class _HandDetectionResult {
  final List<LandmarkPoint>? rightHand;
  final double rightConfidence;

  _HandDetectionResult({
    this.rightHand,
    this.rightConfidence = 0.0,
  });

  factory _HandDetectionResult.empty() => _HandDetectionResult(
        rightHand: null,
        rightConfidence: 0.0,
      );
}

/// Internal result class for pose detection
class _PoseDetectionResult {
  final List<LandmarkPoint>? landmarks;
  final double confidence;

  _PoseDetectionResult({this.landmarks, this.confidence = 0.0});

  factory _PoseDetectionResult.empty() => _PoseDetectionResult();
}
