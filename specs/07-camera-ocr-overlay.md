# Camera OCR Overlay — Apple Vision Framework

This document specifies the capture-then-OCR text recognition and overlay system using Apple's native Vision framework (`VNRecognizeTextRequest`). This is the same engine that powers Live Text / "select text from photos" on iOS. Works fully offline with excellent CJK support.

---

## Overview

The camera OCR overlay is the core interaction of the app. The user sees a live camera preview, takes a picture of the novel page, and the captured image is processed for text recognition. Detected text becomes interactable — users can tap words or drag to select phrases, then trigger explanations.

**Why Apple Vision framework:**
- **Offline**: No internet required after iOS 16, no model downloads needed — built into the OS
- **Excellent Japanese support**: Same quality as iOS Live Text, far superior to ML Kit for CJK
- **No API costs**: Unlike Google Cloud Vision API, zero per-request cost
- **Fast**: Native on-device processing, no network latency

**Why capture-first instead of real-time streaming:**
- **Higher accuracy**: Vision framework processes a full-resolution JPEG, significantly more accurate for Japanese text than camera stream frames
- **Simpler lifecycle**: No camera stream to manage, no frame throttling
- **Seamless transition**: Camera preview stays rendered behind the captured image — no screen flash on capture

---

## Architecture

### Components

| File | Purpose |
|------|---------|
| `ios/Runner/TextRecognitionPlugin.swift` | Native platform channel — calls `VNRecognizeTextRequest`, returns bounding boxes in pixel coords |
| `lib/services/apple_ocr_service.dart` | Dart service — invokes the platform channel, maps results to `OcrResult` / `RecognizedBlock` / `RecognizedElement` |
| `lib/services/ocr_service.dart` | Shared data classes (`OcrResult`, `RecognizedBlock`, `RecognizedElement`) + dormant Cloud Vision API implementation (kept for future use) |
| `lib/widgets/text_overlay.dart` | Gesture handling, selection logic, magnifier loupe, selection painting |
| `lib/screens/camera_screen.dart` | Camera UI, capture flow, bottom sheet explanation dialog |

### Platform Channel

- Channel name: `com.nikki/text_recognition`
- Method: `recognizeText`
- Arguments: `{ imagePath: String, languages: [String] }`
- Returns: `{ blocks: [...], width: Int, height: Int }`

---

## Pipeline

```
Live Preview → User taps Capture → takePicture() → JPEG file
                                                       ↓
                                          Platform Channel → Swift
                                                       ↓
                                          VNRecognizeTextRequest (.accurate)
                                                       ↓
                                          Per-character bounding boxes (CJK)
                                          Per-word bounding boxes (Latin)
                                                       ↓
                                          Display captured image + Overlay
```

### Step 1: Live Camera Preview

- Camera shows a live preview using `CameraPreview(controller)` inside `FittedBox(fit: BoxFit.cover)`
- Resolution: `ResolutionPreset.max` for high-quality captures
- No OCR processing during live preview
- The preview **remains rendered** even after capture (layered behind the captured image) to prevent screen flash

### Step 2: Picture Capture

- User taps the Capture button (bottom-center circle)
- `CameraController.takePicture()` captures a high-resolution JPEG
- While capturing + processing, the button shows a loading spinner

### Step 3: OCR via Apple Vision

**Native side (Swift):**

1. Load image via `UIImage(contentsOfFile:)` to get EXIF orientation
2. Pass `CGImage` + `CGImagePropertyOrientation` to `VNImageRequestHandler`
3. Configure `VNRecognizeTextRequest`:
   - `.recognitionLevel = .accurate`
   - `.recognitionLanguages = [langCode]` (e.g. `"ja"` for Japanese)
   - `.usesLanguageCorrection = true`
4. For each `VNRecognizedTextObservation`:
   - Get top candidate text via `topCandidates(1).first`
   - **CJK languages** (`ja`, `zh-Hans`, `zh-Hant`, `ko`): Extract **character-level** bounding boxes using `candidate.boundingBox(for: charRange)` for each character index
   - **Latin languages**: Extract **word-level** bounding boxes by splitting on spaces and calling `candidate.boundingBox(for: wordRange)`
5. Convert Vision framework normalized coordinates (origin bottom-left, 0→1) to pixel coordinates (origin top-left):
   ```
   pixelX = normalizedX * imageWidth
   pixelY = (1.0 - normalizedY - normalizedHeight) * imageHeight
   ```
