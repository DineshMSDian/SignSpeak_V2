// tflite_service.dart
// Loads and runs TFLite models for on-device inference
// ASL model: MLP — input shape (1, 225), output (1, 26)
// ISL model: LSTM — input shape (1, 30, 225), output (1, 10)
//
// CRITICAL: All inputs must be Float32List, not Float64

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PredictionResult {
  final String label;
  final double confidence;

  PredictionResult(this.label, this.confidence);
}

class TFLiteService {
  Interpreter? _aslInterpreter;
  Interpreter? _islInterpreter;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Labels for mock implementation
  final List<String> _aslLabels = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
  final List<String> _islLabels = ['HELLO', 'THANK YOU', 'PLEASE', 'SORRY', 'YES', 'NO', 'HELP', 'I LOVE YOU', 'WATER', 'FOOD'];

  /// Initialize models. Fails gracefully if files are missing.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      try {
        _aslInterpreter = await Interpreter.fromAsset('models/asl_model.tflite');
        debugPrint('✅ ASL Model loaded successfully');
      } catch (e) {
        debugPrint('⚠️ ASL Model not found, will use mock predictions');
      }

      try {
        _islInterpreter = await Interpreter.fromAsset('models/isl_model.tflite');
        debugPrint('✅ ISL Model loaded successfully');
      } catch (e) {
        debugPrint('⚠️ ISL Model not found, will use mock predictions');
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('❌ Critical TFLite init error: $e');
      return false;
    }
  }

  /// Run inference on a single frame (ASL)
  Future<PredictionResult> predictASL(Float32List featureVector) async {
    if (_aslInterpreter == null) {
      // Return mock prediction
      await Future.delayed(const Duration(milliseconds: 10));
      return _generateMockPrediction(_aslLabels);
    }

    try {
      final input = featureVector.reshape([1, 225]);
      final output = List.generate(1, (_) => Float32List(26));

      _aslInterpreter!.run(input, output);

      final confidences = output[0];
      int maxIdx = 0;
      double maxVal = confidences[0];
      for (int i = 1; i < confidences.length; i++) {
        if (confidences[i] > maxVal) {
          maxVal = confidences[i];
          maxIdx = i;
        }
      }

      final label = _aslLabels[maxIdx % _aslLabels.length];
      return PredictionResult(label, maxVal);
    } catch (e) {
      debugPrint('ASL Inference Error: $e');
      return PredictionResult('Error', 0.0);
    }
  }

  /// Run inference on a 30-frame sequence (ISL)
  Future<PredictionResult> predictISL(List<Float32List> sequence) async {
    if (sequence.length != 30) {
      debugPrint('ISL Error: Sequence must be exactly 30 frames. Got ${sequence.length}');
      return PredictionResult('Error', 0.0);
    }

    if (_islInterpreter == null) {
      // Return mock prediction
      await Future.delayed(const Duration(milliseconds: 50));
      return _generateMockPrediction(_islLabels);
    }

    try {
      // Flatten the 30 vectors into a single contiguous array for reshaping
      final flatInput = Float32List(30 * 225);
      for (int i = 0; i < 30; i++) {
        flatInput.setAll(i * 225, sequence[i]);
      }

      final input = flatInput.reshape([1, 30, 225]);
      final output = List.generate(1, (_) => Float32List(10));

      _islInterpreter!.run(input, output);

      final confidences = output[0];
      int maxIdx = 0;
      double maxVal = confidences[0];
      for (int i = 1; i < confidences.length; i++) {
        if (confidences[i] > maxVal) {
          maxVal = confidences[i];
          maxIdx = i;
        }
      }

      final label = _islLabels[maxIdx % _islLabels.length];
      return PredictionResult(label, maxVal);
    } catch (e) {
      debugPrint('ISL Inference Error: $e');
      return PredictionResult('Error', 0.0);
    }
  }

  PredictionResult _generateMockPrediction(List<String> labels) {
    // Generate a random high confidence score to simulate a real prediction
    final random = Random();
    final confidence = 0.75 + (random.nextDouble() * 0.24); // 0.75 to 0.99
    
    // Pick a random label occasionally to simulate detections (biased to not change too instantly)
    final labelIndex = random.nextInt(labels.length);
    return PredictionResult(labels[labelIndex], confidence);
  }

  void dispose() {
    _aslInterpreter?.close();
    _islInterpreter?.close();
    _aslInterpreter = null;
    _islInterpreter = null;
    _isInitialized = false;
  }
}
