# Nikki Code Organization Specification

## 1. Problem Summary

The codebase currently has 25 Dart files across 8 folders. The architecture started well — clean separation of models, data, providers, services, screens, widgets, and theme — but as features accrued (OCR backends, idle/sleep, motion detection, explanation sheets, language dropdowns, novel management), code piled into a few monolithic files rather than being decomposed.

**The worst offender is `camera_screen.dart` at 1,107 lines.** It owns:
- Camera permission flow (check, request, permanently-denied)
- Camera lifecycle (init, stop, dispose, app-lifecycle resume/pause)
- Idle sleep system (timer, motion detection via accelerometer, wake/sleep)
- Capture/retake orchestration (take picture, run OCR, update provider, stop camera)
- Explanation bottom sheet presentation (builds its own 200-line inline sheet)
- New Novel dialog
- Full UI build with 5+ stacked layers and two toolbar bars
- Language name mapping utility

**Secondary issues:**
- OCR domain models (`RecognizedBlock`, `RecognizedElement`, `SelectedWord`) live inside `camera_provider.dart` instead of in `models/`
- `OcrResult` lives in `ocr_service.dart` (the Google Cloud implementation) but is imported by `apple_ocr_service.dart`
- The camera screen builds its own explanation bottom sheet inline (lines 280-491) while `widgets/explanation_sheet.dart` exists as a proper extracted widget — only used by `history_screen.dart`
- Language constants (display names, ISO codes, supported lists) are duplicated across 4 files
- `CameraProvider` mixes capture state, novel management, language settings, and text selection into one class

---

## 2. Proposed File Structure

```
lib/
  main.dart                           # (unchanged) Entry point
  app.dart                            # (unchanged) MaterialApp + provider setup

  core/
    constants/
      languages.dart                  # Single source of truth for language maps
      camera_colors.dart              # Linen/teal/brown palette + selection blue colors
      assets.dart                     # SVG and image asset path constants

  models/
    explanation.dart                  # (unchanged)
    explanation_category.dart         # (unchanged)
    novel.dart                       # (unchanged)
    word_entry.dart                  # (unchanged)
    recognized_block.dart            # NEW — extract from camera_provider.dart
    recognized_element.dart          # NEW — extract from camera_provider.dart
    selected_word.dart               # NEW — extract from camera_provider.dart
    ocr_result.dart                  # NEW — extract from ocr_service.dart

  data/
    database.dart                    # (unchanged)
    novel_repository.dart            # (unchanged)
    settings_repository.dart         # (unchanged)
    word_repository.dart             # (unchanged)

  services/
    ocr/
      ocr_service.dart               # SLIMMED — just the OcrService class (Google Cloud)
      apple_ocr_service.dart         # (mostly unchanged, imports from models/)
    openai_service.dart              # (unchanged)

  providers/
    camera_provider.dart             # SLIMMED — see section 4
    explanation_provider.dart        # (unchanged)
    history_provider.dart            # (unchanged)
    settings_provider.dart           # (unchanged)

  screens/
    camera/
      camera_screen.dart             # SLIMMED — orchestrator only (~250 lines)
      widgets/
        camera_permission_view.dart  # Permission denied / request UI
        camera_preview_layer.dart    # Live preview + blurred sleep + sleep overlay
        camera_top_bar.dart          # Language dropdown + novel selector + arrow
        camera_bottom_bar.dart       # Save toggle + capture button + history button
        language_dropdown.dart       # Extracted PopupMenuButton for source language
        novel_selector.dart          # Extracted PopupMenuButton for novel pick
        new_novel_dialog.dart        # AlertDialog for creating a novel
    history/
      history_screen.dart            # (unchanged, or minor import adjustments)
    settings/
      settings_screen.dart           # (unchanged)

  widgets/
    explanation_sheet.dart           # (unchanged — becomes the SINGLE sheet widget)
    shimmer_box.dart                 # (unchanged)
    text_overlay.dart                # (unchanged)

  theme/
    nikki_theme.dart                 # (unchanged)
```

**Net change:** ~8-11 new files, 0 deleted files (contents moved), every existing file either unchanged or slimmed down.

---

## 3. Detailed Extraction Plan

### 3.1 Extract OCR Models into `models/`

**Current state:** `RecognizedBlock`, `RecognizedElement`, and `SelectedWord` are defined at the top of `camera_provider.dart` (lines 1-33). `OcrResult` is defined at the top of `services/ocr_service.dart` (lines 11-17).

