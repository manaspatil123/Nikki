# Nikki — App Overview

## What is Nikki?

Nikki is a mobile app for reading physical novels in foreign languages you're learning. Point your camera at a page, tap a word or phrase, and instantly get structured explanations — meaning, context, usage examples, and similar words for comparison. Every lookup is automatically saved into per-novel history so you can review and build vocabulary over time.

## Core Philosophy

- **Black and white UI only.** Clean, distraction-free, reader-focused.
- **No accounts, no login, no cloud sync.** Everything is local on-device.
- **No free-form prompting.** The app provides fixed, curated explanation categories — the user selects what they want, and AI handles the rest behind the scenes.
- **Minimal scope.** A few pages of functionality done extremely well. No bloat.

## Target User

Someone reading a physical novel in a language they don't speak (e.g., Japanese) who wants deep, structured understanding of individual words and phrases — not just raw translation.

## High-Level Flow

```
Camera Scan → Text Overlay → Tap Word/Phrase → Explanation Card → (Optional) Compare Similar Words
                                                    ↓
                                              Auto-saved to History
                                              (grouped by Novel)
```

## Platform

Flutter (Dart). Cross-platform (Android + iOS). Single app, no backend server.

## Lightweight Mandate

This app must stay light. Every dependency, feature, and asset is evaluated against:
- **APK size target:** Under 15 MB.
- **Minimal dependencies:** Only what's strictly needed. No utility mega-libraries.
- **On-device first:** ML Kit on-device (no cloud model downloads at runtime for OCR).
- **No background services:** App only does work when in foreground.
- **Lazy loading:** History and explanation data loaded on-demand, not pre-fetched.
- **No image caching:** Camera frames are processed and discarded, never stored.
- **Room over heavyweight ORMs:** SQLite via Room is the lightest local DB option.
- **Single-module project:** No multi-module overhead for an app this size.
