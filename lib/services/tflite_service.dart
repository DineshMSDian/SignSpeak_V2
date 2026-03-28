// tflite_service.dart
// Loads and runs TFLite models for on-device inference
// ASL model: MLP — input shape (1, 225), output (1, 26)
// ISL model: LSTM — input shape (1, 30, 225), output (1, 10)
//
// CRITICAL: All inputs must be Float32List, not Float64
// Dart uses Float64 by default — explicit conversion required

class TFLiteService {
  // TODO: Load ASL and ISL models from assets
  // TODO: Run ASL inference (single frame)
  // TODO: Run ISL inference (30-frame sequence)
  // TODO: Return prediction label + confidence score
}