**Problem:** These are data models, not provider internals. Every file that needs OCR types must import `camera_provider.dart` or `ocr_service.dart`, creating unnecessary coupling. `apple_ocr_service.dart` imports `camera_provider.dart` just to access `RecognizedBlock` — a service depending on a provider.

**Action:**

| New File | Classes Moved |
|---|---|
| `models/recognized_block.dart` | `RecognizedBlock` |
| `models/recognized_element.dart` | `RecognizedElement` |
| `models/selected_word.dart` | `SelectedWord` |
| `models/ocr_result.dart` | `OcrResult` |

Then update imports in:
- `camera_provider.dart` — import from models
- `apple_ocr_service.dart` — import from models instead of `camera_provider.dart`
- `ocr_service.dart` — import from models
- `text_overlay.dart` — import from models instead of `camera_provider.dart`

**Optionally**, keep a single barrel file `models/ocr.dart` that re-exports all four for convenience:
```dart
export 'recognized_block.dart';
export 'recognized_element.dart';
export 'selected_word.dart';
export 'ocr_result.dart';
```

### 3.2 Centralize Language Constants

**Current state:** Language data is scattered across 4 files:

| File | What it defines |
|---|---|
| `camera_screen.dart:261-272` | `_nativeLanguageName()` — English name to native script |
| `camera_screen.dart:778-786` | Inline `languages` map (same data, in a widget builder) |
| `apple_ocr_service.dart:19-38` | `_languageCode()` — English name to ISO 639 code |
| `ocr_service.dart:20-39` | `_languageHint()` — same mapping, different method name |
| `settings_screen.dart:10-32` | `_sourceLanguages` / `_targetLanguages` lists |

**Data inconsistency (not just duplication):** The camera dropdown offers 7 languages (Japanese, Chinese, Korean, English, French, German, Spanish) while `settings_screen.dart` offers 11 source languages (adding Chinese Simplified/Traditional as separate entries, Italian, Portuguese, Russian, Arabic) and 8 target languages. The camera uses plain "Chinese" while settings splits it into "Chinese (Simplified)" and "Chinese (Traditional)". These must be reconciled during centralization.

**Action:** Create `lib/core/constants/languages.dart`:

```dart
class Languages {
  // Canonical list of supported source languages
  static const sourceLanguages = ['Japanese', 'Chinese', 'Korean', ...];

  // Canonical list of supported target languages
  static const targetLanguages = ['English', 'Japanese', 'Korean', ...];

  // English name -> native script (e.g. 'Japanese' -> '日本語')
  static const nativeNames = { ... };

  // English name -> ISO 639-1 code for OCR engines
  static String ocrLanguageCode(String language) { ... }
}
```

Then replace all 4 scattered definitions with references to this class. Decide on one canonical naming scheme for Chinese variants.

### 3.2b Extract Camera Color Constants

**Current state:** The camera UI uses a warm color palette that is entirely separate from `nikki_theme.dart` (which defines a monochrome black/white theme). These colors appear hardcoded 15+ times across `camera_screen.dart`:

| Color | Hex | Usage | Occurrences |
|---|---|---|---|
| Linen (cream) | `0xFFFAF0E6` | Status bar, toolbar bg, capture button bg, history button bg, popup menu bg | 6 |
| Teal | `0xFF008B8B` | Language button, capture icon tint, progress indicator, history border, border accent | 5 |
| Dark Teal | `0xFF005F5F` | Language button (hovered/open), history text/icon | 3 |
| Brown | `0xFF664C36` | Capture button border, selected item border, selected item text | 3 |

After the widget extraction (section 3.3), these will scatter across `camera_top_bar.dart`, `camera_bottom_bar.dart`, `language_dropdown.dart`, etc. — same magic numbers in more files.

**Additionally**, `text_overlay.dart` has 4 hardcoded blue selection colors:
- `Color(0x332196F3)` — 20% blue (drag selection fill)
- `Color(0x662196F3)` — 40% blue (final selection fill)
- `Color(0x442196F3)` — 27% blue (loupe selection fill)
- `Color(0xDD2196F3)` — 87% blue (cursor lines and dots)

**Action:** Create `lib/core/constants/camera_colors.dart`:

```dart
class CameraColors {
  static const linen = Color(0xFFFAF0E6);
  static const teal = Color(0xFF008B8B);
  static const darkTeal = Color(0xFF005F5F);
  static const brown = Color(0xFF664C36);

  // Selection overlay colors (used in text_overlay.dart)
  static const selectionDrag = Color(0x332196F3);
  static const selectionFinal = Color(0x662196F3);
  static const selectionLoupe = Color(0x442196F3);
  static const selectionCursor = Color(0xDD2196F3);
}
```

