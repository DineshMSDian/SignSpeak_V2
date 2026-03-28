// gesture_badge.dart
// Floating prediction card shown at bottom of camera feed
// Shows: letter/gesture name + confidence percentage + color coded bar
// Green if confidence > 0.88, yellow 0.7-0.88, hidden below 0.7

import 'package:flutter/material.dart';

class GestureBadge extends StatelessWidget {
  final String? label;
  final double confidence;

  const GestureBadge({
    super.key,
    this.label,
    this.confidence = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null || confidence < 0.7) {
      return const SizedBox.shrink();
    }

    // TODO: Implement animated badge with confidence bar
    return const Placeholder();
  }
}
