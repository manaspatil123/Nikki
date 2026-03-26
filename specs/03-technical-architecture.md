# Technical Architecture

## Platform & Stack

| Layer | Technology |
|---|---|
| Platform | Flutter (Android + iOS) |
| Language | Dart |
| UI | Flutter Material 3, black & white theme |
| Camera | camera package |
| OCR | google_mlkit_text_recognition (on-device) |
| AI Explanations | OpenAI GPT-4o-mini API (see AI section below) |
| Local Storage | sqflite (SQLite) |
| State Management | provider (ChangeNotifier) |
| Networking | http package |
| Secure Storage | flutter_secure_storage (API key) |
| Preferences | shared_preferences |

---

## OCR: Google ML Kit vs Google Cloud Vision API

**Recommendation: Google ML Kit (on-device)**

| Factor | ML Kit (on-device) | Cloud Vision API |
|---|---|---|
| Cost | Free | $1.50 per 1000 requests |
| Latency | ~50-100ms (on-device) | 500ms+ (network round-trip) |
| Offline | Yes | No |
| Japanese support | Yes (requires explicit `implementation` dependency in app-level build.gradle — the Flutter package only includes it as `compileOnly`) | Yes |
| Accuracy | Good (sufficient for printed novel text) | Slightly better |
| Privacy | Text never leaves device | Text sent to Google servers |

ML Kit is the clear winner for this use case. Novel text is printed (not handwritten), well-formatted, and high-contrast — ML Kit handles this well. No cost, no network dependency for OCR.

**Note:** The user mentioned "Google Translate OCR API" — there is no public standalone API for Google Translate's camera OCR. The underlying tech is ML Kit / Cloud Vision. ML Kit is what Google Translate uses on-device.

---

## AI API: Choosing Between OpenAI, Claude, and Others

### Recommendation: **OpenAI GPT-4o-mini** (primary) or **Claude 3.5 Haiku** (alternative)

This app makes many small, structured requests (one per word lookup). The key criteria are:

| Criteria | GPT-4o-mini | Claude 3.5 Haiku | Gemini 1.5 Flash |
|---|---|---|---|
| Cost per 1M input tokens | $0.15 | $0.25 | $0.075 |
| Cost per 1M output tokens | $0.60 | $1.25 | $0.30 |
| Multilingual quality | Excellent | Excellent | Good |
| Structured JSON output | Native (response_format) | Good | Good |
| Linguistic nuance | Very good | Excellent (strongest here) | Good |
| Latency (median) | ~400ms | ~500ms | ~300ms |
| Rate limits | Generous | Generous | Generous |

**Verdict:**

- **GPT-4o-mini** is the best default — cheapest at high quality, native JSON mode, fast.
- **Claude Haiku 4.5** is the best alternative if linguistic nuance matters most (it's notably better at explaining subtle differences between similar words, formality registers, and cultural context). Slightly more expensive but the quality difference is meaningful for a language-learning app.
- **Gemini 1.5 Flash** is cheapest but weaker on nuanced Japanese linguistic explanations.

**For v1: Use OpenAI GPT-4o-mini.** ~$0.77/month at 100 lookups/day. If quality isn't sufficient for nuanced linguistic explanations, switch to Claude Haiku 4.5 (~$6/month at same usage).

**Architecture allows swapping:** The AI layer is abstracted behind an interface, so switching to Claude or adding a provider toggle in settings is straightforward.

---

## AI Prompt Strategy

The user never writes prompts. All prompts are pre-built and sent programmatically.

### Explanation Request Prompt Template

```
You are a language tutor. The user is reading a novel in {source_language} and learning vocabulary.

Selected text: "{selected_text}"
Surrounding context: "{surrounding_sentence_or_paragraph}"
Source language: {source_language}
Target language: {target_language}

Provide the following in JSON format:
{
  "meaning": "...",
  "reading": "...",
  "context": "...",
  "examples": ["...", "...", "..."],
  "breakdown": "...",
  "formality": "...",
  "similar_words": [
    {"word": "...", "reading": "...", "brief": "..."},
    ...
  ]
}

Only include these fields: {enabled_categories}
Be concise. Use {target_language} for all explanations.
```

### Comparison Request Prompt Template

```
Compare these two {source_language} words for a {target_language} speaker:

Word A: "{original_word}"
Word B: "{compared_word}"

Respond in JSON:
{
  "word_a": {"word": "...", "reading": "...", "meaning": "..."},
  "word_b": {"word": "...", "reading": "...", "meaning": "..."},
  "difference": "...",
  "nuance": "...",
  "example_a": "...",
  "example_b": "..."
}
```

### Prompt Notes

- Surrounding context (the sentence/paragraph around the selected word) is extracted from OCR results and sent with the request. This is critical for accurate contextual explanations.
- Only enabled categories are requested to reduce token usage.
- JSON response format is enforced via OpenAI's `response_format: { type: "json_object" }`.

---

## App Architecture Pattern

**Provider + Repository Pattern**

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   UI Layer   │────▶│  ChangeNotifier  │────▶│   Repository /  │
│  (Widgets)   │◀────│   (Provider)     │◀────│   Service        │
└─────────────┘     └──────────────────┘     └────────┬────────┘
                                                       │
                                              ┌────────┴────────┐
                                              │                 │
                                        ┌─────▼─────┐   ┌──────▼──────┐
                                        │  sqflite   │   │  OpenAI     │
                                        │  (Local)   │   │  (HTTP)     │
                                        └───────────┘   └─────────────┘
```

### Package Structure

```
lib/
├── main.dart
├── app.dart                  # MaterialApp + theme + routes
├── theme/
│   └── nikki_theme.dart      # Black & white theme
├── models/                   # Data classes
│   ├── novel.dart
│   ├── word_entry.dart
│   ├── explanation.dart
│   └── explanation_category.dart
├── data/
│   ├── database.dart         # sqflite setup + migrations
│   ├── novel_repository.dart
│   ├── word_repository.dart
│   └── settings_repository.dart
├── services/
│   ├── openai_service.dart   # OpenAI API calls
│   └── ocr_service.dart      # ML Kit text recognition
├── providers/
│   ├── camera_provider.dart
│   ├── explanation_provider.dart
│   ├── history_provider.dart
│   └── settings_provider.dart
├── screens/
│   ├── camera_screen.dart
│   ├── history_screen.dart
│   └── settings_screen.dart
└── widgets/
    ├── text_overlay.dart
    ├── explanation_sheet.dart
    ├── comparison_view.dart
    └── shimmer_box.dart
```

---

## API Key Management

The user's OpenAI API key is needed. Options:

**Option A (v1 — simple):** User enters their own API key in Settings. Stored in EncryptedSharedPreferences. No backend needed.

**Option B (future):** Proxy server that holds the API key and rate-limits per device. More secure but requires a backend.

**v1 uses Option A.** The app is personal-use, no public distribution initially.

---

## Offline Behavior

- **OCR:** Works fully offline (ML Kit on-device).
- **AI Explanations:** Requires internet. If offline, show a clear message: "Connect to the internet for word explanations."
- **History:** Works fully offline (local Room DB).
