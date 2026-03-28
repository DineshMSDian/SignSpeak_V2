// recognition_screen.dart
// Live sign recognition — back camera + skeleton overlay + temporal filter
// Rolling letter/gesture buffer, confidence bar, mode toggle (ASL/ISL)
// Translate button → calls Gemini Pro
// Auto-trigger translate after 3s of no new detection

import 'package:flutter/material.dart';

class RecognitionScreen extends StatelessWidget {
  const RecognitionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recognition'),
      ),
      body: const Center(
        child: Text('Recognition Screen — TODO'),
      ),
    );
  }
}
