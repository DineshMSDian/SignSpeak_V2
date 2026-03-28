// skeleton_overlay.dart
// CustomPainter widget that draws landmarks on camera feed
// Green dots for hand joints, blue lines for pose connections
// Renders on top of camera preview using Stack widget
// Only draws when landmarks are detected with confidence > 0.5

import 'package:flutter/material.dart';

class SkeletonOverlay extends CustomPainter {
  // TODO: Accept LandmarkData as input
  // TODO: Draw pose skeleton (blue connections)
  // TODO: Draw hand landmarks (green dots)
  // TODO: Scale coordinates to match camera preview size

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: Implement landmark drawing
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
