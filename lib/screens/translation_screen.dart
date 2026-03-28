// translation_screen.dart
// Displays Gemini Pro translation output
// Three cards: English, Tamil, Hindi
// TTS button speaks out the English translation
// Loading spinner while waiting for API response

import 'package:flutter/material.dart';

class TranslationScreen extends StatelessWidget {
  const TranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translation')),
      body: const Center(child: Text('Translation Screen — TODO')),
    );
  }
}
