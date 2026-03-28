// skeleton_overlay.dart
// CustomPainter widget that draws landmarks on camera feed
// Green dots for hand joints, blue lines for pose connections
// Renders on top of camera preview using Stack widget
// Only draws when landmarks are detected with confidence > 0.5

import 'package:flutter/material.dart';
import '../models/landmark_data.dart';

class SkeletonOverlay extends CustomPainter {
  final LandmarkData? landmarks;
  final Size imageSize;

  SkeletonOverlay({this.landmarks, required this.imageSize});

  // --- Pose skeleton connections (upper body only) ---
  // Based on MediaPipe Pose indices 0-24
  static const List<List<int>> _poseConnections = [
    // Face
    [0, 1], [1, 2], [2, 3], [3, 7], // right eye
    [0, 4], [4, 5], [5, 6], [6, 8], // left eye
    [9, 10], // mouth
    // Torso
    [11, 12], // shoulders
    [11, 23], [12, 24], // shoulders to hips
    [23, 24], // hips
    // Right arm
    [12, 14], [14, 16], // right shoulder → elbow → wrist
    // Left arm
    [11, 13], [13, 15], // left shoulder → elbow → wrist
    // Hands (from pose model)
    [16, 18], [16, 20], [16, 22], // right wrist to fingers
    [15, 17], [15, 19], [15, 21], // left wrist to fingers
  ];

  // --- Hand skeleton connections ---
  // MediaPipe hand landmark indices
  static const List<List<int>> _handConnections = [
    // Thumb
    [0, 1], [1, 2], [2, 3], [3, 4],
    // Index
    [0, 5], [5, 6], [6, 7], [7, 8],
    // Middle
    [0, 9], [9, 10], [10, 11], [11, 12],
    // Ring
    [0, 13], [13, 14], [14, 15], [15, 16],
    // Pinky
    [0, 17], [17, 18], [18, 19], [19, 20],
    // Palm
    [5, 9], [9, 13], [13, 17],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null) return;

    final scaleX = size.width / (imageSize.width > 0 ? imageSize.width : 1);
    final scaleY = size.height / (imageSize.height > 0 ? imageSize.height : 1);

    // Draw pose skeleton
    if (landmarks!.hasPose && landmarks!.poseConfidence > 0.5) {
      _drawPose(canvas, size, scaleX, scaleY);
    }

    // Draw left hand
    if (landmarks!.leftHand != null &&
        landmarks!.leftHand!.isNotEmpty &&
        landmarks!.leftHandConfidence > 0.5) {
      _drawHand(
        canvas,
        landmarks!.leftHand!,
        size,
        scaleX,
        scaleY,
        const Color(0xFF00E676), // Green
      );
    }

    // Draw right hand
    if (landmarks!.rightHand != null &&
        landmarks!.rightHand!.isNotEmpty &&
        landmarks!.rightHandConfidence > 0.5) {
      _drawHand(
        canvas,
        landmarks!.rightHand!,
        size,
        scaleX,
        scaleY,
        const Color(0xFF00E5FF), // Cyan
      );
    }
  }

  void _drawPose(Canvas canvas, Size size, double scaleX, double scaleY) {
    final pose = landmarks!.poseLandmarks!;

    // Connection paint (blue)
    final linePaint = Paint()
      ..color = const Color(0xFF448AFF).withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Joint paint (blue with glow)
    final dotPaint = Paint()
      ..color = const Color(0xFF2979FF)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = const Color(0xFF448AFF).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Draw connections
    for (final connection in _poseConnections) {
      final from = connection[0];
      final to = connection[1];
      if (from >= pose.length || to >= pose.length) continue;

      final p1 = pose[from];
      final p2 = pose[to];

      // Skip if either landmark has low visibility
      if ((p1.visibility ?? 0) < 0.5 || (p2.visibility ?? 0) < 0.5) continue;

      canvas.drawLine(
        Offset(p1.x * size.width, p1.y * size.height),
        Offset(p2.x * size.width, p2.y * size.height),
        linePaint,
      );
    }

    // Draw dots
    for (int i = 0; i < pose.length && i < 25; i++) {
      final lm = pose[i];
      if ((lm.visibility ?? 0) < 0.5) continue;

      final offset = Offset(lm.x * size.width, lm.y * size.height);
      canvas.drawCircle(offset, 6, glowPaint); // glow
      canvas.drawCircle(offset, 3.5, dotPaint); // dot
    }
  }

  void _drawHand(
    Canvas canvas,
    List<LandmarkPoint> hand,
    Size size,
    double scaleX,
    double scaleY,
    Color color,
  ) {
    // Connection paint
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Joint paint
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Draw connections
    for (final connection in _handConnections) {
      final from = connection[0];
      final to = connection[1];
      if (from >= hand.length || to >= hand.length) continue;

      final p1 = hand[from];
      final p2 = hand[to];

      canvas.drawLine(
        Offset(p1.x * size.width, p1.y * size.height),
        Offset(p2.x * size.width, p2.y * size.height),
        linePaint,
      );
    }

    // Draw dots
    for (final lm in hand) {
      final offset = Offset(lm.x * size.width, lm.y * size.height);
      canvas.drawCircle(offset, 5, glowPaint); // glow
      canvas.drawCircle(offset, 3, dotPaint); // dot
    }

    // Draw wrist with larger indicator
    if (hand.isNotEmpty) {
      final wrist = hand[0];
      final offset = Offset(wrist.x * size.width, wrist.y * size.height);
      canvas.drawCircle(
        offset,
        8,
        Paint()..color = color.withValues(alpha: 0.2),
      );
      canvas.drawCircle(offset, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonOverlay oldDelegate) {
    return landmarks != oldDelegate.landmarks;
  }
}
