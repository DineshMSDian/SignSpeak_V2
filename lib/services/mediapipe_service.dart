// mediapipe_service.dart
// Runs MediaPipe Tasks API — Hand Landmarker + Pose Landmarker
// Extracts: 25 upper body pose pts + 21 left hand pts + 21 right hand pts
// Normalizes: wrist-relative coords + scale normalize + nose-relative pose
// Output: 225-dim feature vector (Float32)
//
// CRITICAL: All landmark data must be Float32, not Float64 (TFLite requirement)
// CRITICAL: Normalization is non-negotiable — model accuracy depends on it

class MediaPipeService {
  // TODO: Initialize Hand Landmarker + Pose Landmarker
  // TODO: Process camera frames
  // TODO: Extract and normalize landmarks
  // TODO: Return 225-dim feature vector
}
