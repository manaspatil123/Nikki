# Camera OCR Overlay — Google Translate-Style

This document specifies the capture-then-OCR text recognition and overlay system. The UX is inspired by **Google Translate's camera mode** — point the camera at text, take a picture, and see detected text overlaid on the captured image for interactive word selection.

---

## Overview

The camera OCR overlay is the core interaction of the app. The user sees a live camera preview, takes a picture of the novel page, and the captured image is processed for text recognition. Detected text is rendered as interactive overlays precisely aligned with the original text. Users tap detected words to trigger explanations.

**Why capture-first instead of real-time streaming:**
- **Higher accuracy**: ML Kit processes a full-resolution JPEG via `InputImage.fromFilePath()`, which is significantly more accurate for Japanese text than processing raw camera stream frames
- **Better Japanese support**: The Japanese text recognition model performs best on high-quality, static images
- **Simpler lifecycle**: No camera stream to manage, no frame throttling, no temporal smoothing needed
- **EXIF handling**: Both ML Kit and Flutter's `Image.file()` handle EXIF rotation automatically, eliminating coordinate rotation bugs

---

## Pipeline

```
Live Preview → User taps Capture → takePicture() → JPEG file
                                                       ↓
                                          InputImage.fromFilePath()
                                                       ↓
                                          ML Kit Text Recognition
                                                       ↓
                                          Recognized Blocks + Image Dimensions
                                                       ↓
                                          Display captured image + Overlay
```

### Step 1: Live Camera Preview

- Camera shows a live preview using `CameraPreview(controller)` inside a `FittedBox(fit: BoxFit.cover)`
- **No OCR processing happens during live preview** — this is just a viewfinder
- Resolution: `ResolutionPreset.high` for high-quality captures
- **Image format is platform-specific** (needed for camera initialization):
  - Android: `ImageFormatGroup.nv21`
  - iOS: `ImageFormatGroup.bgra8888`

### Step 2: Picture Capture

- User taps the Capture button (bottom-center circle)
- `CameraController.takePicture()` captures a high-resolution JPEG to a temporary file
- While capturing, the button shows a loading spinner

### Step 3: OCR on Captured File

- `InputImage.fromFilePath(xFile.path)` creates the input image
- ML Kit handles EXIF rotation internally — bounding boxes are in the **visual** coordinate space (post-rotation)
- `TextRecognizer(script: TextRecognitionScript.japanese)` processes the image
- Returns hierarchy: `RecognizedText → TextBlock → TextLine → TextElement`
- Image dimensions are obtained via `instantiateImageCodec()` which also reflects EXIF rotation

### Step 4: Display Captured Image + Overlay

- The captured JPEG is displayed full-screen using `Image.file(fit: BoxFit.cover)`
- The text overlay is rendered on top via `CustomPaint` in a `Stack`
- Since both `Image.file()` and ML Kit apply EXIF rotation, `rotationDegrees` is set to **0** — no manual rotation needed

#### Critical: EXIF Dimension Correction

ML Kit's `fromFilePath()` physically rotates the bitmap using EXIF data before recognition — bounding boxes are in the **visual (post-rotation)** coordinate space. `Image.file()` also applies EXIF for display.

However, `dart:ui`'s `instantiateImageCodec` may or may not apply EXIF depending on the Flutter engine version. Since the app is portrait-locked, the visual image is always portrait (height > width). After getting raw dimensions from the codec, we enforce this:

```dart
if (width > height) { swap(width, height); }
```

This ensures the reported dimensions match ML Kit's bounding box coordinate space regardless of whether the codec applied EXIF.

### Step 5: Coordinate Transformation (Image Space → Screen Space)

The captured image is displayed using `Image.file(fit: BoxFit.cover)`, which scales and crops. The coordinate transform accounts for this:

```
imageAspect = imageWidth / imageHeight
screenAspect = overlayWidth / overlayHeight

if imageAspect > screenAspect:
  // Image is wider than screen — cropped on left/right
  scale = overlayHeight / imageHeight
  offsetX = (imageWidth * scale - overlayWidth) / 2
  offsetY = 0
else:
  // Image is taller than screen — cropped on top/bottom
  scale = overlayWidth / imageWidth
  offsetX = 0
  offsetY = (imageHeight * scale - overlayHeight) / 2

transformedRect = Rect.fromLTRB(
  r.left * scale - offsetX,
  r.top * scale - offsetY,
  r.right * scale - offsetX,
  r.bottom * scale - offsetY,
)
```

