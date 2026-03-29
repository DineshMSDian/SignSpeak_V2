// home_screen.dart
// Landing page — mode selector (ASL/ISL), navigation to recognition and data collection
// Model load status indicator

import 'package:flutter/material.dart';
import 'collection_screen.dart';
import 'translation_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤟 SignBridge'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sign_language, size: 80, color: Colors.deepPurpleAccent),
              const SizedBox(height: 24),
              const Text(
                'Welcome to SignBridge',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              _buildNavButton(
                context,
                title: 'Translation Mode',
                icon: Icons.translate,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TranslationScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _buildNavButton(
                context,
                title: 'Data Collection Mode',
                icon: Icons.camera_alt,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CollectionScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(title, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTap,
      ),
    );
  }
}
