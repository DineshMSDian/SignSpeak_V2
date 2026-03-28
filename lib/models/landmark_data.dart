// landmark_data.dart
// Data classes for landmark extraction results
//
// Total landmarks: 67 (25 pose + 21 left hand + 21 right hand)
// Feature vector: 225 dimensions
//   - Pose: 25 landmarks × 4 (x, y, z, visibility) = 100
//   - Left hand: 21 landmarks × 3 (x, y, z) = 63
//   - Right hand: 21 landmarks × 3 (x, y, z) = 63

import 'dart:typed_data';

/// Represents a single landmark point
class LandmarkPoint {
  final double x;
  final double y;
  final double z;
  final double? visibility; // only for pose landmarks

  const LandmarkPoint({
    required this.x,
    required this.y,
    required this.z,
    this.visibility,
  });
}

/// Represents all landmarks extracted from a single frame
class LandmarkData {
  final List<LandmarkPoint>? poseLandmarks;   // 25 upper body points
  final List<LandmarkPoint>? leftHand;         // 21 hand points
  final List<LandmarkPoint>? rightHand;        // 21 hand points
  final double poseConfidence;
  final double leftHandConfidence;
  final double rightHandConfidence;

  const LandmarkData({
    this.poseLandmarks,
    this.leftHand,
    this.rightHand,
    this.poseConfidence = 0.0,
    this.leftHandConfidence = 0.0,
    this.rightHandConfidence = 0.0,
  });

  /// Whether pose was detected
  bool get hasPose => poseLandmarks != null && poseLandmarks!.isNotEmpty;

  /// Whether at least one hand was detected
  bool get hasHand =>
      (leftHand != null && leftHand!.isNotEmpty) ||
      (rightHand != null && rightHand!.isNotEmpty);

  /// Convert to 225-dim Float32 feature vector (normalized)
  /// This is what gets fed to the TFLite models
  Float32List toFeatureVector() {
    // TODO: Implement feature extraction with normalization
    // - Pose: nose-relative coordinates
    // - Hands: wrist-relative + scale normalized
    return Float32List(225);
  }
}
