// temporal_filter.dart
// Anti-spam prediction filter — prevents rapid-fire duplicate detections
//
// 4-layer pipeline:
// 1. Confidence gate (> 0.88) — ignores low-confidence predictions
// 2. Majority vote (10/15 frames) — ignores flickering predictions
// 3. Hold duration (12 frames) — gesture must be held, not flashed
// 4. Cooldown (1.2s) — minimum gap between two fired predictions

import 'dart:collection';

class TemporalFilter {
  final int bufferSize;
  final int minAgreement;
  final int holdFrames;
  final double confidenceThreshold;
  final Duration cooldown;

  final Queue<String> _buffer = Queue();
  int _holdCount = 0;
  String? _lastGesture;
  DateTime _lastFired = DateTime(2000);

  TemporalFilter({
    this.bufferSize = 15,
    this.minAgreement = 10,
    this.holdFrames = 12,
    this.confidenceThreshold = 0.88,
    this.cooldown = const Duration(milliseconds: 1200),
  });

  /// Process a prediction through the 4-layer filter.
  /// Returns the gesture label if all gates pass, null otherwise.
  String? process(String prediction, double confidence) {
    // Step 1: Confidence gate
    if (confidence < confidenceThreshold) {
      _holdCount = 0;
      return null;
    }

    // Step 2: Add to buffer
    _buffer.addLast(prediction);
    if (_buffer.length > bufferSize) _buffer.removeFirst();

    // Step 3: Majority vote
    final counts = <String, int>{};
    for (var p in _buffer) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final topEntry = counts.entries
        .reduce((a, b) => a.value > b.value ? a : b);

    if (topEntry.value < minAgreement) return null;

    // Step 4: Hold duration
    if (topEntry.key == _lastGesture) {
      _holdCount++;
    } else {
      _holdCount = 1;
      _lastGesture = topEntry.key;
    }

    if (_holdCount < holdFrames) return null;

    // Step 5: Cooldown check
    final now = DateTime.now();
    if (now.difference(_lastFired) < cooldown) return null;

    // ✅ All gates passed — fire!
    _holdCount = 0;
    _lastFired = now;
    return topEntry.key;
  }

  void reset() {
    _buffer.clear();
    _holdCount = 0;
    _lastGesture = null;
  }
}
