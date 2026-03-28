# ASL & ISL Sign Language Recognition — Full Project Instructions
> Use this file as the master reference for building the entire project from scratch.
> Stack: Flutter (mobile) + Python (training) + MediaPipe Tasks API + TFLite + Gemini Pro

---

## 📌 Project Overview

Build a **mobile-first** sign language recognition app that:
- Detects **ASL** (American Sign Language) — 26 static fingerspelled letters
- Detects **ISL** (Indian Sign Language) — 10 dynamic gestures
- Translates recognized signs to English / Tamil / Hindi using **Gemini Pro API**
- Uses **back camera** for both data collection AND inference (no flip issues)
- Runs fully on-device with TFLite models

---

## 🏗️ Full System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MOBILE APP (Flutter)                      │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   DATA        │    │  RECOGNITION │    │   TRANSLATION    │  │
│  │  COLLECTION   │    │    SCREEN    │    │     SCREEN       │  │
│  │   SCREEN      │    │              │    │                  │  │
│  └──────┬───────┘    └──────┬───────┘    └────────┬─────────┘  │
│         │                   │                      │             │
│         ▼                   ▼                      ▼             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              BACK CAMERA (CameraX / camera plugin)       │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                             │                                    │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           MediaPipe Tasks — Holistic Inference            │   │
│  │     Pose Landmarker + Hand Landmarker (both hands)       │   │
│  │     Output: 25 pose pts + 21L hand pts + 21R hand pts    │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                             │                                    │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              FEATURE EXTRACTION + NORMALIZE               │   │
│  │   Wrist-relative coords + scale normalize + angles        │   │
│  │   Output: 225-dim feature vector (flip-invariant)        │   │
│  └──────────────┬──────────────────────────┬───────────────┘   │
│                 │                            │                    │
│                 ▼                            ▼                    │
│  ┌──────────────────────┐    ┌──────────────────────────────┐  │
│  │   ASL TFLite Model   │    │      ISL TFLite Model        │  │
│  │   (MLP — static)     │    │   (LSTM — 30 frame seq)      │  │
│  │   26 letter classes  │    │   10 gesture classes         │  │
│  └──────────┬───────────┘    └─────────────┬────────────────┘  │
│             │                               │                     │
│             └──────────────┬───────────────┘                     │
│                            ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │         TEMPORAL FILTER (Anti-Spam Pipeline)             │   │
│  │   Majority vote (15 frames) + Confidence gate (>0.88)   │   │
│  │   Hold duration (12 frames) + Cooldown (1.2s)           │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                             │                                    │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              LETTER / GESTURE BUFFER                     │   │
│  │   Accumulates detections → triggers translation          │   │
│  └─────────────────────────┬───────────────────────────────┘   │
│                             │                                    │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  GEMINI PRO API                           │   │
│  │   Fingerspelled letters → words → Tamil/Hindi/English    │   │
│  │   ISL gesture labels → natural sentence → translation    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project File Structure

```
asl_isl_project/
│
├── flutter_app/                        # Mobile app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── collection_screen.dart   # Data collection
│   │   │   ├── recognition_screen.dart  # Live recognition
│   │   │   └── translation_screen.dart  # Gemini output
│   │   ├── services/
│   │   │   ├── mediapipe_service.dart   # Landmark extraction
│   │   │   ├── tflite_service.dart      # Model inference
│   │   │   ├── temporal_filter.dart     # Anti-spam logic
│   │   │   └── gemini_service.dart      # Gemini Pro API
│   │   ├── models/
│   │   │   ├── landmark_data.dart
│   │   │   └── prediction_result.dart
│   │   └── widgets/
│   │       ├── skeleton_overlay.dart    # Draw landmarks
│   │       └── gesture_badge.dart
│   ├── assets/
│   │   ├── models/
│   │   │   ├── asl_model.tflite
│   │   │   └── isl_model.tflite
│   │   └── labels/
│   │       ├── asl_labels.txt
│   │       └── isl_labels.txt
│   └── pubspec.yaml
│
├── python_training/                    # PC training pipeline
│   ├── collect_data.py                 # (optional laptop fallback)
│   ├── preprocess.py                   # Normalize + augment
│   ├── train_asl.py                    # Train MLP
│   ├── train_isl.py                    # Train LSTM
│   ├── export_tflite.py                # Convert to TFLite
│   ├── data/
│   │   ├── asl_raw/                    # JSON from mobile
│   │   └── isl_raw/                    # JSON from mobile
│   └── models/
│       ├── asl_model.h5
│       ├── isl_model.h5
│       ├── asl_model.tflite
│       └── isl_model.tflite
│
└── ASL_ISL_PROJECT_INSTRUCTIONS.md    # This file
```

