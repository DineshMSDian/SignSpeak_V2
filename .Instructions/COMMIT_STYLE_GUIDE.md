# Commit Message Style Guide — SignBridge Project
> Reference this when writing commit messages. Keep it human, keep it YOU.

---

## Your Commit DNA (from SignSpeak history)

```
SignBridge: [Short title in Title Case or lowercase mix]

- bullet point 1 explaining what changed
- bullet point 2 why it was needed
- sometimes a typo is fine, dont stress

NOTES FOR ME: (optional, when you want to remember something)
explanation of why you did this
technical reasoning in casual tone

Source: (if you referenced something)
    Claude 😅  /  GeeksForGeeks link  /  official docs
```

---

## Full Commit Sequence — Copy & Paste Ready

Use `git commit` (opens editor) or `git commit -m "title" -m "body"`

---

### 🔰 Project Init

```
SignBridge: Initializing project — Flutter + MediaPipe fresh start

starting from scratch cuz the old mediapipe legacy was a mess
new stack: Flutter (mobile) + MediaPipe Tasks API + TFLite + Gemini Pro

Source:
    previous SignSpeak project (learned what NOT to do lol)
```

```
SignBridge: add pubspec.yaml with all required dependencies

camera, tflite_flutter, mediapipe, http, provider — the whole gang
also added flutter_tts for speaking out translations

NOTES FOR ME:
tflite_flutter needs special setup on android, check NDK version
```

---

### 📁 Project Structure

```
SignBridge: setup folder structure for screens, services and models

created screens/, services/, models/, widgets/ under lib/
assets/models/ for tflite files, assets/labels/ for label txts

- following clean architecture so it doesnt become spaghetti like before
```

---

### 📷 Camera Setup

```
SignBridge: [1/4] implementing back camera with CameraX

back camera only — this is important
front cam caused flip issues in SignSpeak, not repeating that mistake

NOTES FOR ME:
back camera = what the user points at someone else signing
inference and data collection BOTH use back cam = no coordinate mismatch
```

```
SignBridge: [2/4] lock orientation and set camera resolution

locked to portrait mode
set resolution to 720p — good balance between landmark quality and speed

- lower res = faster mediapipe inference
- 720p gives enough detail for hand landmarks to be accurate
```

```
SignBridge: [3/4] camera preview renders to flutter widget

used CameraPreview inside a Stack so we can overlay skeleton later
wrapped in AspectRatio to prevent stretching

Source:
    Flutter camera plugin docs
```

```
SignBridge: [4/4] camera permissions handled for android and ios

added camera permission in AndroidManifest.xml and Info.plist
shows permission dialog on first launch, handles denial gracefully

- if denied: shows a snackbar "camera permission required"
- doesnt crash anymore if user says no lol
```

---

### 🦴 MediaPipe Integration

```
SignBridge: [1/3] integrating mediapipe tasks — hand + pose landmarker

moved from legacy mp.solutions (old) to new MediaPipe Tasks API
uses .task model files instead of the old python mediapipe

NOTES FOR ME:
new API is completely different from what we used in SignSpeak
no more mp.solutions.holistic — now its separate task files
Hand Landmarker + Pose Landmarker run independently
```

```
SignBridge: [2/3] extracting pose + both hand landmarks per frame

upper body pose: landmarks 0-24 (skipping legs, not needed)
left hand: 21 landmarks, right hand: 21 landmarks
total = 67 landmarks = 225 features after flattening

- added null checks for when hands go offscreen
- zero-padding when hand not detected (same as SignSpeak fix)

NOTES FOR ME:
pose gives us shoulder + elbow context = important for ISL
hand-only was the reason ISL was bad in SignSpeak
```

```
SignBridge: [3/3] normalize landmarks — wrist relative + scale normalize

this is the big fix from our old project
raw coordinates depend on where you stand → model gets confused
normalized coords are position and distance invariant

- wrist moved to origin (0,0,0)  
- scale normalized by middle finger MCP distance
- pose normalized relative to nose landmark

Source:
    Claude 😅
```

---

### 🖼️ Skeleton Overlay

```
SignBridge: skeleton overlay widget — draws landmarks on camera feed

CustomPainter draws dots on hand + pose landmarks
green dots for hands, blue for pose connections
renders on top of camera preview using Stack widget

- only draws when landmarks are detected
- skips drawing when confidence is below 0.5
```