Then replace all hardcoded hex values in `camera_screen.dart` and `text_overlay.dart` with references to this class.

### 3.2c Extract Asset Path Constants

**Current state:** The SVG asset path `'assets/icons/capture.svg'` is a magic string in `camera_screen.dart` line 1035. Currently only one asset, but good practice to centralize.

**Action:** Create `lib/core/constants/assets.dart`:

```dart
class Assets {
  static const captureIcon = 'assets/icons/capture.svg';
}
```

### 3.3 Decompose `camera_screen.dart`

This is the core of the refactoring. The current 1,107-line file should be split into an orchestrator + focused child widgets.

#### 3.3.1 `camera_permission_view.dart`

**Extracts:** Lines 589-634 (the permission-denied scaffold body)

**Interface:**
```dart
class CameraPermissionView extends StatelessWidget {
  final bool isPermanentlyDenied;
  final VoidCallback onRequestPermission;
  // builds the icon + message + button
}
```

#### 3.3.2 `camera_preview_layer.dart`

**Extracts:** Lines 654-709 (blurred last-frame, live preview, sleep overlay)

**Interface:**
```dart
class CameraPreviewLayer extends StatelessWidget {
  final CameraController? controller;
  final bool isCaptured;
  final bool isSleeping;
  final String? lastFramePath;
  final VoidCallback onWakeTap;
}
```

#### 3.3.3 `camera_top_bar.dart`

**Extracts:** Lines 739-986 (the entire top Positioned widget: status bar, language dropdown, novel selector, arrow button)

**Interface:**
```dart
class CameraTopBar extends StatelessWidget {
  final String sourceLanguage;
  final List<Novel> novels;
  final Novel? selectedNovel;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<Novel> onNovelSelected;
  final VoidCallback onNewNovel;
  final VoidCallback onArrowTap;
}
```

This widget internally uses `LanguageDropdown` and `NovelSelector` sub-widgets.

#### 3.3.4 `language_dropdown.dart`

**Extracts:** Lines 764-868 (the PopupMenuButton for source language)

Standalone reusable widget showing the teal button with native language names.

#### 3.3.5 `novel_selector.dart`

**Extracts:** Lines 871-958 (the PopupMenuButton for novel selection)

Standalone widget with novel list + "New Novel..." divider item.

#### 3.3.6 `camera_bottom_bar.dart`

**Extracts:** Lines 988-1100 (the bottom positioned bar: save toggle, capture/retake button, history button)

**Interface:**
```dart
class CameraBottomBar extends StatelessWidget {
  final bool isCaptured;
  final bool isTakingPicture;
  final bool dontSave;
  final VoidCallback onCapture;
  final VoidCallback onRetake;
  final VoidCallback onToggleSave;
  final VoidCallback onHistoryTap;
}
```

#### 3.3.7 `new_novel_dialog.dart`

**Extracts:** Lines 520-575 (`_showNewNovelDialog`)

Convert to a static method or a standalone function:
```dart
Future<void> showNewNovelDialog(BuildContext context) async { ... }
```

#### 3.3.8 What Remains in `camera_screen.dart`

After extraction, the screen becomes a ~250-line orchestrator:
- State variables for camera controller, permissions, sleep state
- `initState`, `dispose`, `didChangeAppLifecycleState`
- Camera init/stop/sleep/wake methods
- Motion detection setup
- `_takePicture()` / `_retake()`
- `_onTextSelected` -> show ExplanationSheet (using the existing widget, not inline)
- `build()` that composes `CameraPermissionView`, `CameraPreviewLayer`, captured image + `TextOverlay`, `CameraTopBar`, `CameraBottomBar`

### 3.4 Unify Explanation Sheet Usage

**Current state:** `camera_screen.dart` builds its own 200-line inline explanation bottom sheet (lines 280-491) with a completely different visual style than `widgets/explanation_sheet.dart` (used only by `history_screen.dart`).

**Detailed style divergence:**