This ensures bounding boxes are **pixel-accurately aligned** with the text visible in the captured image.

### Step 6: Overlay Rendering

The overlay renders on a `CustomPaint` widget that sits on top of the captured image via a `Stack`.

#### Visual Style (Google Translate-inspired)

| State | Rendering |
|-------|-----------|
| **Detected text (idle)** | Semi-transparent white filled rectangle behind each text block with the detected text rendered on top in a matching font size. Slight rounded corners (2px radius). |
| **Tappable word** | Each `TextElement` (word) is an independent tap target with its own bounding box |
| **Selected word** | White filled background (90% opacity) + black border (60% opacity, 2px) around the tapped word |
| **No text detected** | Clean captured image with no overlay |

#### Text Overlay Rendering (Google Translate Style)

For each detected `TextBlock`:
1. Draw a semi-transparent background fill over the block's bounding box (white at ~75% opacity)
2. Render the **detected text** on top using `TextPainter`, sized to fit within the bounding box
3. The font size is auto-calculated to fill the bounding box width while staying within its height

This creates the signature Google Translate effect where text appears to float on top of the original.

#### Tap Detection

- `GestureDetector` with `HitTestBehavior.translucent` captures taps
- On tap, iterate through all elements and check if the tap position falls within any transformed bounding box
- The **first matching element** triggers `onElementTapped(element, blockText)` where `blockText` is the parent block's full text (used as surrounding context for AI explanations)

---

## Retake Flow

- After capture, the center button changes to a **refresh icon** (white filled circle with black icon)
- Tapping it calls `retake()` which:
  - Clears the captured image path
  - Clears recognized blocks
  - Returns to live camera preview
- The user can then capture a new page

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Camera permission denied | Show permission request screen with "Grant Permission" button |
| Camera permission permanently denied | Show "Open Settings" button |
| No cameras available | Show "No camera available" message |
| Picture capture fails | Log error, stay on live preview |
| OCR processing fails | Log error, show captured image without overlay |
| No text detected | Show captured image with no overlay |

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Capture-to-overlay latency | < 2 seconds (includes takePicture + OCR + image decode) |
| OCR accuracy (Japanese print) | > 95% character accuracy |
| Overlay rendering | 60 FPS (static image, no re-processing) |
| Memory usage | < 50MB additional from OCR |
| Battery impact | Low (camera only active during preview, not continuous processing) |

---

## Platform-Specific Notes

### Android
- Image format: `ImageFormatGroup.nv21` (specified in CameraController constructor)
- **Japanese model must be explicitly added** to `android/app/build.gradle.kts`:
  ```kotlin
  dependencies {
      implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
  }
  ```
  The Flutter package (`google_mlkit_text_recognition`) only declares non-Latin models as `compileOnly` — they compile but are NOT bundled in the APK. Without this explicit dependency, the Japanese recognizer silently returns empty results.
- The Japanese model adds ~28MB to the APK
- `takePicture()` saves JPEG with EXIF rotation metadata
- `InputImage.fromFilePath()` reads EXIF and applies rotation to bounding boxes

### iOS
- Image format: `ImageFormatGroup.bgra8888` (specified in CameraController constructor)
- ML Kit uses the same on-device model via CocoaPods
- Same EXIF-based rotation handling as Android

---

## Lifecycle & Disposal

- When the app goes to background (`AppLifecycleState.paused/inactive`):
  - Camera controller is disposed and set to null
  - `setState()` is called to trigger rebuild with loading indicator
- When the app resumes (`AppLifecycleState.resumed`):
  - Camera is re-initialized
- On widget dispose: camera controller and OCR recognizer are both disposed
- The `Consumer<CameraProvider>` builder guards against null/disposed controller

---

## Relationship to Other Features

- **F1 (Camera Scanner)**: This spec details the internal mechanics of F1's OCR pipeline
- **F2 (Explanation Card)**: Triggered when user taps a word in the overlay; receives `selectedText` + `surroundingContext` (block text)
- **F3 (Don't Save)**: Affects whether the explanation is persisted, but has no impact on OCR behavior
