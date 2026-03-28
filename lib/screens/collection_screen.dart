// collection_screen.dart
// Data collection UI — back camera + auto-capture + skeleton overlay
// Auto-captures 1 sample every 500ms when confidence > 0.85
// Only saves if both pose AND at least 1 hand detected
// Export saves JSON to device Downloads folder

import 'package:flutter/material.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Collection'),
      ),
      body: const Center(
        child: Text('Collection Screen — TODO'),
      ),
    );
  }
}
