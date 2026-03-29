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

class _CollectionScreenState extends State<CollectionScreen>
    with SingleTickerProviderStateMixin {
  // ─── Camera ───
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // ─── MediaPipe ───
  final MediaPipeService _mediaPipeService = MediaPipeService();
  LandmarkData? _currentLandmarks;

  // ─── Shared State ───
  int _samplesCollected = 0;
  static const int _targetSamples = 100;
  SignMode _datasetMode = SignMode.asl;
  final TextEditingController _labelController =
      TextEditingController(text: 'A');
  String get _currentLabel => _labelController.text.trim().toUpperCase();

  // ─── ASL-specific (rapid snapshot mode) ───
  bool _isAslCapturing = false;
  Timer? _aslCaptureTimer;
  static const Duration _aslCaptureInterval = Duration(milliseconds: 33);

  // ─── ISL-specific (2-second sequential recording mode) ───
  bool _islIsRecording = false;
  int _islFrameCount = 0;
  static const int _islFramesPerGesture = 60; // 60 frames @ 30fps = 2 seconds
  static const Duration _islFrameInterval =
      Duration(milliseconds: 33); // ~30fps
  List<Map<String, dynamic>> _islSequenceBuffer = [];
  Timer? _islRecordTimer;
  Timer? _islCountdownTimer;
  int _islCountdownSeconds = 2;
  bool _islGestureSaved = false; // brief "✓ Saved" flash

  // ─── Storage ───
  // ASL: { "asl_A": [{frame}, {frame}, ...] }
  // ISL: { "isl_HELLO": [[{f1},{f2},...,{f60}], [{f1},...,{f60}], ...] }
  final Map<String, List<dynamic>> _collectedData = {};

  // ─── Animation ───
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
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

  // ═══════════════════════════════════════════════════════════
  //  ASL MODE — Rapid 33ms snapshot capture (unchanged logic)
  // ═══════════════════════════════════════════════════════════

  void _startAslCapture() {
    if (!_isCameraReady || _isAslCapturing) return;

    setState(() => _isAslCapturing = true);

    _cameraController!.startImageStream((CameraImage image) async {
      if (!_isAslCapturing) return;
      final landmarks = await _mediaPipeService.processFrame(image);
      if (mounted) setState(() => _currentLandmarks = landmarks);
    });

    _aslCaptureTimer = Timer.periodic(_aslCaptureInterval, (_) {
      _aslAutoCaptureSample();
    });
  }

  void _stopAslCapture() {
    setState(() => _isAslCapturing = false);
    _aslCaptureTimer?.cancel();
    _aslCaptureTimer = null;
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
  }

  void _aslAutoCaptureSample() {
    if (!_isAslCapturing || _currentLandmarks == null) return;
    final landmarks = _currentLandmarks!;

    if (!landmarks.hasHand) return;
    if (landmarks.overallConfidence < 0.50) return;

    final key = 'asl_$_currentLabel';
    _collectedData.putIfAbsent(key, () => []);

    _collectedData[key]!.add({
      'frame_id': _collectedData[key]!.length,
      ...landmarks.toJson(),
    });

    setState(() {
      _samplesCollected = _collectedData[key]!.length;
    });

    if (_samplesCollected >= _targetSamples) {
      _stopAslCapture();
      debugPrint('Collected $_targetSamples ASL samples for $_currentLabel');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Finished collecting $_targetSamples ASL frames for $_currentLabel')),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ISL MODE — 2-second sequential gesture recording
  // ═══════════════════════════════════════════════════════════

  void _startIslRecording() {
    if (!_isCameraReady || _islIsRecording) return;

    setState(() {
      _islIsRecording = true;
      _islFrameCount = 0;
      _islCountdownSeconds = 2;
      _islGestureSaved = false;
      _islSequenceBuffer = [];
    });

    // Start camera stream (ISL: NO confidence gating — capture everything)
    _cameraController!.startImageStream((CameraImage image) async {
      if (!_islIsRecording) return;
      final landmarks = await _mediaPipeService.processFrame(image);
      if (mounted) setState(() => _currentLandmarks = landmarks);
    });

    // Capture frames at ~30fps intervals
    _islRecordTimer = Timer.periodic(_islFrameInterval, (_) {
      _islCaptureFrame();
    });

    // Visual countdown timer (2s → 1s → 0s)
    _islCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _islCountdownSeconds--;
      });
      if (_islCountdownSeconds <= 0) {
        _islCountdownTimer?.cancel();
      }
    });
  }

  void _islCaptureFrame() {
    if (!_islIsRecording) return;

    // Capture the current frame regardless of confidence (Option C)
    final landmarks = _currentLandmarks;
    if (landmarks != null) {
      _islSequenceBuffer.add({
        'frame_id': _islFrameCount,
        ...landmarks.toJson(),
      });
    } else {
      // Zero-fill if no landmarks available at this instant
      _islSequenceBuffer.add({
        'frame_id': _islFrameCount,
        'pose': null,
        'left_hand': null,
        'right_hand': null,
      });
    }

    setState(() {
      _islFrameCount++;
    });

    // Check if we've captured all 60 frames
    if (_islFrameCount >= _islFramesPerGesture) {
      _completeIslRecording();
    }
  }

  void _completeIslRecording() {
    // Stop recording
    _islRecordTimer?.cancel();
    _islRecordTimer = null;
    _islCountdownTimer?.cancel();
    _islCountdownTimer = null;

    setState(() => _islIsRecording = false);

    try {
      _cameraController?.stopImageStream();
    } catch (_) {}

    // Save the complete 60-frame sequence as ONE sample
    final key = 'isl_$_currentLabel';
    _collectedData.putIfAbsent(key, () => []);

    // ISL: each sample is a LIST of 60 frame objects (nested array)
    _collectedData[key]!.add(List<Map<String, dynamic>>.from(_islSequenceBuffer));
    _islSequenceBuffer = [];

    setState(() {
      _samplesCollected = _collectedData[key]!.length;
      _islGestureSaved = true;
    });

    // Brief "✓ Saved" flash, then reset
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _islGestureSaved = false);
    });

    if (_samplesCollected >= _targetSamples) {
      debugPrint(
          'Collected $_targetSamples ISL gesture sequences for $_currentLabel');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Finished collecting $_targetSamples ISL gestures for $_currentLabel')),
      );
    }
  }

  void _cancelIslRecording() {
    _islRecordTimer?.cancel();
    _islRecordTimer = null;
    _islCountdownTimer?.cancel();
    _islCountdownTimer = null;
    setState(() {
      _islIsRecording = false;
      _islSequenceBuffer = [];
      _islFrameCount = 0;
    });
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED — Export, Dispose, Helpers
  // ═══════════════════════════════════════════════════════════

  bool get _isAnythingActive => _isAslCapturing || _islIsRecording;

  void _handleRecordButton() {
    if (_datasetMode == SignMode.asl) {
      _isAslCapturing ? _stopAslCapture() : _startAslCapture();
    } else {
      _islIsRecording ? _cancelIslRecording() : _startIslRecording();
    }
  }

  /// Reset samples counter when switching labels or modes
  void _updateSamplesCounter() {
    final prefix = _datasetMode == SignMode.asl ? 'asl' : 'isl';
    final key = '${prefix}_$_currentLabel';
    _samplesCollected = _collectedData[key]?.length ?? 0;
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
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'SignSpeak V2 Dataset',
          ),
        );
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
    _stopAslCapture();
    _cancelIslRecording();
    _cameraController?.dispose();
    _mediaPipeService.dispose();
    _labelController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isISL = _datasetMode == SignMode.isl;
    final sampleUnit = isISL ? 'gestures' : 'frames';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Data Collection'),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // ─── Top Controls Bar ───
          _buildControlsBar(sampleUnit),

          // ─── Camera Preview with Overlays ───
          Expanded(
            child: _isCameraReady && _cameraController != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cameraController!),

                      // Skeleton overlay
                      if (_currentLandmarks != null)
                        CustomPaint(
                          painter: SkeletonOverlay(
                            landmarks: _currentLandmarks,
                            imageSize: Size(
                              _cameraController!.value.previewSize?.height ??
                                  640,
                              _cameraController!.value.previewSize?.width ??
                                  480,
                            ),
                          ),
                        ),

                      // ISL recording overlay
                      if (isISL && _islIsRecording) _buildIslRecordingOverlay(),

                      // ISL "✓ Gesture Saved" flash
                      if (isISL && _islGestureSaved) _buildGestureSavedOverlay(),

                      // Mode indicator badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isISL
                                ? Colors.orange.withValues(alpha: 0.85)
                                : Colors.blue.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isISL ? '● ISL Sequential' : '● ASL Static',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child:
                        CircularProgressIndicator(color: Colors.blueAccent)),
          ),

          // ─── Bottom Action Bar ───
          _buildActionBar(isISL),
        ],
      ),
    );
  }

  Widget _buildControlsBar(String sampleUnit) {
    return Container(
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
            onChanged: _isAnythingActive
                ? null
                : (v) {
                    if (v != null) {
                      setState(() {
                        _datasetMode = v;
                        _labelController.text =
                            v == SignMode.asl ? 'A' : 'HELLO';
                        _updateSamplesCounter();
                      });
                    }
                  },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _labelController,
              enabled: !_isAnythingActive,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: _datasetMode == SignMode.asl
                    ? 'Letter (e.g. A, B)'
                    : 'Gesture (e.g. HELLO)',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54)),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent)),
              ),
              onChanged: (_) => _updateSamplesCounter(),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_samplesCollected/$_targetSamples',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                sampleUnit,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIslRecordingOverlay() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          children: [
            // Pulsing red border to indicate recording
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.redAccent
                          .withValues(alpha: 0.4 + _pulseController.value * 0.5),
                      width: 4,
                    ),
                  ),
                ),
              ),
            ),

            // Countdown + frame counter
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white
                              .withValues(alpha: 0.5 + _pulseController.value * 0.5),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'REC ${_islCountdownSeconds > 0 ? '${_islCountdownSeconds}s' : '...'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Frame $_islFrameCount/$_islFramesPerGesture',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Progress bar at bottom of camera
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _islFrameCount / _islFramesPerGesture,
                backgroundColor: Colors.black45,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                minHeight: 5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGestureSavedOverlay() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + value * 0.2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Gesture Saved!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionBar(bool isISL) {
    final bool isActive = _isAnythingActive;
    final bool isDone = _samplesCollected >= _targetSamples;

    String buttonLabel;
    IconData buttonIcon;

    if (isISL) {
      if (_islIsRecording) {
        buttonLabel = 'Cancel Recording';
        buttonIcon = Icons.cancel;
      } else if (isDone) {
        buttonLabel = 'All Gestures Collected!';
        buttonIcon = Icons.check_circle;
      } else {
        buttonLabel = 'Record Gesture (2s)';
        buttonIcon = Icons.radio_button_checked;
      }
    } else {
      if (_isAslCapturing) {
        buttonLabel = 'Stop Recording';
        buttonIcon = Icons.stop;
      } else if (isDone) {
        buttonLabel = 'All Frames Collected!';
        buttonIcon = Icons.check_circle;
      } else {
        buttonLabel = 'Record Label';
        buttonIcon = Icons.fiber_manual_record;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: isActive ? null : _exportData,
            icon: const Icon(Icons.download),
            label: const Text('Export JSON'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
          ElevatedButton.icon(
            onPressed: isDone && !isActive ? null : _handleRecordButton,
            icon: Icon(buttonIcon),
            label: Text(buttonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive
                  ? Colors.red
                  : isDone
                      ? Colors.grey
                      : Colors.green,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}