---

## 📱 Flutter App — Screen by Screen

### Screen 1: Home Screen

```
┌─────────────────────────────┐
│                             │
│     🤟 SignSpeak           │
│     ASL & ISL Translator    │
│                             │
│  ┌─────────────────────┐   │
│  │  📷 Start           │   │
│  │     Recognition     │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │  📦 Collect         │   │
│  │     Training Data   │   │
│  └─────────────────────┘   │
│                             │
│  ┌──────────┐ ┌──────────┐ │
│  │   ASL    │ │   ISL    │ │  ← toggle active mode
│  │    ✅    │ │          │ │
│  └──────────┘ └──────────┘ │
│                             │
│  Model status: ✅ Loaded    │
└─────────────────────────────┘
```

---

### Screen 2: Data Collection Screen (MOST IMPORTANT)

```
┌─────────────────────────────┐
│  ← Back    [ASL ▾] [ISL ▾] │  ← dataset toggle
├─────────────────────────────┤
│  Gesture: Letter "A"        │
│  Progress: 67 / 100  ████░  │
│                             │
│  ┌─────────────────────┐   │
│  │                     │   │
│  │   LIVE CAMERA FEED  │   │
│  │   (back camera)     │   │
│  │                     │   │
│  │  [skeleton overlay] │   │
│  │                     │   │
│  └─────────────────────┘   │
│                             │
│  Pose: ✅  Hands: ✅        │
│  Confidence: 0.94           │
│  Status: 🟢 AUTO CAPTURING  │
│                             │
│  ┌────────┐  ┌───────────┐ │
│  │ ⏸ STOP│  │ ⏭ SKIP   │ │
│  └────────┘  └───────────┘ │
│                             │
│  ┌─────────────────────┐   │
│  │  💾 Export to JSON  │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

**Behavior:**
- Auto-captures 1 sample every 500ms when confidence > 0.85
- Only saves if both pose AND at least 1 hand detected
- Shows live skeleton overlay on camera feed
- Moves to next gesture automatically at 100 samples
- Export saves JSON to device Downloads folder

---

### Screen 3: Recognition Screen

```
┌─────────────────────────────┐
│  ← Back    MODE: [ASL][ISL] │
├─────────────────────────────┤
│  ┌─────────────────────┐   │
│  │                     │   │
│  │   LIVE CAMERA FEED  │   │
│  │   (back camera)     │   │
│  │                     │   │
│  │  [skeleton overlay] │   │
│  │                     │   │
│  └─────────────────────┘   │
│                             │
│  Detected: [ A ] [ S ] [ L ]│  ← rolling buffer
│                             │
│  Current: ████ "L"  94%    │  ← confidence bar
│                             │
│  Buffer: "A S L"            │
│                             │
│  ┌─────────────────────┐   │
│  │  🌐 Translate Now   │   │
│  └─────────────────────┘   │
│  ┌──────────┐ ┌──────────┐ │
│  │  🗑 Clear│ │ ⏸ Pause │ │
│  └──────────┘ └──────────┘ │
└─────────────────────────────┘
```

**Behavior:**
- Temporal filter runs on every frame (no spam)
- Letters/gestures appear in buffer with animation
- "Translate Now" → calls Gemini Pro
- Auto-trigger translate after 3s of no new detection

---

### Screen 4: Translation Screen

```
┌─────────────────────────────┐
│  ← Back         🔊 Speak   │
├─────────────────────────────┤
│  Detected Signs:            │
│  "A S L   I S   G O O D"   │
│                             │
│  ┌─────────────────────┐   │
│  │  🇬🇧 English:       │   │
│  │  "ASL is good"      │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │  🇮🇳 Tamil:          │   │
│  │  "ASL நல்லது"        │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │  🇮🇳 Hindi:          │   │
│  │  "ASL अच्छा है"      │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │  🔁 Recognize Again │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

