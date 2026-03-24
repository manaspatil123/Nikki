# Navigation & State Management

## Navigation Graph

```
CameraScreen (start destination)
    │
    ├──▶ ExplanationSheet (bottom sheet, overlay on camera)
    │       │
    │       └──▶ ComparisonView (replaces sheet content)
    │
    ├──▶ HistoryScreen
    │       │
    │       └──▶ ExplanationSheet (bottom sheet, overlay on history)
    │               │
    │               └──▶ ComparisonView
    │
    └──▶ SettingsScreen (from History)
```

Only 3 actual screens. The Explanation Card and Comparison View are bottom sheet overlays, not separate navigation destinations.

## State Flow

### Camera Screen State

```kotlin
data class CameraScreenState(
    val selectedNovel: Novel? = null,
    val sourceLanguage: String = "ja",
    val targetLanguage: String = "en",
    val dontSave: Boolean = false,
    val isFrozen: Boolean = false,
    val recognizedText: List<TextBlock> = emptyList(),
    val selectedText: String? = null,
    val selectedTextBounds: Rect? = null,
    val surroundingContext: String? = null
)
```

### Explanation Sheet State

```kotlin
data class ExplanationSheetState(
    val isLoading: Boolean = false,
    val selectedText: String = "",
    val explanation: Explanation? = null,
    val error: String? = null,
    val comparisonTarget: SimilarWord? = null,
    val comparison: Comparison? = null,
    val isComparisonLoading: Boolean = false
)
```

### History Screen State

```kotlin
data class HistoryScreenState(
    val novels: List<Novel> = emptyList(),
    val selectedNovelId: Long? = null,
    val entries: List<WordEntry> = emptyList(),
    val searchQuery: String = ""
)
```

## Key State Transitions

1. **User taps word on camera** → `selectedText` updated → Explanation Sheet opens → AI request fires → `explanation` populated
2. **AI response received + dontSave=false** → WordEntry inserted into Room → History updated
3. **User taps similar word chip** → `comparisonTarget` set → Comparison AI request fires → `comparison` populated
4. **User switches novel tab in History** → `selectedNovelId` updated → `entries` re-queried from Room