| Aspect | Camera inline sheet | `ExplanationSheet` widget |
|---|---|---|
| Background | `Colors.black` (hardcoded) | Uses `Theme.of(context)` |
| Text colors | `Colors.white`, `Colors.white70`, `Colors.white54`, `Colors.white38` (hardcoded) | Inherits from theme |
| Dividers | `Colors.white24` (hardcoded) | `Divider()` (theme-aware) |
| Error color | `Colors.white70` | `theme.colorScheme.onSurface.withOpacity(0.6)` |
| Layout | Flat `ListView` with label/value rows | Structured `_Section` widgets with `UPPERCASE` labels |
| Similar words | Inline underlined text list | Horizontal scrollable chip row |
| Comparison | Inline below similar words | Full-screen replacement with back button |
| Helper | `_explanationRow()` method (lines 495-519) | `_Section` widget class |

**Action:**
1. Delete the inline sheet from `camera_screen.dart` (lines 282-493) and the `_explanationRow` helper (lines 495-519)
2. Use `ExplanationSheet` from `widgets/explanation_sheet.dart` in both screens
3. To keep the dark-on-camera appearance, wrap the sheet in a `Theme` override at the call site:

```dart
void _showExplanationSheet() {
  // ... trigger explanation via provider (same as now) ...
  showModalBottomSheet(
    backgroundColor: Colors.black,
    barrierColor: Colors.transparent,
    // ... same sheet config ...
    builder: (context) => Theme(
      data: NikkiTheme.dark(),  // force dark appearance over camera
      child: DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => const ExplanationSheet(),
      ),
    ),
  );
}
```

This way `ExplanationSheet` remains theme-aware (no hardcoded colors) while the camera screen gets its dark overlay look via the dark theme.

### 3.5 Slim Down `CameraProvider`

**Current state:** `CameraProvider` manages 5 distinct concerns:
1. Novel list + selected novel
2. Language settings (source/target)
3. Capture state (image path, recognized blocks, dimensions)
4. Text selection state (selected word, show explanation flag)
5. UI toggle (`dontSave`)

**Recommendation:** For now, keep it as one provider but organize it with clear section comments and consider splitting in the future if it continues to grow. The immediate priority is extracting the data models out (section 3.1) and removing the `enabledCategories` and `googleCloudApiKey` fields that duplicate what's already in `SettingsProvider`/`SettingsRepository`.

**Action:**
- Remove `enabledCategories` field — it's already in `SettingsProvider` and `ExplanationProvider` fetches it directly from `SettingsRepository`
- Remove `googleCloudApiKey` field — it's loaded but only used by the old `OcrService` (Google Cloud), not by `AppleOcrService`. If needed later, fetch from `SettingsRepository` at call site.
- Keep the rest as-is for now; the provider is 152 lines which is reasonable

### 3.6 Move OCR Services into Subfolder

**Current state:** `services/` has 3 files at the same level — two are OCR backends, one is OpenAI.

**Action:** Group the OCR services:
```
services/
  ocr/
    ocr_service.dart          # Google Cloud Vision
    apple_ocr_service.dart    # Apple Vision (MethodChannel)
  openai_service.dart         # (unchanged)
```

This makes room for future service additions without clutter.

---

## 4. Migration Order

Execute in this order to keep the app compilable at every step:

| Step | What | Risk | Files Touched |
|---|---|---|---|
| 1 | Extract OCR models to `models/` | Low — only import changes | 6 files |
| 2 | Create `core/constants/languages.dart` (reconcile settings vs camera lists) | Low — additive, then swap | 5 files |
| 3 | Create `core/constants/camera_colors.dart` + `core/constants/assets.dart` | Low — additive, then swap | 3 files |
| 4 | Move OCR services to `services/ocr/` | Low — only path changes | 3 files |
| 5 | Move `history_screen.dart` → `screens/history/`, `settings_screen.dart` → `screens/settings/` | Low — only path + import changes | 3 files |
| 6 | Extract `CameraPermissionView` | Low — pure UI extraction | 2 files |
| 7 | Extract `CameraBottomBar` | Low — pure UI extraction | 2 files |
| 8 | Extract `LanguageDropdown` + `NovelSelector` | Low | 3 files |
| 9 | Extract `CameraTopBar` | Low — composes step 8 widgets | 2 files |
| 10 | Extract `CameraPreviewLayer` | Low — pure UI extraction | 2 files |
| 11 | Extract `NewNovelDialog` | Low | 2 files |
| 12 | Replace inline explanation sheet with `ExplanationSheet` widget + dark theme wrapper; delete `_explanationRow` helper | Medium — visual behavior change | 2 files |
| 13 | Remove duplicate fields from `CameraProvider` | Low | 1 file |

Each step should be a single commit. Run `flutter analyze` and a smoke test after each.