---

## 🧠 Feature Vector Design

### Landmarks Used
```
MediaPipe Holistic output:
  - Pose: landmarks 0–24 (upper body only, skip legs 25-32)
  - Left Hand: 21 landmarks
  - Right Hand: 21 landmarks

Total: 25 pose + 21 + 21 = 67 landmarks
With x,y,z (+visibility for pose) = 225 features
```

### Normalization (Critical — do this or accuracy suffers)

```python
def extract_features(pose_landmarks, left_hand, right_hand):
    features = []

    # --- POSE (upper body) ---
    if pose_landmarks:
        upper_body = list(range(25))  # skip legs
        ref = pose_landmarks.landmark[0]  # nose as reference
        for i in upper_body:
            lm = pose_landmarks.landmark[i]
            features.extend([
                lm.x - ref.x,   # relative to nose
                lm.y - ref.y,
                lm.z - ref.z,
                lm.visibility
            ])
    else:
        features.extend([0.0] * 100)

    # --- HANDS (wrist-relative + scale normalize) ---
    for hand_landmarks in [left_hand, right_hand]:
        if hand_landmarks:
            lm = [[l.x, l.y, l.z] for l in hand_landmarks.landmark]
            lm = np.array(lm)
            lm -= lm[0]                     # wrist to origin
            scale = np.linalg.norm(lm[9])   # middle finger MCP
            if scale > 0:
                lm /= scale                 # scale normalize
            features.extend(lm.flatten())   # 63 values
        else:
            features.extend([0.0] * 63)

    return np.array(features, dtype=np.float32)  # shape: (225,)
```

---

## 🤖 Model Architectures

### ASL Model (Static — Single Frame)

```python
import tensorflow as tf

def build_asl_model(input_dim=225, num_classes=26):
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(input_dim,)),
        tf.keras.layers.Dense(256, activation='relu'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.2),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

# Input:  (batch, 225)
# Output: (batch, 26)  — one per ASL letter
```

### ISL Model (Dynamic — 30 Frame Sequence)

```python
def build_isl_model(seq_len=30, input_dim=225, num_classes=10):
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(seq_len, input_dim)),
        tf.keras.layers.LSTM(64, return_sequences=True),
        tf.keras.layers.LSTM(128, return_sequences=False),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

# Input:  (batch, 30, 225)
# Output: (batch, 10)  — one per ISL gesture
```

### Export to TFLite

```python
def export_tflite(model, output_path):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    print(f"Saved: {output_path}")

export_tflite(asl_model, "models/asl_model.tflite")
export_tflite(isl_model, "models/isl_model.tflite")
```

---

## 🛡️ Anti-Spam Temporal Filter (Dart)

```dart
// temporal_filter.dart

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
```

---

## 🌐 Gemini Pro Integration (Dart)

```dart
// gemini_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  Future<TranslationResult> translateASL(List<String> letters) async {
    final joined = letters.join(' ');
    final prompt = '''
You are an ASL fingerspelling interpreter.
Detected letters: $joined
Reconstruct the most likely English words or sentence from these fingerspelled letters.
Also provide Tamil and Hindi translations.
Respond ONLY in this JSON format (no markdown, no extra text):
{"english": "", "tamil": "", "hindi": ""}
''';
    return _callGemini(prompt);
  }

  Future<TranslationResult> translateISL(List<String> gestures) async {
    final joined = gestures.join(', ');
    final prompt = '''
You are an ISL (Indian Sign Language) interpreter.
Detected gestures in sequence: $joined
Convert these ISL gesture labels to a natural English sentence.
Also provide Tamil and Hindi translations.
Respond ONLY in this JSON format (no markdown, no extra text):
{"english": "", "tamil": "", "hindi": ""}
''';
    return _callGemini(prompt);
  }

  Future<TranslationResult> _callGemini(String prompt) async {
    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 300,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      final json = jsonDecode(text);
      return TranslationResult(
        english: json['english'] ?? '',
        tamil: json['tamil'] ?? '',
        hindi: json['hindi'] ?? '',
      );
    }
    throw Exception('Gemini API failed: ${response.statusCode}');
  }
}

class TranslationResult {
  final String english;
  final String tamil;
  final String hindi;
  TranslationResult({
    required this.english,
    required this.tamil,
    required this.hindi,
  });
}
```

