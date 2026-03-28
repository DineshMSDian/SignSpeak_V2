// landmark_data.dart
// Data classes for landmark extraction results
//
// Total landmarks: 67 (25 pose + 21 left hand + 21 right hand)
// Feature vector: 225 dimensions
//   - Pose: 25 landmarks × 4 (x, y, z, visibility) = 100
//   - Left hand: 21 landmarks × 3 (x, y, z) = 63
//   - Right hand: 21 landmarks × 3 (x, y, z) = 63

import 'dart:math' as math;
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

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'x': x, 'y': y, 'z': z};
    if (visibility != null) map['v'] = visibility;
    return map;
  }

  factory LandmarkPoint.fromJson(Map<String, dynamic> json) {
    return LandmarkPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      visibility: json['v'] != null ? (json['v'] as num).toDouble() : null,
    );
  }
}

/// Represents all landmarks extracted from a single frame
class LandmarkData {
  final List<LandmarkPoint>? poseLandmarks; // 25 upper body points
  final List<LandmarkPoint>? leftHand; // 21 hand points
  final List<LandmarkPoint>? rightHand; // 21 hand points
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

  /// Overall confidence — min of detected components
  double get overallConfidence {
    if (!hasPose && !hasHand) return 0.0;
    final scores = <double>[];
    if (hasPose) scores.add(poseConfidence);
    if (leftHand != null && leftHand!.isNotEmpty) {
      scores.add(leftHandConfidence);
    }
    if (rightHand != null && rightHand!.isNotEmpty) {
      scores.add(rightHandConfidence);
    }
    return scores.isEmpty ? 0.0 : scores.reduce(math.min);
  }

  /// Convert to 225-dim Float32 feature vector (normalized)
  /// This is what gets fed to the TFLite models
  Float32List toFeatureVector() {
    final features = Float32List(225);
    int idx = 0;

    // --- POSE (upper body, nose-relative) ---
    if (hasPose && poseLandmarks!.length >= 25) {
      final ref = poseLandmarks![0]; // nose as reference
      for (int i = 0; i < 25; i++) {
        final lm = poseLandmarks![i];
        features[idx++] = (lm.x - ref.x).toDouble();
        features[idx++] = (lm.y - ref.y).toDouble();
        features[idx++] = (lm.z - ref.z).toDouble();
        features[idx++] = (lm.visibility ?? 0.0).toDouble();
      }
    } else {
      // No pose detected — zero-fill 100 values
      idx += 100;
    }

    // --- LEFT HAND (wrist-relative + scale normalized) ---
    _normalizeHand(leftHand, features, idx);
    idx += 63;

    // --- RIGHT HAND (wrist-relative + scale normalized) ---
    _normalizeHand(rightHand, features, idx);

    return features;
  }

  /// Normalize a hand's landmarks:
  /// 1. Subtract wrist (landmark 0) from all points → wrist at origin
  /// 2. Divide by distance from wrist to middle finger MCP (landmark 9) → scale invariant
  void _normalizeHand(
    List<LandmarkPoint>? hand,
    Float32List output,
    int startIdx,
  ) {
    if (hand == null || hand.length < 21) {
      // No hand — leave as zeros (already initialized to 0)
      return;
    }

    final wrist = hand[0];

    // Compute scale factor: distance from wrist to middle finger MCP (landmark 9)
    final mcp = hand[9];
    final dx = mcp.x - wrist.x;
    final dy = mcp.y - wrist.y;
    final dz = mcp.z - wrist.z;
    double scale = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (scale <= 0) scale = 1.0; // avoid division by zero

    int idx = startIdx;
    for (int i = 0; i < 21; i++) {
      final lm = hand[i];
      output[idx++] = ((lm.x - wrist.x) / scale).toDouble();
      output[idx++] = ((lm.y - wrist.y) / scale).toDouble();
      output[idx++] = ((lm.z - wrist.z) / scale).toDouble();
    }
  }

  /// Convert to JSON for data collection export
  Map<String, dynamic> toJson() {
    return {
      'pose': poseLandmarks?.map((p) => p.toJson()).toList(),
      'left_hand': leftHand?.map((p) => p.toJson()).toList(),
      'right_hand': rightHand?.map((p) => p.toJson()).toList(),
    };
  }

  /// Create from JSON (for loading saved data)
  factory LandmarkData.fromJson(Map<String, dynamic> json) {
    return LandmarkData(
      poseLandmarks: json['pose'] != null
          ? (json['pose'] as List)
                .map((p) =>
                    LandmarkPoint.fromJson(Map<String, dynamic>.from(p)))
                .toList()
          : null,
      leftHand: json['left_hand'] != null
          ? (json['left_hand'] as List)
                .map((p) =>
                    LandmarkPoint.fromJson(Map<String, dynamic>.from(p)))
                .toList()
          : null,
      rightHand: json['right_hand'] != null
          ? (json['right_hand'] as List)
                .map((p) =>
                    LandmarkPoint.fromJson(Map<String, dynamic>.from(p)))
                .toList()
          : null,
    );
  }

  /// Create an empty landmark data (all zeros)
  static const empty = LandmarkData();
}
