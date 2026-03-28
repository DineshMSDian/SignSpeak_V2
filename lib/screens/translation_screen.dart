// translation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/mediapipe_service.dart';
import '../services/tflite_service.dart';
import '../services/gemini_service.dart';
import '../widgets/skeleton_overlay.dart';
import '../models/landmark_data.dart';

enum ActiveSignMode { asl, isl }

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  // Services
  final MediaPipeService _mediaPipeService = MediaPipeService();
  final TFLiteService _tfliteService = TFLiteService();
  final GeminiService _geminiService = GeminiService(); // Stubbed for now

  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;

  // ML State
  ActiveSignMode _mode = ActiveSignMode.asl;
  LandmarkData? _currentLandmarks;
  String _currentPredictionBuffer = ''; // The most recent sign detected
  double _currentConfidence = 0.0;
  
  // Buffers
  final List<String> _detectedSequence = []; // List of all words signed so far
  
  // ISL 30-frame buffer
  final List<LandmarkData> _islFrameBuffer = [];

  // Translation Output
  bool _isTranslating = false;
  
  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    await Future.wait([
      _mediaPipeService.initialize(),
      _tfliteService.initialize(),
      _initializeCamera(),
    ]);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraReady = true);
        _startInferenceLoop();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startInferenceLoop() {
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;

      try {
        final landmarks = await _mediaPipeService.processFrame(image);
        if (mounted) setState(() => _currentLandmarks = landmarks);

        // Run inference if confidence is high enough
        if (landmarks.hasPose && landmarks.hasHand && landmarks.overallConfidence > 0.8) {
          if (_mode == ActiveSignMode.asl) {
            await _processASL(landmarks);
          } else {
            await _processISL(landmarks);
          }
        }
      } finally {
        _isProcessingFrame = false;
      }
    });

    // Simple fake debounce/commit loop to simulate word ending gaps
    Timer.periodic(const Duration(seconds: 2), (_) {
      if (_currentPredictionBuffer.isNotEmpty && mounted) {
        setState(() {
          _detectedSequence.add(_currentPredictionBuffer);
          _currentPredictionBuffer = '';
          _currentConfidence = 0.0;
        });
      }
    });
  }

  Future<void> _processASL(LandmarkData landmarks) async {
    final features = landmarks.toFeatureVector();
    final result = await _tfliteService.predictASL(features);

    if (result.confidence > 0.75 && mounted) {
      setState(() {
        _currentPredictionBuffer = result.label;
        _currentConfidence = result.confidence;
      });
    }
  }

  Future<void> _processISL(LandmarkData landmarks) async {
    _islFrameBuffer.add(landmarks);
    
    // When we hit 30 frames, extract sequence and run ISL LSTM
    if (_islFrameBuffer.length >= 30) {
      final sequence = _islFrameBuffer.map((l) => l.toFeatureVector()).toList();
      _islFrameBuffer.clear(); // reset buffer
      
      final result = await _tfliteService.predictISL(sequence);
      if (result.confidence > 0.75 && mounted) {
        setState(() {
          _currentPredictionBuffer = result.label;
          _currentConfidence = result.confidence;
        });
      }
    }
  }

  Future<void> _triggerGeminiTranslation() async {
    if (_detectedSequence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No signs detected to translate.')));
      return;
    }

    setState(() => _isTranslating = true);

    try {
      // Stub: in step 2.13 we will flesh out Gemini service fully
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Translation Result', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Original: ${_detectedSequence.join(' ')}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                const Text('English: Hello, how are you?', style: TextStyle(color: Colors.greenAccent, fontSize: 18)),
                const Text('Tamil: வணக்கம், எப்படி இருக்கிறீர்கள்?', style: TextStyle(color: Colors.blueAccent, fontSize: 18)),
                const Text('Hindi: नमस्ते, आप कैसे हैं?', style: TextStyle(color: Colors.orangeAccent, fontSize: 18)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _detectedSequence.clear());
                },
                child: const Text('Clear & Close'),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _mediaPipeService.dispose();
    _tfliteService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SignBridge Recognition'),
        backgroundColor: Colors.black87,
        actions: [
          DropdownButton<ActiveSignMode>(
            value: _mode,
            dropdownColor: Colors.grey[850],
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: ActiveSignMode.asl, child: Text('ASL Mode')),
              DropdownMenuItem(value: ActiveSignMode.isl, child: Text('ISL Mode')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _mode = v);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: _isCameraReady && _cameraController != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cameraController!),
                      if (_currentLandmarks != null)
                        CustomPaint(
                          painter: SkeletonOverlay(
                            landmarks: _currentLandmarks,
                            imageSize: Size(
                              _cameraController!.value.previewSize?.height ?? 640,
                              _cameraController!.value.previewSize?.width ?? 480,
                            ),
                          ),
                        ),
                      
                      // Live Detection Badge overlay
                      if (_currentPredictionBuffer.isNotEmpty)
                        Positioned(
                          top: 20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.blueAccent, width: 2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentPredictionBuffer,
                                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${(_currentConfidence * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                    ],
                  )
                : const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          ),
          
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detected Sequence:', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 12),
                  
                  // Text crawl
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _detectedSequence.map((word) {
                          return Chip(
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                            side: const BorderSide(color: Colors.blueAccent),
                            label: Text(word, style: const TextStyle(color: Colors.white, fontSize: 18)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // Translate button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isTranslating ? null : _triggerGeminiTranslation,
                      icon: _isTranslating 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.language),
                      label: Text(_isTranslating ? 'Translating...' : 'Translate Sequence'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
