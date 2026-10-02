<p align="center">
  <img src="assets/icons/7EBE0F57-0829-46A0-B512-677D04BE7CE4.png" width="150" alt="SeeForYou Logo">
</p>

<h1 align="center">SeeForYou Mobile App</h1>

SeeForYou is a Flutter mobile application designed to assist visually impaired and elderly users in identifying product expiry dates. It combines on-device OCR for initial scanning with cloud-based vision analysis for processing, utilizing audio feedback and haptics for navigation.

---

## 🌟 Features

### 1. Accessibility & Navigation

- **Double-Tap Navigation:** Main navigation tabs and major actions (such as retaking a photo or opening the gallery) require a two-step confirmation. Tapping an item once plays an audio description of its function; double-tapping within 1,500ms executes the action.
- **Long-Press Instructions:** The introduction screen features an option to hold anywhere for 3 seconds to play verbal instructions. Rhythmic haptic feedback vibrates once per second during the hold to indicate progress.
- **Gestures:** Users can switch from the introduction screen to the camera view using a horizontal swipe left gesture.

### 2. On-Device OCR Pipeline

- **Local Processing:** Runs Google ML Kit Text Recognition locally to scan camera frames continuously without a network dependency.
- **Character Mapping:** Standardizes common OCR misreadings of text characters into numerical digits (e.g., converting `O`, `Q`, `D` -> `0`; `I`, `L` -> `1`; `B` -> `8`; `S` -> `5`; `Z` -> `2`).
- **Date Parsing Strategies:** Searches for date formats using three fallback methods:
  1. _Keywords:_ Looks for labels like `EXP`, `MFD`, `BBF`, or `BEST BEFORE` followed by a date.
  2. _Delimiters:_ Identifies numeric patterns separated by dots, slashes, dashes, or spaces.
  3. _Raw Digits:_ Parses continuous 6 or 8-digit blocks (e.g., `DDMMYY` or `DDMMYYYY`).
- **Year Standardization:** Converts Buddhist Era years to Gregorian years (subtracts 543 if the year is >= 2500) and limits valid matches to the 2018–2040 range to reduce false positives.

### 3. Scan Control & Angle Checks

- **Polling Interval:** Captures and processes frames at a set 1,300ms interval.
- **Angle Verification:** Computes text alignment lines using trigonometric functions (`atan2`). If a detected line exceeds a 20-degree tilt, the frame counter resets, and an audio/haptic warning prompts the user to adjust the camera angle.
- **Frame Validation:** Requires the exact same date format to be detected across 2 consecutive frames before triggering the cloud upload.

### 4. Cloud Integration & Audio Playback

- **Image Compression:** Compresses images to `640x640` resolution at 80% quality via `flutter_image_compress` to limit data usage and latency.
- **Backend Processing:** Sends the compressed image via a multipart POST request to a FastAPI service hosted on Hugging Face Spaces.
- **Audio Playback:** Receives a text summary and a Text-to-Speech (TTS) streaming link from the server, which is played using the `audioplayers` package.

---

## 🧱 Project Directory Structure

```text
lib/
│   firebase_options.dart      # Configuration generated via FlutterFire CLI
│   main.dart                  # App entry point & Firebase initializer
│
├───screens/
│   ├───camera/
│   │   │   camera_screen.dart          # Live camera feed and frame capture management
│   │   │
│   │   ├───components/
│   │   │       camera_overlay.dart     # Interface layer for flash toggle and gallery access
│   │   │
│   │   └───controllers/
│   │           scan_logic_controller.dart # Manages frame loops, validation counts, and scanner state
│   │
│   ├───intro/
│   │       intro_screen.dart           # Onboarding screen with long-press guides and swipe gestures
│   │
│   ├───result/
│   │       result_screen.dart          # Compresses images, handles upload payloads, and plays remote TTS
│   │
│   └───root/
│           root_screen.dart            # Layout shell containing the double-tap bottom navigation bar
│
├───services/
│       api_service.dart                # Manages multipart HTTP uploads to the FastAPI endpoint
│       audio_feedback_service.dart     # Handles audio asset playback and haptic triggers
│       expiry_scanner_service.dart     # Coordinates Google ML Kit OCR and regex filtering
│
└───utils/
        constants.dart                  # Backend URL and endpoint configurations
```

---

## 🛠️ Tech Stack & Dependencies

### Environment

- **Dart SDK:** `^3.8.1`
- **Framework:** Flutter

### Core Dependencies

- `camera: ^0.11.2+1` — Handles live camera feed and frame capture management.
- `google_mlkit_text_recognition: ^0.15.0` — Provides local on-device OCR processing.
- `audioplayers: ^6.5.1` — Manages sound effects, verbal cues, and cloud TTS streaming.
- `haptic_feedback: ^0.6.4+2` / Native Haptics — Coordinates tactile vibration patterns.
- `http: ^1.6.0` — Handles multipart network payloads to the FastAPI backend.
- `flutter_image_compress: ^2.4.0` — Downscales image quality and dimensions before upload.
- `firebase_core: ^4.6.0` — Configures infrastructure for backend distribution and tester flows.
- `image_picker: ^1.2.1` — Provides gallery asset picking tools.
- `flutter_svg: ^2.2.3` — Renders vector icons across the interface layers.
- `google_fonts: ^6.3.2` — Typography management.
- `cupertino_icons: ^1.0.8` — Asset icons for iOS-style components.
- `flutter_launcher_icons: ^0.14.4` — Configures and updates application launcher icons.

---

## 🚀 Getting Started

### Prerequisites

- **Dart SDK** version `^3.8.1` or higher.
- Flutter SDK (Stable channel) configured.
- Android Studio or Xcode configured for physical device testing (highly recommended to verify camera, audio, and haptic hardware features).

### Installation & Setup

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/your-username/SeeForYou-mobile-app.git
   cd SeeForYou-mobile-app
   ```

2. **Fetch Dependencies:**

   ```bash
   flutter pub get
   ```

3. **Asset Verification:** Ensure audio assets (`camera_is_ready.mp3`, `rotate_warning.mp3`, etc.) and vector graphics are placed in their respective directories and registered in `pubspec.yaml`:

   ```yaml
   flutter:
     assets:
       - assets/icons/
       - assets/audio/
   ```

4. **Run the Application:**
   Connect a physical mobile device and run:
   ```bash
   flutter run
   ```

---

## ⚙️ Service Configuration

### FastAPI Endpoint

The application interacts with a backend parsing service on Hugging Face Spaces. The base URL is configured in `lib/utils/constants.dart`:

```dart
const String backendBaseUrl = 'https://lunaboy-seeforyou-fastapi.hf.space';
```

### Firebase App Distribution

Firebase configuration is managed inside `lib/firebase_options.dart` to support **Firebase App Distribution**. This allows the deployment of pre-release builds to beta testers and feedback groups without a store listing.

To reconfigure the Firebase environment, use the FlutterFire CLI:

```bash
flutterfire configure
```

---

## ❤️ Final Note

While this project might not be perfect or groundbreaking, it was built with genuine dedication and a sincere effort to create something meaningful. I poured a lot of care into designing these accessibility features, hoping they can be truly helpful to those who need them. Thank you for taking the time to look through my work!