---

## 📦 Flutter pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Camera
  camera: ^0.10.5

  # MediaPipe (use Google's Flutter plugin)
  google_mediapipe: ^0.1.0            # or mediapipe_flutter
  # Alternative: use tflite_flutter and run MediaPipe as separate .task model

  # TFLite inference
  tflite_flutter: ^0.10.4

  # HTTP for Gemini
  http: ^1.2.0

  # Utilities
  path_provider: ^2.1.2               # for saving JSON data
  share_plus: ^7.2.2                  # for exporting collected data
  flutter_tts: ^3.8.5                 # text to speech for translations
  provider: ^6.1.2                    # state management
  lottie: ^3.0.0                      # loading animations

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

---

## 📊 Data Collection Format (JSON)

```json
{
  "metadata": {
    "label": "A",
    "type": "ASL",
    "total_samples": 100,
    "collector": "person_1",
    "date": "2025-01-01",
    "device": "Pixel 7",
    "camera": "back"
  },
  "samples": [
    {
      "frame_id": 0,
      "pose": [
        {"x": 0.12, "y": 0.34, "z": -0.01, "v": 0.99},
        ...
      ],
      "left_hand": null,
      "right_hand": [
        {"x": 0.45, "y": 0.67, "z": 0.02},
        ...
      ]
    }
  ]
}
```

**Save location on device:** `/Downloads/SignSpeak V2_data/ASL/A.json`  
**Transfer to PC:** ADB pull or Google Drive upload button in app

---

## 🐍 Python Training Pipeline

### Step 1: Preprocess + Normalize

```python
# preprocess.py
import json, os, numpy as np
from glob import glob

def load_dataset(data_dir, mode='ASL'):
    X, y, labels = [], [], []
    label_map = {}
    idx = 0

    for json_file in sorted(glob(f"{data_dir}/{mode}/*.json")):
        with open(json_file) as f:
            data = json.load(f)

        label = data['metadata']['label']
        if label not in label_map:
            label_map[label] = idx
            labels.append(label)
            idx += 1

        for sample in data['samples']:
            features = extract_features(
                sample['pose'],
                sample['left_hand'],
                sample['right_hand']
            )

            # Augment: add flipped version
            flipped = features.copy()
            # Flip X coords for hands (indices 100+ in our 225-vector)
            for i in range(100, 226, 3):
                flipped[i] = -flipped[i]

            X.append(features)
            y.append(label_map[label])
            X.append(flipped)
            y.append(label_map[label])

            # Add noise augmentation
            noisy = features + np.random.normal(0, 0.01, features.shape)
            X.append(noisy)
            y.append(label_map[label])

    return np.array(X), np.array(y), labels, label_map
```

### Step 2: Train ASL

```python
# train_asl.py
from preprocess import load_dataset
from sklearn.model_selection import train_test_split

X, y, labels, label_map = load_dataset('data', mode='ASL')
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)

model = build_asl_model(input_dim=225, num_classes=len(labels))
model.fit(
    X_train, y_train,
    validation_data=(X_test, y_test),
    epochs=50,
    batch_size=32,
    callbacks=[
        tf.keras.callbacks.EarlyStopping(patience=10),
        tf.keras.callbacks.ModelCheckpoint('models/asl_best.h5', save_best_only=True)
    ]
)
```

### Step 3: Train ISL (sequences)

```python
# train_isl.py
# ISL needs sequences: shape (num_samples, 30, 225)

def load_isl_sequences(data_dir, seq_len=30):
    X, y, labels = [], [], []
    label_map = {}
    idx = 0

    for json_file in sorted(glob(f"{data_dir}/ISL/*.json")):
        with open(json_file) as f:
            data = json.load(f)

        label = data['metadata']['label']
        if label not in label_map:
            label_map[label] = idx
            labels.append(label)
            idx += 1

        samples = data['samples']
        features_list = [
            extract_features(s['pose'], s['left_hand'], s['right_hand'])
            for s in samples
        ]

        # Sliding window sequences
        for i in range(0, len(features_list) - seq_len, 5):
            seq = features_list[i:i + seq_len]
            X.append(seq)
            y.append(label_map[label])

    return np.array(X), np.array(y), labels
```

---

## 🎯 ISL — 10 Gestures to Collect

