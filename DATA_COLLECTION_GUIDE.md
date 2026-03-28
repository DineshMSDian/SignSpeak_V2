# 📱 SignSpeak V2: Data Collection Guide

Welcome to the SignSpeak V2 Data Collection team! This guide will walk you through cloning the repository, compiling the Android App (`.apk`), and properly capturing high-quality Machine Learning datasets.

---

## 🛠️ 1. Prerequisites
Before you start, make sure you have the following installed on your computer:
1. **[Git](https://git-scm.com/)**
2. **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (Run `flutter doctor` to ensure it's healthy).
3. **[Android Studio](https://developer.android.com/studio)** (Used purely for the Android build tools and Java JDK 11/17).

---

## 📥 2. Cloning the Repository
Open your terminal and clone the project:
```bash
git clone https://github.com/DineshMSDian/SignSpeak_V2.git
cd SignSpeak_V2
```

---

## ⚙️ 3. Environment Setup
The app relies on a `.env` file to communicate with external APIs. It will fail to compile if this file is missing.
1. Create a new file exactly named `.env` in the root of the folder.
2. Paste the following line inside:
```text
GEMINI_API_KEY=dummy_key_for_data_collection
```

---

## 🔨 4. Build the APK
1. Download all the Flutter dependencies:
```bash
flutter pub get
```
2. Compile the application into a Release APK:
```bash
flutter build apk --release
```

> **⚠️ NOTE: JVM Error**
> If you see `Dependency requires at least JVM runtime version 11`, your machine is defaulting to an old Java 8 installation. Open Android Studio > Settings > Build, Execution, Deployment > Build Tools > Gradle, and set the **Gradle JDK** to Java 17. 

---

## 📲 5. Install on Your Phone
1. Once the compilation succeeds, locate your new APK file here: 
   `build/app/outputs/flutter-apk/app-release.apk`
2. Transfer this file to your Android phone (you can use a USB cable, Google Drive, or just email it to yourself).
3. Tap the APK on your phone to install it. *(If Android blocks it, go to your phone settings and allow "Install from Unknown Sources" for your file manager.)*

---

## 🎥 6. Data Collection Best Practices
A machine learning model is only as smart as the data it's given. Follow these rules for the highest accuracy:

**Lighting & Setup**
- Stand in a well-lit room.
- Try to have a relatively plain background behind you.
- Wear a shirt that contrasts with your skin tone (avoid wearing skin-colored shirts, otherwise the AI struggles to separate your hands from your torso).

**Recording ASL (American Sign Language)**
*ASL relies solely on static finger positions (like holding up an 'A' or 'B').*
1. Toggle the app dropdown to **ASL**.
2. Type the letter you are signing in the Label box (e.g., `A`).
3. Form the letter with your hand, hold it steady, and press **Record Label**.
4. The app will capture exactly 100 frames. 
5. **PRO-TIP:** *Don't be a statue! Slightly rotate your wrist or smoothly move your hand an inch closer to the camera while it records. This creates variance and makes the AI infinitely smarter.*

**Recording ISL (Indian Sign Language)**
*ISL relies on dynamic movements involving both hands, arms, and chest space (like swiping down for "Please").*
1. Toggle the app dropdown to **ISL**.
2. Type the word you are signing (e.g., `HELLO`).
3. Press **Record Label** and perform the complete gesture. 
4. **PRO-TIP:** *Since ISL is movement-based, perform the word smoothly, reset your hands, and perform it again until the 100-frame counter hits the limit.*

---

## 📤 7. Export and Send!
When your session is complete:
1. Tap the **Export JSON** button in the app.
2. The Android Share Sheet will appear. 
3. **Send that `.json` file to Dinesh!** (You can email it, drop it in a shared drive, or WhatsApp it). We will use those raw JSON files to train the Python Neural Networks!
