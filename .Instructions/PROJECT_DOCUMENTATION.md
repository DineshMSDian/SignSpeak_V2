# SignSpeak V2 — Project Documentation
> **HOW THIS FILE WORKS:**
> Every time the agent adds a feature, fixes a bug, or makes a decision — it MUST update this file immediately.
> This is your single source of truth for project review, viva, or presentation.
> Never leave this file outdated.

---

## 📋 Project Identity

| Field | Detail |
|-------|--------|
| **Project Name** | SignSpeak V2 |
| **Purpose** | Real-time ASL (26 letters) + ISL (10 gestures) recognition with multilingual translation |
| **Platform** | Flutter (Android/iOS) |
| **Camera Used** | Back camera only |
| **AI Models** | TFLite on-device (MLP for ASL, LSTM for ISL) |
| **Translation API** | Gemini Pro |
| **Started** | 2026-03-28 |
| **Last Updated** | 2026-03-28 |

---

## 👥 Team & Roles

| Name | Role |
|------|------|
| — | — |

---

## 🗂️ Table of Contents

1. [Tech Stack](#tech-stack)
2. [Folder Structure](#folder-structure)
3. [Feature Log](#feature-log) ← agent updates this every step
4. [Screen Documentation](#screen-documentation)
5. [ML Model Documentation](#ml-model-documentation)
6. [Data Collection Process](#data-collection-process)
7. [API Integrations](#api-integrations)
8. [Known Issues & Fixes](#known-issues--fixes)
9. [References](#references)
10. [Glossary](#glossary)

---

## 🛠️ Tech Stack

| Layer | Technology | Why This Was Chosen |
|-------|-----------|---------------------|
| Mobile Framework | Flutter (Dart) | Cross-platform, good camera plugin support |
| Landmark Detection | MediaPipe Tasks API (new) | Replaced legacy mediapipe, better accuracy, works on mobile |
| Pose Estimation | MediaPipe Pose Landmarker | Captures shoulder/arm context — needed for ISL |
| Hand Tracking | MediaPipe Hand Landmarker | 21 landmarks per hand, both hands tracked |
| ASL Model | TFLite MLP | Static sign = single frame = simple MLP enough |
| ISL Model | TFLite LSTM | Dynamic gesture = sequence of frames = LSTM needed |
| Translation | Gemini Pro API | Converts letters/gestures to natural language + Tamil/Hindi |
| Training | Python + TensorFlow/Keras | Standard ML training pipeline |
| State Management | Provider | Lightweight, sufficient for this app |
| TTS | flutter_tts | Speaks out translation result |

---

## 📁 Folder Structure

> Agent: Update this section whenever a new file or folder is created.

```
SignSpeak V2/
│
├── lib/
│   ├── main.dart                        # App entry point (SignBridgeApp)
│   ├── screens/
│   │   ├── home_screen.dart             # Landing page, mode selector
│   │   ├── collection_screen.dart       # Data collection UI
│   │   ├── recognition_screen.dart      # Live sign recognition
│   │   └── translation_screen.dart      # Gemini translation output
│   │
│   ├── services/
│   │   ├── mediapipe_service.dart       # Runs landmark detection
│   │   ├── tflite_service.dart          # Loads + runs TFLite models
│   │   ├── temporal_filter.dart         # Anti-spam prediction filter (IMPLEMENTED)
│   │   └── gemini_service.dart          # Gemini Pro API calls
│   │
│   ├── models/
│   │   ├── landmark_data.dart           # Data class for landmarks
│   │   └── prediction_result.dart       # Data class for model output
│   │
│   └── widgets/
│       ├── skeleton_overlay.dart        # Draws bones on camera feed
│       └── gesture_badge.dart           # Floating prediction card
│
├── assets/
│   ├── models/
│   │   └── README.md                    # TFLite models go here after training
│   └── labels/
│       ├── asl_labels.txt               # A-Z labels (26 letters)
│       └── isl_labels.txt               # 10 ISL gesture names
│
├── python_training/
│   ├── preprocess.py                    # Normalize + augment landmarks
│   ├── train_asl.py                     # Train MLP for ASL
│   ├── train_isl.py                     # Train LSTM for ISL
│   ├── export_tflite.py                 # Convert .h5 → .tflite
│   ├── data/
│   │   ├── asl_raw/                     # JSON collected from mobile
│   │   └── isl_raw/                     # JSON collected from mobile
│   └── models/                          # Trained .h5 and .tflite files
│
├── .env                                 # API keys (NOT committed to git)
├── .gitignore                           # Excludes .env, .tflite, data, build
├── pubspec.yaml                         # Flutter dependencies
└── .Instructions/
    ├── ASL_ISL_PROJECT_INSTRUCTIONS.md  # Master architecture reference
    ├── COMMIT_STYLE_GUIDE.md            # Commit message format
    └── PROJECT_DOCUMENTATION.md         # This file
```

---

## 📝 Feature Log

> **AGENT INSTRUCTION:** Every time you complete a step, add a new entry here.
> Fill in: what was done, which files were created/modified, why this decision was made.
> Do NOT skip this. This is the most important section.

---

### Step 1 — Project Initialization
- **Status:** ✅ Done
- **Date:** 2026-03-28
- **What was done:** Initialized complete Flutter project structure. Replaced default counter app with SignBridge app entry point. Created all screen placeholders, service files, model data classes, and widget files as defined in the architecture spec. Set up python_training directory with placeholder scripts and data directories. Created asset directories for models and labels.
- **Files created/modified:**
  - `lib/main.dart` — app entry point, dark theme, routes to HomeScreen
  - `lib/screens/home_screen.dart` — placeholder
  - `lib/screens/collection_screen.dart` — placeholder
  - `lib/screens/recognition_screen.dart` — placeholder
  - `lib/screens/translation_screen.dart` — placeholder
  - `lib/services/mediapipe_service.dart` — placeholder
  - `lib/services/tflite_service.dart` — placeholder
  - `lib/services/temporal_filter.dart` — **FULLY IMPLEMENTED** (4-layer anti-spam pipeline)
  - `lib/services/gemini_service.dart` — placeholder + TranslationResult class
  - `lib/models/landmark_data.dart` — LandmarkPoint + LandmarkData classes
  - `lib/models/prediction_result.dart` — PredictionResult + SignMode enum
  - `lib/widgets/skeleton_overlay.dart` — placeholder CustomPainter
  - `lib/widgets/gesture_badge.dart` — placeholder confidence badge
  - `assets/labels/asl_labels.txt` — 26 ASL letters A-Z
  - `assets/labels/isl_labels.txt` — 10 ISL gesture names
  - `assets/models/README.md` — placeholder for TFLite models
  - `python_training/preprocess.py` — placeholder
  - `python_training/train_asl.py` — placeholder
  - `python_training/train_isl.py` — placeholder
  - `python_training/export_tflite.py` — placeholder
  - `python_training/data/asl_raw/README.md`
  - `python_training/data/isl_raw/README.md`
  - `python_training/models/README.md`
- **Why:** Clean architecture from the start — separated concerns into screens, services, models, widgets. Temporal filter implemented early because it was the #1 bug in the original SignSpeak project.
- **Notes:** Project uses `signspeak_v2` as package name. App displays as "SignBridge".

---

### Step 2 — pubspec.yaml & Dependencies
- **Status:** ✅ Done
- **Date:** 2026-03-28
- **What was done:** Configured pubspec.yaml with all required dependencies and declared asset directories. Ran `flutter pub get` — all dependencies resolved successfully.
- **Files created/modified:** `pubspec.yaml`
- **Dependencies added:**

| Package | Version | Purpose |
|---------|---------|--------|
| camera | ^0.11.1 | Back camera access |
| tflite_flutter | ^0.11.0 | On-device TFLite inference |
| http | ^1.3.0 | Gemini API calls |
| provider | ^6.1.2 | State management |
| flutter_tts | ^4.2.0 | Read out translations |
| path_provider | ^2.1.5 | Save JSON data files |
| share_plus | ^10.1.4 | Export collected data |
| flutter_dotenv | ^5.2.1 | Load .env file (API keys) |
| lottie | ^3.3.1 | Loading animations |

- **Notes:** Assets declared: `assets/models/`, `assets/labels/`, `.env`

---

### Step 3 — Folder Structure Setup
- **Status:** ✅ Done
- **Date:** 2026-03-28
- **What was done:** Created complete folder structure matching the architecture spec. All directories: `lib/screens/`, `lib/services/`, `lib/models/`, `lib/widgets/`, `assets/models/`, `assets/labels/`, `python_training/`, `python_training/data/asl_raw/`, `python_training/data/isl_raw/`, `python_training/models/`.
- **Files created/modified:** All 23 files listed in Step 1 above.
- **Notes:** Steps 1, 2, and 3 were done together as a single project initialization pass. Updated `.gitignore` to exclude `.env`, `*.tflite`, `*.h5`, `__pycache__/`, `build/`, `.dart_tool/`, python training data/models, and IDE files.

---

### Step 4 — Camera Integration
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** —
- **Key decision:** Back camera only — front camera causes horizontal flip of landmarks which breaks model predictions
- **Notes:** —

---

### Step 5 — MediaPipe Tasks Integration
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/services/mediapipe_service.dart`
- **Key decision:** Using new MediaPipe Tasks API (not legacy mp.solutions)
- **Why new API:**
  - Legacy API deprecated
  - New API uses `.task` model files — faster, smaller
  - Works natively on mobile without Python dependency
- **Landmarks extracted:**
  - Pose: landmarks 0–24 (upper body only)
  - Left hand: 21 landmarks
  - Right hand: 21 landmarks
  - Total: 225 features per frame
- **Notes:** —

---

### Step 6 — Landmark Normalization
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/services/mediapipe_service.dart`
- **Why normalization is critical:**
  - Raw x,y,z coordinates depend on where the person stands and how far from camera
  - Without normalization: same gesture at different distances = different features = model confused
  - With normalization: position & scale invariant = model sees same gesture always same way
- **How it works:**
  - Hand: move wrist to origin (0,0,0), divide all points by distance to middle finger MCP
  - Pose: make all points relative to nose landmark
- **Notes:** —

---

### Step 7 — Skeleton Overlay Widget
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/widgets/skeleton_overlay.dart`
- **What it shows:** Green dots on hand joints, blue lines for pose bones, drawn on top of camera feed using Stack + CustomPainter
- **Notes:** —

---

### Step 8 — Data Collection Screen
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/screens/collection_screen.dart`
- **Features:**
  - Auto-captures every 500ms when confidence > 0.85
  - Shows live camera + skeleton overlay
  - Progress bar (samples collected / 100)
  - Skip gesture button
  - Export to JSON button
- **Why mobile collection instead of laptop:**
  - Laptop front cam = mirrored image = flipped X coordinates = model trained on wrong data
  - Mobile back cam = same camera as inference = zero mismatch
  - Pose capture needs full body in frame — easier with someone holding phone than sitting at laptop
- **Notes:** —

---

### Step 9 — JSON Export & Transfer to PC
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/services/collection_screen.dart`
- **Export format:** `/Downloads/SignSpeak V2_data/{ASL or ISL}/{label}.json`
- **Transfer method:** Google Drive share button or ADB pull
- **Notes:** —

---

### Step 10 — Python: Preprocessing & Augmentation
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `python_training/preprocess.py`
- **Augmentations applied:**
  - Horizontal flip (simulates opposite hand dominance)
  - Gaussian noise (simulates real-world jitter)
  - Result: 3× data from original samples
- **Notes:** —

---

### Step 11 — Python: Train ASL Model
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `python_training/train_asl.py`
- **Model type:** MLP (Multi-Layer Perceptron)
- **Why MLP for ASL:** ASL letters are static — one frame is enough — no time sequence needed — simple dense layers work well
- **Architecture:**
  ```
  Input(225) → Dense(256, relu) → BN → Dropout(0.3)
             → Dense(128, relu) → BN → Dropout(0.2)
             → Dense(64, relu)
             → Dense(26, softmax)
  ```
- **Training result:**
  - Val accuracy: —
  - Val loss: —
  - Epochs trained: —
- **Notes:** —

---

### Step 12 — Python: Train ISL Model
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `python_training/train_isl.py`
- **Model type:** LSTM (Long Short-Term Memory)
- **Why LSTM for ISL:** ISL gestures are dynamic — they involve movement over time — a single frame cannot capture a waving or nodding motion — LSTM processes sequences of 30 frames (1 second)
- **Architecture:**
  ```
  Input(30, 225) → LSTM(64, return_seq=True)
                 → LSTM(128)
                 → Dense(64, relu) → Dropout(0.3)
                 → Dense(10, softmax)
  ```
- **Training result:**
  - Val accuracy: —
  - Val loss: —
  - Epochs trained: —
- **Notes:** —

---

### Step 13 — Export Models to TFLite
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `python_training/export_tflite.py`, `assets/models/asl_model.tflite`, `assets/models/isl_model.tflite`
- **Optimization:** DEFAULT quantization (reduces file size ~2×, minimal accuracy drop)
- **ASL model size:** —
- **ISL model size:** —
- **Notes:** —

---

### Step 14 — TFLite Service in Flutter
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/services/tflite_service.dart`
- **ASL inference:** takes 1 frame (225 features) → returns letter + confidence
- **ISL inference:** takes 30 frames (30×225) → returns gesture + confidence
- **Important fix:** All inputs converted to Float32 — Dart uses Float64 by default which causes silent wrong outputs in TFLite
- **Notes:** —

---

### Step 15 — Temporal Filter (Anti-Spam)
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/services/temporal_filter.dart`
- **Why this was needed:** Without filtering, the model fires a prediction every single frame → spams the same letter/gesture hundreds of times per second
- **4-layer filter pipeline:**

| Layer | Setting | What it does |
|-------|---------|-------------|
| Confidence gate | > 0.88 | Ignores low-confidence predictions |
| Majority vote | 10 out of 15 frames agree | Ignores flickering predictions |
| Hold duration | 12 consecutive frames | Gesture must be held, not flashed |
| Cooldown | 1.2 seconds | Min gap between two fired predictions |

- **Notes:** —

---

### Step 16 — Recognition Screen
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/screens/recognition_screen.dart`
- **Features:**
  - Live camera + skeleton overlay
  - Rolling letter/gesture buffer shown on screen
  - Confidence bar per detection
  - Mode toggle (ASL / ISL)
  - Translate button → goes to translation screen
  - Auto-translate after 3s silence
  - Clear buffer button
- **Notes:** —

---

### Step 17 — Gemini Pro Service
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/services/gemini_service.dart`
- **ASL prompt logic:** Sends fingerspelled letters → asks Gemini to reconstruct words + translate to Tamil + Hindi
- **ISL prompt logic:** Sends gesture label sequence → asks Gemini to form natural sentence + translate
- **Temperature:** 0.2 (low = more consistent, deterministic output)
- **When it fires:** Only on button tap OR after 3s of no new detection (NOT on every frame)
- **Notes:** —

---

### Step 18 — Translation Screen
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/screens/translation_screen.dart`
- **Shows:** English result, Tamil result, Hindi result
- **TTS:** Speaks out English translation on tap
- **Notes:** —

---

### Step 19 — Home Screen + Model Status
- **Status:** ⬜ Pending
- **Date:** —
- **What was done:** —
- **Files created/modified:** `lib/screens/home_screen.dart`
- **Notes:** —

---

### Step 20 — Final Testing & Threshold Tuning
- **Status:** ⬜ Pending
- **Date:** —
- **ASL accuracy on real use:** —
- **ISL accuracy on real use:** —
- **Threshold adjustments made:** —
- **Tested with N people:** —
- **Notes:** —

---

## 🖥️ Screen Documentation

### Screen 1: Home Screen
- **File:** `lib/screens/home_screen.dart`
- **Purpose:** Entry point. Shows model load status, mode selector (ASL/ISL), navigation to recognition and data collection.
- **State managed:** which mode is active (ASL or ISL)

### Screen 2: Data Collection Screen
- **File:** `lib/screens/collection_screen.dart`
- **Purpose:** Collect training data using back camera. Auto-saves landmark JSONs to device storage.
- **Who uses this:** Developer/team only. Not for end users.
- **State managed:** current gesture label, sample count, capture active/paused

### Screen 3: Recognition Screen
- **File:** `lib/screens/recognition_screen.dart`
- **Purpose:** Main user screen. Live sign detection with anti-spam filter. Builds up letter/gesture buffer.
- **State managed:** landmark buffer, prediction buffer, temporal filter state, letter history

### Screen 4: Translation Screen
- **File:** `lib/screens/translation_screen.dart`
- **Purpose:** Calls Gemini Pro and displays translated output in English, Tamil, Hindi.
- **State managed:** loading state, translation result, TTS state

---

## 🤖 ML Model Documentation

### ASL Model

| Field | Value |
|-------|-------|
| Type | MLP (Multi-Layer Perceptron) |
| Input | Single frame — 225 features |
| Output | 26 classes (A–Z) |
| Framework | TensorFlow/Keras → TFLite |
| File | `assets/models/asl_model.tflite` |
| Val Accuracy | — (fill after training) |
| Training Samples | — |

**Why MLP and not LSTM for ASL:**
ASL fingerspelling letters are static hand shapes. The letter "A" looks the same whether you hold it for 1 second or 5 seconds. A single frame of landmark data contains all information needed. LSTM would be overkill and slower.

---

### ISL Model

| Field | Value |
|-------|-------|
| Type | LSTM (Long Short-Term Memory) |
| Input | 30 frame sequence — shape (30, 225) |
| Output | 10 classes (ISL gestures) |
| Framework | TensorFlow/Keras → TFLite |
| File | `assets/models/isl_model.tflite` |
| Val Accuracy | — (fill after training) |
| Training Samples | — |

**Why LSTM for ISL:**
ISL gestures involve movement — waving, nodding, circular motions. A single frame cannot tell you if a hand is moving up or down or in circles. LSTM processes 30 consecutive frames (1 second at 30fps) and learns the temporal pattern of the gesture.

---

### Feature Vector (225 dimensions)

```
[0–99]    Pose landmarks 0–24 (upper body)
          Each landmark: x, y, z, visibility = 4 values × 25 = 100

[100–162] Left hand landmarks 0–20
          Each landmark: x, y, z (wrist-relative) = 3 values × 21 = 63

[163–225] Right hand landmarks 0–20
          Each landmark: x, y, z (wrist-relative) = 3 values × 21 = 63
```

**Normalization applied:**
- Pose: all points relative to nose (landmark 0)
- Hands: wrist moved to origin, scale divided by distance wrist→middle MCP (landmark 9)

---

## 📸 Data Collection Process

### Who collected data
- Person 1: —
- Person 2: —

### Setup
- Camera: Back camera of [device name]
- Distance from camera: 1.2–1.5 meters
- Background: Plain light wall
- Lighting: Natural daylight / indoor light

### ASL Collection

| Letter | Samples | Collected By | Date |
|--------|---------|-------------|------|
| A | — | — | — |
| B | — | — | — |
| C | — | — | — |
| ... | | | |

### ISL Collection

| Gesture | Description | Samples | Collected By | Date |
|---------|-------------|---------|-------------|------|
| NAMASTE | Both palms together | — | — | — |
| HELLO | Open palm wave | — | — | — |
| THANK_YOU | Right hand from lips outward | — | — | — |
| YES | Fist nodding motion | — | — | — |
| NO | Index finger side to side | — | — | — |
| HELP | Fist on open palm, lifted up | — | — | — |
| PLEASE | Circular hand on chest | — | — | — |
| SORRY | Fist circular on chest | — | — | — |
| GOOD | Thumbs up | — | — | — |
| BAD | Thumbs down | — | — | — |

---

## 🔌 API Integrations

### Gemini Pro API

| Field | Detail |
|-------|--------|
| Provider | Google AI (generativelanguage.googleapis.com) |
| Model | gemini-pro |
| Auth | API key in .env file |
| Called from | `lib/services/gemini_service.dart` |
| Trigger | Button tap or 3s silence |
| Input (ASL) | Space-separated fingerspelled letters |
| Input (ISL) | Comma-separated gesture labels |
| Output | JSON with english, tamil, hindi fields |
| Temperature | 0.2 |
| Max tokens | 300 |

**ASL Prompt template:**
```
You are an ASL fingerspelling interpreter.
Detected letters: {letters}
Reconstruct the most likely English words.
Also provide Tamil and Hindi translations.
Respond ONLY in JSON: {"english": "", "tamil": "", "hindi": ""}
```

**ISL Prompt template:**
```
You are an ISL (Indian Sign Language) interpreter.
Detected gestures in sequence: {gestures}
Convert to a natural English sentence.
Also provide Tamil and Hindi translations.
Respond ONLY in JSON: {"english": "", "tamil": "", "hindi": ""}
```

---

## 🐛 Known Issues & Fixes

> Agent: Add an entry here every time a bug is found and fixed.

| # | Bug | Cause | Fix | File |
|---|-----|-------|-----|------|
| 1 | — | — | — | — |

---

## 📚 References

> Agent: Add a reference every time you use an external source for code or decisions.

| # | What it was used for | Source |
|---|---------------------|--------|
| 1 | MediaPipe Tasks Python API | https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker/python |
| 2 | MediaPipe Pose Landmarker | https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker |
| 3 | TFLite Flutter plugin | https://pub.dev/packages/tflite_flutter |
| 4 | Gemini API docs | https://ai.google.dev/gemini-api/docs |
| 5 | LSTM for action detection (YouTube) | Nicholas Renotte — Action Detection tutorial |
| 6 | Flutter camera plugin | https://pub.dev/packages/camera |
| 7 | Previous project (SignSpeak) | https://github.com/DineshMSDian/SignSpeak |

---

## 📖 Glossary

| Term | Meaning |
|------|---------|
| **ASL** | American Sign Language — uses 26 static hand shapes for A–Z |
| **ISL** | Indian Sign Language — uses full body gestures, dynamic movements |
| **MediaPipe** | Google's ML framework for detecting body, hands, face in images |
| **Landmark** | A specific joint or point on the body tracked by MediaPipe (e.g. wrist, knuckle) |
| **TFLite** | TensorFlow Lite — compressed ML models that run on mobile devices |
| **MLP** | Multi-Layer Perceptron — simple neural network, good for static inputs |
| **LSTM** | Long Short-Term Memory — neural network that understands sequences over time |
| **Feature vector** | The flattened array of all landmark coordinates fed into the model |
| **Normalization** | Adjusting landmark coordinates so they are position/scale independent |
| **Temporal filter** | Logic that prevents the model from spamming repeated predictions |
| **Majority vote** | Only fire a prediction when most recent frames all agree on same result |
| **Confidence** | How sure the model is (0.0–1.0). We only accept predictions above 0.88 |
| **TFLite quantization** | Compressing model weights from 32-bit to 8-bit — smaller file, same accuracy |
| **Sequence length** | Number of consecutive frames fed to LSTM — we use 30 frames (1 second) |
| **Pose landmarks** | 33 body joint points tracked by MediaPipe Pose |
| **Gemini Pro** | Google's large language model API used here for translation |
| **Back camera** | Rear-facing camera — used for both collection and inference to avoid flip issues |
| **Flip issue** | Front camera mirrors the image — X coordinates reversed — breaks model trained on back cam data |

---

## ✅ Project Checklist

- [x] Flutter project created
- [x] Dependencies added (pubspec.yaml)
- [ ] Back camera working
- [ ] MediaPipe hands + pose running
- [ ] Landmark normalization implemented
- [ ] Skeleton overlay on camera feed
- [ ] Data collection screen built
- [ ] JSON export working
- [ ] Python training pipeline working
- [ ] ASL model trained (target: >90% accuracy)
- [ ] ISL model trained (target: >85% accuracy)
- [ ] Both models exported to TFLite
- [ ] TFLite models integrated in Flutter
- [ ] Temporal filter working (no spam)
- [ ] Recognition screen working
- [ ] Gemini API integrated
- [ ] Translation screen working
- [ ] TTS working
- [ ] Tested with 2+ signers
- [ ] APK built and installable
- [ ] Demo ready

---

*SignSpeak V2 — ASL & ISL Recognition Project*
*Documentation maintained by: AI Agent (Antigravity)*
*For project review reference only*
