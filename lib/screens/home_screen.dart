// home_screen.dart
// Landing page — mode selector (ASL/ISL), navigation to recognition and data collection
// Model load status indicator

import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤟 SignBridge'),
      ),
      body: const Center(
        child: Text('Home Screen — TODO'),
      ),
    );
  }
}