---

### 📦 Data Collection Screen

```
SignBridge: data collection screen UI — basic layout

screen has: camera feed, gesture label, sample counter, progress bar
auto-capture toggle, skip button, export button
back camera only — same as inference screen

NOTES FOR ME:
this screen is how we replace the laptop data collection from SignSpeak
mobile back cam = no front cam flip problem
someone holds the phone, other person signs in front
```

```
SignBridge: auto-capture logic — saves sample every 500ms

captures landmark data automatically while pose+hand confidence > 0.85
no need to tap for every sample, just hold the sign

- Timer.periodic fires every 500ms
- checks if both pose AND hand detected before saving
- increments counter, moves to next gesture at 100 samples

NOTES FOR ME:
100 samples per gesture × 36 classes (26 ASL + 10 ISL) = 3600 samples
with augmentation (flip + noise) = ~10800 effective samples
should be enough for decent accuracy
```

```
SignBridge: save collected data as JSON to device downloads

each gesture saves to /Downloads/signbridge_data/ASL/A.json
format: metadata + array of samples with pose + left_hand + right_hand

- added share button to upload directly to google drive
- can also ADB pull the files to PC for training

NOTES FOR ME:
transfer JSON to PC → run python training → get .tflite → put back in assets/
```

```
SignBridge: confidence gate — only save high quality samples

added validation before saving each frame
requires: pose_confidence > 0.8 AND at least one hand detected
discards bad frames silently (no error shown to user)

- inspired by the hand absence detection fix in SignSpeak (commit 3388591)
- MIN_HAND_FRAMES check same idea but per-sample not per-sequence
```

---

### 🧠 TFLite Model Integration

```
SignBridge: load ASL and ISL tflite models from assets

both models loaded on app init
ASL input shape: (1, 225) — single frame
ISL input shape: (1, 30, 225) — 30 frame sequence

- added error handling if model file missing
- shows "Model not loaded" badge on home screen

NOTES FOR ME:
model files go in assets/models/
remember to declare them in pubspec.yaml under flutter: assets:
```

```
SignBridge: ASL inference — single frame MLP prediction

takes 1 frame of landmarks (225 features)
runs through tflite ASL model
returns letter + confidence score

- output is 26 floats (one per letter A-Z)
- argmax gives predicted class
- confidence = that max value
```

```
SignBridge: ISL inference — 30 frame sequence LSTM prediction

maintains a rolling buffer of last 30 frames
when buffer full, runs LSTM model
returns gesture label + confidence

NOTES FOR ME:
ISL is dynamic (involves movement over time)
cant use single frame like ASL — needs sequence of frames
30 frames at 30fps = 1 second of signing
```

---

### 🛡️ Anti-Spam Temporal Filter

```
SignBridge: temporal filter — fixes the spam detection from SignSpeak

this was the main bug in our old project — random spamming of letters
implemented 4-layer filter: majority vote + confidence gate + hold + cooldown

- majority vote: 10/15 frames must agree on same prediction
- confidence gate: prediction confidence must be > 0.88
- hold duration: must hold gesture for 12 consecutive frames  
- cooldown: 1.2s between any two fired predictions

NOTES FOR ME:
SignSpeak was firing on every single frame with no filtering
this is literally THE fix. everything else is secondary.

Source:
    Claude 😅
```

---

### 🌐 Gemini Pro Translation

```
SignBridge: gemini service — translates ASL letters to words

calls Gemini Pro API with accumulated fingerspelled letters
prompt asks for: english word reconstruction + tamil + hindi translation
returns JSON with all three languages

- only calls API on button tap (not every frame, not every letter)
- also auto-triggers after 3 seconds of no new detection

NOTES FOR ME:
Gemini API key goes in .env file — dont commit the key lol
using gemini-pro model, temperature 0.2 (more deterministic output)
```

```
SignBridge: gemini service — ISL gesture sequence translation

separate prompt for ISL — sends gesture labels like "NAMASTE, HELLO, GOOD"
asks Gemini to convert gesture sequence to natural English sentence
also gets tamil and hindi output

Source:
    Claude 😅 (prompt engineering mostly)
```

---

### 🎨 Translation Screen

