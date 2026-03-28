// prediction_result.dart
// Data class for model inference output
// Used by both ASL (MLP) and ISL (LSTM) models

/// Represents the output of a TFLite model prediction
class PredictionResult {
  final String label;          // predicted letter (ASL) or gesture (ISL)
  final double confidence;     // softmax probability (0.0 - 1.0)
  final SignMode mode;         // which model produced this
  final DateTime timestamp;

  PredictionResult({
    required this.label,
    required this.confidence,
    required this.mode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Whether this prediction passes the confidence threshold
  bool get isConfident => mode == SignMode.asl
      ? confidence >= 0.88
      : confidence >= 0.85;

  @override
  String toString() => '$label (${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Active sign language mode
enum SignMode {
  asl,  // American Sign Language — 26 static letters
  isl,  // Indian Sign Language — 10 dynamic gestures
}