---

## 5. Dependency Graph (Before vs After)

### Before: camera_screen.dart imports
```
camera_screen.dart
  -> dart:async, dart:io, dart:math, dart:ui
  -> camera, flutter, permission_handler, provider, sensors_plus
  -> providers/camera_provider.dart
  -> providers/explanation_provider.dart
  -> services/apple_ocr_service.dart
  -> widgets/text_overlay.dart
```
The screen directly handles camera hardware, OCR, permissions, motion sensors, and all UI.

### After: camera_screen.dart imports
```
camera_screen.dart
  -> camera, flutter, permission_handler, provider, sensors_plus
  -> providers/camera_provider.dart
  -> providers/explanation_provider.dart
  -> services/ocr/apple_ocr_service.dart
  -> widgets/text_overlay.dart
  -> widgets/explanation_sheet.dart
  -> screens/camera/widgets/camera_permission_view.dart
  -> screens/camera/widgets/camera_preview_layer.dart
  -> screens/camera/widgets/camera_top_bar.dart
  -> screens/camera/widgets/camera_bottom_bar.dart
  -> screens/camera/widgets/new_novel_dialog.dart
```
The screen orchestrates; each widget handles its own rendering.

---

## 6. What NOT to Refactor (and Why)

| File | Lines | Verdict |
|---|---|---|
| `text_overlay.dart` | 629 | Large, but it's a single cohesive concern (overlay rendering + gesture handling + magnifier). The painters are tightly coupled to the overlay state. Leave structure as-is, but do extract the 4 hardcoded blue selection colors to `CameraColors` (section 3.2b). |
| `history_screen.dart` | 455 | Contains private helper widgets (`_NovelTab`, `_WordListItem`, etc.) that are screen-specific. Clean pattern, leave as-is. |
| `settings_screen.dart` | 473 | Same pattern — private section widgets that only this screen uses. Leave as-is. |
| `explanation_sheet.dart` | 353 | Well-extracted widget. Leave as-is (and start using it from camera screen too). |
| `providers/` | ~150 each | Reasonable size. Only cleanup is removing duplicate fields from `CameraProvider`. |
| `data/` | ~40 each | Tiny, focused repository classes. Perfect as-is. |
| `models/` | ~50 each | Clean data classes. Only change: add OCR models extracted from provider. |

---

## 7. Line Count Projections

| File | Before | After |
|---|---|---|
| `camera_screen.dart` | 1,107 | ~250 |
| `camera_provider.dart` | 153 | ~130 (remove duplicate fields + model classes) |
| `ocr_service.dart` | 279 | ~265 (OcrResult extracted) |
| `text_overlay.dart` | 629 | ~625 (color refs from constants) |
| **New files:** | | |
| `camera_permission_view.dart` | — | ~50 |
| `camera_preview_layer.dart` | — | ~80 |
| `camera_top_bar.dart` | — | ~60 |
| `language_dropdown.dart` | — | ~110 |
| `novel_selector.dart` | — | ~90 |
| `camera_bottom_bar.dart` | — | ~120 |
| `new_novel_dialog.dart` | — | ~55 |
| `languages.dart` | — | ~45 |
| `camera_colors.dart` | — | ~20 |
| `assets.dart` | — | ~10 |
| `recognized_block.dart` | — | ~20 |
| `recognized_element.dart` | — | ~10 |
| `selected_word.dart` | — | ~10 |
| `ocr_result.dart` | — | ~15 |

Total new code: ~695 lines across 16 new files, replacing ~900 lines removed from existing files. Net reduction of ~205 lines (duplicated logic removed).

---

## 8. Key Principles Applied

1. **Single Responsibility** — Each file owns one concern. A widget file builds UI. A provider file manages state. A service file talks to an external system.

2. **No Cross-Layer Imports** — Services should never import providers. Models should never import services. The current `apple_ocr_service.dart -> camera_provider.dart` dependency violates this; fixed by extracting models.

3. **Feature Folders for Screens** — `screens/camera/` groups the camera feature's private widgets. These widgets are not reusable app-wide (they depend on `CameraProvider` shape), so they belong near the screen that uses them, not in the global `widgets/` folder.

4. **Global `widgets/` for Shared Components** — `ExplanationSheet`, `ShimmerBox`, `TextOverlay` are used by multiple screens, so they stay in `widgets/`.

5. **DRY Constants** — Language data defined once, referenced everywhere.

6. **Incremental Migration** — Each step compiles independently. No big-bang rewrite.
