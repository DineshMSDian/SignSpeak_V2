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

    final barColor = confidence > 0.88 ? Colors.greenAccent : Colors.amberAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: barColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(confidence * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: barColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