6. Visual dimensions from `UIImage.size * UIImage.scale` (matches Flutter's `Image.file()` after EXIF rotation)

**Dart side:**

- `AppleOcrService.processImageFile(filePath, sourceLanguage)` invokes the platform channel
- Maps the response to `OcrResult` containing `RecognizedBlock` list + image dimensions
- Each block = one line of text, with character or word-level `RecognizedElement` children

### Step 4: Display Captured Image + Overlay

- Camera preview stays rendered (always in the widget tree)
- Captured JPEG displayed on top using `Image.file(fit: BoxFit.cover)` inside `InteractiveViewer` (pinch-to-zoom, 1x–5x)
- `TextOverlay` widget sits on top of the image in the same `InteractiveViewer` stack — both scale together

### Step 5: Coordinate Transformation (Image Space → Screen Space)

The captured image is displayed using `BoxFit.cover`. The overlay replicates this transform:

```
imageAspect = imageWidth / imageHeight
screenAspect = overlayWidth / overlayHeight

if imageAspect > screenAspect:
  scale = overlayHeight / imageHeight
  offsetX = (imageWidth * scale - overlayWidth) / 2
  offsetY = 0
else:
  scale = overlayWidth / imageWidth
  offsetX = 0
  offsetY = (imageHeight * scale - overlayHeight) / 2

screenRect = Rect.fromLTRB(
  imgRect.left * scale - offsetX,
  imgRect.top * scale - offsetY,
  imgRect.right * scale - offsetX,
  imgRect.bottom * scale - offsetY,
)
```

---

## Text Selection

### Element Granularity

| Language | Element = | Reason |
|----------|-----------|--------|
| Japanese, Chinese, Korean | Single character | Precise drag selection — user can stop at any character boundary |
| English, French, German, Spanish | Single word | Natural word boundaries via spaces |

### Tap Selection (Single Tap)

- Tapping a character selects the **full word** it belongs to
- Word boundaries determined by character-type grouping on the Dart side:
  - Consecutive **CJK ideographs** (U+4E00–U+9FFF) form one word
  - Consecutive **hiragana** (U+3040–U+309F) form one word
  - Consecutive **katakana** (U+30A0–U+30FF) form one word
  - Consecutive **Latin letters** form one word
  - Consecutive **digits** form one word
  - Punctuation / other = single character only
- Example: tapping any character in `漢字` selects both; tapping `食` in `食べる` selects just `食` (kanji group), tapping `べ` selects `べる` (hiragana group)
- Hit test uses 6px padding around each bounding box for easier tapping

### Drag Selection (Long Press + Drag)

- **Long press duration**: 200ms (reduced from default 500ms for snappier feel)
- Selects individual characters — user has full control over exact selection range
- Works **across multiple lines/blocks** using global element indexing
- Uses `RawGestureDetector` with custom `LongPressGestureRecognizer` for the reduced duration
- Closest-element search across all blocks determines which element the drag is over

### Global Element Indexing

All elements across all blocks are assigned a sequential global index. This allows seamless cross-line selection:

```
Block 0: elements [0, 1, 2, 3, 4]
Block 1: elements [5, 6, 7, 8]
Block 2: elements [9, 10, 11]
```

Drag from global 3 to global 8 selects elements 3–8 across blocks 0 and 1.

### Selection Context

- `selectedText` = concatenation of all selected element texts
- `surroundingContext` = combined text of all blocks containing selected elements (used for AI explanation)

---

## Visual Rendering

### Overlay

**No idle overlay.** The captured image is displayed clean — no underlines, no tint, no visual indicators of tappable text. The image looks exactly as captured.

### Selection Highlight

| State | Visual |
|-------|--------|
| **During drag** | Per-element blue fill: `Color(0x332196F3)` (20% blue), 2px rounded corners |
| **After tap / finalized selection** | Per-element blue fill: `Color(0x662196F3)` (40% blue), 2px rounded corners |
| **No border** | Borders removed — per-element fill follows the exact bounding box of each character, which aligns naturally with tilted text |

### Bottom Sheet (Explanation Dialog)

- `showModalBottomSheet` with `barrierColor: Colors.transparent` (no darkening scrim)
- `DraggableScrollableSheet`:
  - `initialChildSize: 0.25`
  - `minChildSize: 0.15`
  - `maxChildSize: 0.45`
- Black background, white text, 16px border radius top corners

---

## Magnifier Loupe

During long-press drag selection, a circular magnifier bubble appears above the finger showing a zoomed-in view of the touch area.

### Specifications

| Property | Value |
|----------|-------|
| Diameter | 90px |
| Position | 60px above the touch point, horizontally centered |
| Magnification | 2.0x |
| Border | 1.5px white at 30% opacity |
| Shadow | Black 25% opacity, 8px blur, 1px spread |

### How It Works

The loupe renders a **second copy of the actual image file** inside a `ClipOval`, translated and scaled so the touch point appears at the loupe center. This approach is fully reliable across screen sizes — no `BackdropFilter` matrix math needed.

```
1. Compute the image's BoxFit.cover display size (coverW × coverH)
2. Compute the centered crop offset (coverOffsetX, coverOffsetY)
3. Map touch point to cover-image coordinates:
   imgX = touchX + coverOffsetX
   imgY = touchY + coverOffsetY
4. Scale by magnification:
   scaledImgX = imgX * mag
   scaledImgY = imgY * mag
5. Translate so scaled touch point sits at loupe center (R, R):
   translateX = R - scaledImgX
   translateY = R - scaledImgY
6. Render Image.file at (translateX, translateY) with size (coverW * mag, coverH * mag)
```

### Selection Overlay in Loupe

A `_LoupeSelectionPainter` draws the blue selection fill inside the magnifier at the matching magnified scale, so selected characters are highlighted in the loupe as well.

### Cursor Markers

Two cursor markers indicate the selection boundaries inside the loupe:

| Marker | Position | Visual |
|--------|----------|--------|
| **Left cursor** | Left edge of first selected element | 2px blue vertical line + 3px blue dot at bottom |
| **Right cursor** | Right edge of last selected element | 2px blue vertical line + 3px blue dot at top |

- Color: `Color(0xDD2196F3)` (87% blue)
- Line extends 2px beyond the element top/bottom
- Dot sits 5px beyond the line end
- Both cursors always visible regardless of drag direction

---

## Pinch-to-Zoom

- `InteractiveViewer` wraps the captured image + text overlay
- Min scale: 1.0x, Max scale: 5.0x
- Both image and overlay scale together — bounding boxes stay aligned
- Zoom in first, then long-press to select small text with precision

---

## Supported Languages

| Language | Vision Code | Element Level |
|----------|-------------|---------------|
| Japanese | `ja` | Character |
| Chinese | `zh-Hans` | Character |
| Korean | `ko` | Character |
| English | `en` | Word |
| French | `fr` | Word |
| German | `de` | Word |
| Spanish | `es` | Word |

---

## Retake Flow

- After capture, the center button changes to a refresh icon (white filled circle with black icon)
- Tapping it calls `retake()` which clears the captured image, recognized blocks, and selection state
- Returns to live camera preview (which was always rendering behind the captured image)

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Camera permission denied | Show permission request screen with "Grant Permission" button |
| Camera permission permanently denied | Show "Open Settings" button |
| Picture capture fails | Log error, show SnackBar, stay on live preview |
| OCR processing fails | Log error, show SnackBar with error message |
| No text detected | Show captured image with no overlay (clean image) |

---

## Platform Requirements

- **iOS 16.0+** — Required for Japanese language support in Vision framework
- Deployment target set in both `Podfile` (`platform :ios, '16.0'`) and Xcode project (`IPHONEOS_DEPLOYMENT_TARGET = 16.0`)

---

## Lifecycle & Disposal

- App goes to background: camera controller disposed, set to null, `setState()` triggers loading indicator
- App resumes: camera re-initialized (or permission re-checked if not yet granted)
- Widget dispose: camera controller and OCR service both disposed
- `Consumer<CameraProvider>` guards against null/disposed controller during rebuilds

---

## Dormant: Cloud Vision API

`lib/services/ocr_service.dart` contains a complete Google Cloud Vision API implementation (`DOCUMENT_TEXT_DETECTION`) that is **not currently wired to the UI**. It handles:
- Base64 image encoding and HTTP POST to Vision API
- Language hints per source language
- EXIF rotation detection and 90deg CW coordinate correction
- Both `vertices` (pixel) and `normalizedVertices` (fractional) bounding box parsing

This is kept for potential future use (e.g. Android support, fallback for complex layouts, or comparison testing).