```
SignBridge: translation screen — displays gemini output in 3 languages

three cards: English, Tamil, Hindi
each card has language flag emoji + translated text
TTS button speaks out the english translation

- loading spinner while waiting for Gemini API response
- error state if API call fails (shows retry button)
```

---

### 🐛 Bug Fixes

```
fix: pose not capturing when hand goes offscreen

when hand leaves frame, pose landmarks still valid
was resetting entire feature vector to zeros when hand missing
now only zero-pads the missing hand portion, keeps pose data intact

- fixed NullPointerException crash on rapid hand movement
```

```
fix: ISL sequence buffer not resetting between gestures

after a gesture fires, buffer kept old frames
next gesture prediction was contaminated with previous gesture frames
now clears buffer immediately after firing a prediction

NOTES FOR ME:
this was causing ISL to misclassify the second gesture every time
```

```
fix: tflite model input shape mismatch on android

float32 vs float64 issue — dart uses float64 by default
tflite expects float32
added explicit .toFloat32List() conversion before inference

- was silently producing garbage output, not an obvious crash
- spent way too long on this one 💀
```

```
fix: gemini returns markdown json with backticks sometimes

gemini wraps response in ```json ... ``` sometimes
json.decode was throwing FormatException
added strip/regex to clean response before parsing

Source:
    Claude 😅
```

```
fix: camera black screen on some android devices

camera2 API compatibility issue on older androids (API 24-27)
added fallback to legacy camera1 API
tested on Pixel 6 (works), Samsung A52 (works now)
```

---

### ✨ UI Polish

```
SignBridge: gesture badge widget — shows current prediction with animation

small floating card at bottom of camera feed
shows: letter/gesture name + confidence percentage + color coded bar
green if confidence > 0.88, yellow 0.7-0.88, hidden below 0.7
```

```
SignBridge: home screen — model status indicator

shows green tick if both ASL and ISL models loaded successfully
shows red warning if model file missing from assets
user knows immediately if something is wrong before trying to sign
```

---

### 📊 Training Scripts (commit from PC after training)

```
SignBridge: python preprocessing — normalize + augment collected data

loads all JSON files from data/ASL/ and data/ISL/
applies wrist-relative normalization and scale normalization
augments with: horizontal flip + gaussian noise (3x data)

- saves processed numpy arrays to data/processed/
```

```
SignBridge: trained ASL model — MLP, 94% validation accuracy

3-layer MLP: Dense(256) → Dense(128) → Dense(64) → Dense(26)
trained on 7800 samples (100 per class × 3 augmentations)
val accuracy: 94.2%, val loss: 0.21

- exported to assets/models/asl_model.tflite
- quantized with DEFAULT optimization (2x smaller, minimal accuracy loss)
```

```
SignBridge: trained ISL model — LSTM, 89% validation accuracy

2-layer LSTM: LSTM(64) → LSTM(128) → Dense(64) → Dense(10)
trained on 2400 sequences (80 per gesture × 30 frames × 3 aug)
val accuracy: 89.1%

- bit lower than ASL because ISL needs more samples honestly
- exported to assets/models/isl_model.tflite

NOTES FOR ME:
if accuracy drops more, collect 20 more samples per gesture
especially for SORRY and PLEASE — those look similar
```

---

## Quick Reference — Prefix Tags

| Tag | When to use |
|-----|------------|
| `SignBridge:` | new feature or implementation |
| `fix:` | bug fix |
| `refactor:` | restructuring without behavior change |
| `chore:` | pubspec updates, .gitignore, configs |
| `docs:` | README, comments |
| `wip:` | incomplete, just saving progress |

---

## Git Commands to Use

```bash
# Regular commit
git add .
git commit -m "SignBridge: short title" -m "body explanation here"
git push origin main

# If you messed up the last commit message
git commit --amend

# Save WIP without committing
git stash

# Check what youre about to commit
git diff --staged
```

---

## Things to NEVER commit

```
.env                    # Gemini API key
*.tflite                # large model files — use Git LFS or link in README
datasets/raw/           # collected landmark data — too large
__pycache__/            # python cache
.dart_tool/             # flutter cache
build/                  # flutter build output
```

### .gitignore additions
```
.env
*.tflite
datasets/
__pycache__/
*.pyc
build/
.dart_tool/
android/local.properties
ios/Pods/
```

---

*Reference: SignSpeak commit history — github.com/DineshMSDian/SignSpeak*