| # | Gesture | Description |
      To Be Decided

---

## 🗓️ 1-Week Execution Plan

```
DAY 1 — Flutter Setup
  ✅ Create Flutter project structure
  ✅ Set up camera (back cam, landscape lock)
  ✅ Integrate MediaPipe Tasks plugin
  ✅ Build skeleton overlay widget
  ✅ Build data collection screen UI

DAY 2 — Data Collection  
  ✅ Collect ISL 10 gestures × 2 people × 80 samples = 1600 samples
  ✅ Collect ASL 26 letters × 1 person × 60 samples (supplement Kaggle)
  ✅ Export JSON → Google Drive → PC

DAY 3 — Python Training
  ✅ Preprocess + normalize all data
  ✅ Train ASL MLP model → export TFLite
  ✅ Train ISL LSTM model → export TFLite
  ✅ Validate accuracy (target: ASL >92%, ISL >88%)

DAY 4 — Flutter Inference
  ✅ Integrate TFLite models
  ✅ Implement TemporalFilter (anti-spam)
  ✅ Build recognition screen
  ✅ Test on real signing

DAY 5 — Gemini Integration
  ✅ Build GeminiService
  ✅ Build translation screen
  ✅ Wire: buffer → translate button → Gemini → display
  ✅ Add Text-to-Speech for translations

DAY 6 — Testing + Polish
  ✅ Tune confidence thresholds
  ✅ Fix edge cases (no hand detected, one hand)
  ✅ Polish UI, add loading states
  ✅ Test with 3+ people signing

DAY 7 — Demo Prep
  ✅ Record demo video
  ✅ Prepare slides/documentation
  ✅ Final bug fixes
  ✅ APK build + install
```

---

## ⚠️ Common Issues + Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| Spam detection | No temporal filter | Implement TemporalFilter class |
| Wrong hand detected | No normalization | Wrist-relative + scale normalize |
| Pose not visible | Camera too close | Hold phone 1.2–1.5m from signer |
| Low ISL accuracy | Not enough sequence context | Increase seq_len to 40 frames |
| Front/back flip issue | Used front cam for data | Only use back cam for everything |
| Model not loading | Wrong TFLite input shape | Verify input (1,225) for ASL, (1,30,225) ISL |
| Gemini slow | Calling every frame | Only call on button tap or 3s silence |
| One hand missing | Occlusion | Augment with single-hand samples |

---

## 📐 Camera Setup Guidelines for Collection

```
CORRECT SETUP:
──────────────────────────────
        📱 (phone held by friend)
        ↓ back camera pointing at signer
        
🧑 [signing person]
  - Full upper body visible
  - Both arms + hands in frame
  - Plain/light background preferred
  - Good lighting (face front-lit)
  - Distance: 1.2m to 1.5m from phone
  - Phone height: chest to eye level

WHAT SHOULD BE VISIBLE IN FRAME:
  ✅ Both shoulders
  ✅ Both arms fully
  ✅ Both hands clearly
  ✅ Face (for future facial grammar)
  ❌ Don't fill frame with just hand
  ❌ Don't stand 3m away (hands too small)
```

---

## 🔑 Environment Variables

Create `.env` file in Flutter project root (use `flutter_dotenv`):

```
GEMINI_API_KEY=your_gemini_pro_api_key_here
ASL_MODEL_PATH=assets/models/asl_model.tflite
ISL_MODEL_PATH=assets/models/isl_model.tflite
ASL_CONFIDENCE_THRESHOLD=0.88
ISL_CONFIDENCE_THRESHOLD=0.85
COOLDOWN_MS=1200
HOLD_FRAMES=12
BUFFER_SIZE=15
```

---

## ✅ Definition of Done

- [ ] Data collection screen works on back camera with auto-capture
- [ ] ASL: 26 letters recognized with >90% accuracy
- [ ] ISL: 10 gestures recognized with >85% accuracy  
- [ ] No spam detection (temporal filter working)
- [ ] Gemini translates to English + Tamil + Hindi
- [ ] TTS reads out translation
- [ ] APK installable and demo-ready
- [ ] Works for at least 2 different people's signing styles

---

*Generated for SignSpeak V2 project — ASL & ISL Recognition App*
*Stack: Flutter + MediaPipe Tasks + TFLite + Gemini Pro*
