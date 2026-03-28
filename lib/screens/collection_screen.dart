// collection_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/landmark_data.dart';
import '../services/mediapipe_service.dart';
import '../widgets/skeleton_overlay.dart';

enum SignMode { asl, isl }

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // MediaPipe
  final MediaPipeService _mediaPipeService = MediaPipeService();
  LandmarkData? _currentLandmarks;

  // Collection State
  bool _isCapturing = false;
  Timer? _captureTimer;
  int _samplesCollected = 0;
  static const int _targetSamples = 100;
  static const Duration _captureInterval = Duration(milliseconds: 500);

  // Storage
  final Map<String, List<Map<String, dynamic>>> _collectedData = {};
  SignMode _datasetMode = SignMode.asl;
  final TextEditingController _labelController = TextEditingController(text: 'A');
  String get _currentLabel => _labelController.text.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeMediaPipe();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras found');
        return;
      }

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
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _initializeMediaPipe() async {
    await _mediaPipeService.initialize();
  }

  void _startCapture() {
    if (!_isCameraReady || _isCapturing) return;

    setState(() => _isCapturing = true);

    _cameraController!.startImageStream((CameraImage image) async {
      if (!_isCapturing) return;
      final landmarks = await _mediaPipeService.processFrame(image);
      if (mounted) setState(() => _currentLandmarks = landmarks);
    });

    _captureTimer = Timer.periodic(_captureInterval, (_) {
      _autoCaptureSample();
    });
  }

  void _stopCapture() {
    setState(() => _isCapturing = false);
    _captureTimer?.cancel();
    _captureTimer = null;
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
  }

  void _autoCaptureSample() {
    if (!_isCapturing || _currentLandmarks == null) return;
    final landmarks = _currentLandmarks!;

    if (!landmarks.hasPose || !landmarks.hasHand) return;
    if (landmarks.overallConfidence < 0.85) return;

    final key = '${_datasetMode.name}_$_currentLabel';
    _collectedData.putIfAbsent(key, () => []);

    _collectedData[key]!.add({
      'frame_id': _collectedData[key]!.length,
      ...landmarks.toJson(),
    });

    setState(() {
      _samplesCollected = _collectedData[key]!.length;
    });

    if (_samplesCollected >= _targetSamples) {
      _stopCapture();
      debugPrint('Collected $_targetSamples samples for $_currentLabel');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Finished collecting $_targetSamples for $_currentLabel')),
      );
    }
  }

  Future<void> _exportData() async {
    if (_collectedData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export!')),
        );
      }
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/signspeak_data_$timestamp.json');

      final jsonString = jsonEncode(_collectedData);
      await file.writeAsString(jsonString);

      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'SignSpeak V2 Dataset');
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _stopCapture();
    _cameraController?.dispose();
    _mediaPipeService.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Data Collection'),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.black87,
            child: Row(
              children: [
                DropdownButton<SignMode>(
                  value: _datasetMode,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: const [
                    DropdownMenuItem(value: SignMode.asl, child: Text('ASL')),
                    DropdownMenuItem(value: SignMode.isl, child: Text('ISL')),
                  ],
                  onChanged: _isCapturing ? null : (v) {
                    if (v != null) setState(() => _datasetMode = v);
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _labelController,
                    enabled: !_isCapturing,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Label (e.g. A, HELLO)',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '$_samplesCollected/$_targetSamples',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
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
                    ],
                  )
                : const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _isCapturing ? null : _exportData,
                  icon: const Icon(Icons.download),
                  label: const Text('Export JSON'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isCapturing ? _stopCapture : _startCapture,
                  icon: Icon(_isCapturing ? Icons.stop : Icons.fiber_manual_record),
                  label: Text(_isCapturing ? 'Stop Reconding' : 'Record Label'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCapturing ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
