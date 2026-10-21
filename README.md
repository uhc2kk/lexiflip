# LexiFlip — offline vocabulary flashcards

One Flutter codebase for **Android, Windows / macOS / Linux and Web**.
Hive (Community Edition) for offline storage, Provider for state.

## Setup

```bash
# 1. Unzip, then generate the platform folders (keeps lib/ and pubspec.yaml)
cd lexiflip
flutter create . --project-name lexiflip --platforms=android,web,windows,macos,linux

# 2. Install packages
flutter pub get

# 3. Run
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
flutter run -d <android>   # Android device / emulator
```

Requires Flutter 3.27+.

### Required platform tweaks (after `flutter create`)

**Android** – auto-fill needs internet in release builds. In
`android/app/src/main/AndroidManifest.xml`, above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

**macOS** – add to both `macos/Runner/DebugProfile.entitlements` and
`Release.entitlements`:

```xml
<key>com.apple.security.network.client</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
```

**Linux** – `flutter_tts` has no Linux engine; the speaker button simply does
nothing there. Everything else works.

## Project structure

```
lib/
├── main.dart                     App entry, Providers, light/dark themes
├── models/
│   └── flashcard.dart            Flashcard model + hand-written Hive adapter
├── providers/
│   ├── deck_provider.dart        Cards, study position, CRUD, import merge
│   └── settings_provider.dart    Theme, target language, Gemini key
├── services/
│   ├── storage_service.dart      Hive init / boxes
│   ├── json_sync_service.dart    Export / import / merge logic
│   ├── file_bridge.dart          Conditional export (io vs web)
│   ├── file_bridge_io.dart       Android + Desktop save dialog
│   ├── file_bridge_web.dart      Browser download
│   ├── autofill_service.dart     Gemini / Free Dictionary / MyMemory
│   └── tts_service.dart          flutter_tts wrapper
├── widgets/
│   ├── flip_card.dart            3D flip animation widget
│   └── card_faces.dart           Front + back faces, auto-saving mnemonic
└── screens/
    ├── study_screen.dart         Flashcard study + keyboard shortcuts
    ├── card_editor_screen.dart   Add / edit with Auto-fill
    ├── card_list_screen.dart     Search, edit, "study from here"
    ├── settings_screen.dart      Theme, language, Gemini key
    └── sync_actions.dart         Export/Import UI (merge or replace)
```

No `build_runner` needed — the Hive adapter is hand-written and stores each
card as a map, so adding fields later never breaks existing data.

## Keyboard shortcuts (desktop / web)

| Key     | Action                       |
|---------|------------------------------|
| Space   | Flip card                    |
| ← / →   | Previous / next card         |
| P       | Pronounce word (TTS)         |
| Esc     | Leave the mnemonic field     |

On Android: tap to flip, swipe left/right to navigate.
Shortcuts are ignored while you're typing in a text field.

## Auto-fill

Type a word → press Enter or the ✨ button.

- **No key (default):** Free Dictionary API (IPA, example sentence, English
  synonym) + MyMemory (two translations). Free, no sign-up.
- **Gemini key set in Settings:** Gemini returns IPA, two translations and an
  example in one call; free APIs only fill anything Gemini missed.

Target language is chosen in Settings (default Uzbek). The mnemonic field is
never overwritten.

## Syncing PC ⇄ Android without a cloud

1. On device A: **⋮ → Export to JSON** → save the file.
2. Move it (USB, Telegram "Saved Messages", email, flash drive…).
3. On device B: **⋮ → Import from JSON** → choose **Merge** or **Replace**.

Merge matches cards by id, then by word; the most recently edited version
wins. Merge never deletes — to propagate deletions, use **Replace**.

File format:

```json
{
  "format": "lexiflip-deck",
  "version": 1,
  "exportedAt": "2026-10-21T12:00:00.000Z",
  "count": 1,
  "cards": [
    {
      "id": "6f1c…",
      "word": "resilient",
      "ipa": "/rɪˈzɪliənt/",
      "primaryTranslation": "…",
      "secondaryTranslation": "…",
      "mnemonic": "",
      "example": "Children are often remarkably resilient.",
      "createdAt": "2026-10-21T11:58:00.000Z",
      "updatedAt": "2026-10-21T11:58:00.000Z"
    }
  ]
}
```

A plain JSON array of card objects also imports, so you can bulk-create decks
by hand or in Excel → JSON.
