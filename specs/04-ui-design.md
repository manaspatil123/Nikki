# UI / UX Design Specification

## Design Principles

1. **Black and white only.** No accent colors. Use weight, size, and spacing for hierarchy.
2. **High contrast.** Pure black (#000000) and pure white (#FFFFFF) with grays (#333, #666, #999, #CCC, #F5F5F5) only.
3. **Typography-driven.** Large, readable text. Generous line spacing.
4. **Minimal chrome.** Hide controls until needed. Let content breathe.
5. **One-hand friendly.** Key interactions reachable with thumb.

---

## Color Palette

| Token | Light Mode | Dark Mode |
|---|---|---|
| Background | #FFFFFF | #000000 |
| Surface | #F5F5F5 | #1A1A1A |
| On Background | #000000 | #FFFFFF |
| On Surface | #333333 | #CCCCCC |
| Border | #CCCCCC | #333333 |
| Disabled | #999999 | #666666 |
| Highlight (selection) | #000000 bg, #FFFFFF text | #FFFFFF bg, #000000 text |

Both light and dark mode supported, but always monochrome.

---

## Typography

| Role | Font | Size | Weight |
|---|---|---|---|
| Page title | System default (sans-serif) | 20sp | Bold |
| Section header | System default | 16sp | SemiBold |
| Body text | System default | 14sp | Regular |
| Selected word (card title) | System default | 24sp | Bold |
| Reading/pronunciation | System default | 16sp | Regular |
| Caption / timestamp | System default | 12sp | Regular |
| Novel tab label | System default | 14sp | Medium |

For Japanese/CJK text, use system default which resolves to Noto Sans CJK on Android.

---

## Screen Layouts

### S1: Camera Screen (Main Screen)

```
┌─────────────────────────────────────┐
│ [JP ▼]    「Pet Sematary ▼」  [EN ▼] │  ← Language + Novel selectors
│                                     │
│                                     │
│                                     │
│         (Camera Viewfinder)         │
│                                     │
│     ┌─────────────────────────┐     │
│     │ OCR text overlay here   │     │
│     │ 古い墓地の猫は夜に      │     │
│     │ [墓地] ← selected       │     │
│     └─────────────────────────┘     │
│                                     │
│                                     │
│  🚫 Don't Save          [History]   │  ← Bottom bar
│         ┌─────────┐                 │
│         │  ◉ Snap  │                │  ← Optional freeze button
│         └─────────┘                 │
└─────────────────────────────────────┘
```

**Notes:**
- Camera fills the entire screen edge-to-edge.
- Top bar is semi-transparent black overlay.
- Bottom bar is semi-transparent black overlay.
- OCR text overlays match the physical position of text in camera.
- "Don't Save" shown as a toggle with crossed-out bookmark icon.

### S2: Explanation Card (Bottom Sheet)

```
┌─────────────────────────────────────┐
│  ━━━  (drag handle)                 │
│                                     │
│  墓地                               │
│  ぼち (bochi)                       │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  MEANING                            │
│  A graveyard or burial ground.      │
│                                     │
│  CONTEXT                            │
│  Refers to the pet cemetery that    │
│  becomes central to the story.      │
│                                     │
│  EXAMPLES                           │
│  • 古い墓地を訪れた。                │
│    (I visited an old graveyard.)    │
│  • この墓地は江戸時代から…            │
│    (This graveyard has been since…) │
│                                     │
│  BREAKDOWN                          │
│  墓 (grave) + 地 (ground/place)     │
│                                     │
│  SIMILAR WORDS                      │
│  ┌────────┐ ┌────────────┐ ┌─────┐ │
│  │  霊園   │ │  共同墓地   │ │ ... │ │
│  └────────┘ └────────────┘ └─────┘ │
│                                     │
└─────────────────────────────────────┘
```

**Notes:**
- Bottom sheet with 3 states: peek (shows word + meaning), half, full.
- Category headers in ALL CAPS, small, bold, with spacing above.
- Similar word chips are outlined rectangles, tappable.
- Scrollable content inside the sheet.
- While loading, show a simple skeleton shimmer (gray bars).

### S3: Comparison View (Overlay on Explanation Card)

```
┌─────────────────────────────────────┐
│  ← Back                            │
│                                     │
│  墓地  vs  霊園                      │
│  bochi    reien                     │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  DIFFERENCE                         │
│  墓地 is a general term for any     │
│  graveyard. 霊園 specifically means  │
│  a landscaped memorial park.        │
│                                     │
│  NUANCE                             │
│  墓地 can feel somber or old.        │
│  霊園 feels more modern, peaceful.   │
│                                     │
│  EXAMPLES                           │
│  墓地: 古い墓地を歩いた。            │
│  霊園: 霊園に花を供えた。            │
│                                     │
└─────────────────────────────────────┘
```

### S4: History Screen

```
┌─────────────────────────────────────┐
│  ← Back              ⚙ Settings     │
│                                     │
│  ┌──────────┬──────────┬─────┐      │
│  │Pet       │Norwegian │  +  │      │
│  │Sematary  │Wood      │     │      │
│  └──────────┴──────────┴─────┘      │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🔍 Search words...          │    │
│  └─────────────────────────────┘    │
│                                     │
│  墓地 (bochi)                       │
│  graveyard                 Mar 15   │
│  ───────────────────────────────    │
│  猫 (neko)                          │
│  cat                       Mar 14   │
│  ───────────────────────────────    │
│  恐怖 (kyōfu)                       │
│  fear                      Mar 14   │
│  ───────────────────────────────    │
│                                     │
│  [Empty state: "No words yet.       │
│   Start scanning to build your      │
│   vocabulary."]                     │
│                                     │
└─────────────────────────────────────┘
```

**Notes:**
- Novel tabs scroll horizontally if many.
- Each word row shows: word, reading, brief meaning, date.
- Tapping opens the cached Explanation Card.
- Long-press to delete.
- Pull-to-refresh not needed (local data).

### S5: Settings Screen

```
┌─────────────────────────────────────┐
│  ← Settings                         │
│                                     │
│  EXPLANATION CATEGORIES             │
│  ───────────────────────────────    │
│  ■ Meaning                    [ON]  │
│  ■ Reading / Pronunciation    [ON]  │
│  ■ Context                    [ON]  │
│  ■ Examples                   [ON]  │
│  ■ Breakdown                  [ON]  │
│  ■ Formality                  [OFF] │
│  ■ Similar Words              [ON]  │
│                                     │
│  DEFAULTS                           │
│  ───────────────────────────────    │
│  Source Language          Japanese ▶ │
│  Target Language          English ▶ │
│                                     │
│  API KEY                            │
│  ───────────────────────────────    │
│  OpenAI API Key           ••••sk ▶  │
│                                     │
│  DATA                               │
│  ───────────────────────────────    │
│  Export History                   ▶  │
│  Clear All History               ▶  │
│                                     │
│  ABOUT                              │
│  ───────────────────────────────    │
│  Version                     1.0.0  │
│                                     │
└─────────────────────────────────────┘
```

---

## Animations & Transitions

| Interaction | Animation |
|---|---|
| Bottom sheet open | Slide up with spring physics |
| Screen navigation | Shared element: word text morphs from list to card |
| Loading AI response | Skeleton shimmer (light gray bars pulsing) |
| Word selection on camera | Quick scale-up (1.0 → 1.05 → 1.0) with highlight |
| Delete word | Swipe-to-dismiss with fade |
| Tab switch | Crossfade content |

---

## Accessibility

- Minimum touch target: 48dp.
- All interactive elements have content descriptions.
- Support system font scaling.
- High contrast already ensured by black/white palette.
