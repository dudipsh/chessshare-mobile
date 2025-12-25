# Board Settings & Sounds - Implementation Checklist

---

## 🔴 BUGS TO FIX (Priority)

### 1. Mute Not Working
- [ ] Mute toggle doesn't actually silence sounds
- [ ] Check where `setEnabled(false)` is called from UI
- [ ] Verify `_enabled` flag is respected in `_playSound()`
- [ ] Check if mute setting is persisted and loaded correctly
- **Location:** `lib/core/services/audio_service.dart`

### 2. Sound Stuttering on Mobile
- [ ] Sounds feel choppy/stuttering on mobile devices
- [ ] Investigate timing - when exactly is the sound triggered?
- [ ] Consider pre-loading sounds on app start
- [ ] Try `AudioPlayer.setSource()` to pre-cache audio
- [ ] Test with `ReleaseMode.stop` vs `ReleaseMode.release`
- [ ] Test on both iOS and Android physical devices

---

## 🟡 NEW FEATURES TO ADD

### 3. Haptic Feedback (Vibration)
- [ ] Add vibration option to board settings
- [ ] Make it reusable across ALL boards (games, puzzles, analysis)
- [ ] Use the SAME settings wheel that already exists (keep it unified)
- [ ] Small vibration when making a move
- [ ] Settings should include:
  - Sound on/off (existing)
  - Vibration on/off (NEW)
- [ ] Use Flutter's `HapticFeedback.lightImpact()` or `vibration` package
- [ ] Add to `BoardSettingsState` and `board_settings_provider.dart`
- [ ] Update `board_settings_sheet.dart` to include vibration toggle

### 4. Test Push Notifications
- [ ] Document how to test push notifications work
- [ ] Options to test:
  - Firebase Console → Cloud Messaging → Send test message
  - Use device token from logs
  - Supabase Edge Functions trigger
- [ ] Must test on PHYSICAL device (not simulator for iOS)
- [ ] Check device token is registered in Supabase `push_tokens` table

---

## Current State Analysis

### Screens with Chessboard:

| Screen | Settings Gear | Sounds | Status |
|--------|--------------|--------|--------|
| `study_board_screen.dart` | YES | YES | ✅ Complete |
| `game_review_screen.dart` | YES | YES | ✅ Complete |
| `puzzle_screen.dart` | YES | YES | ✅ Complete |
| `daily_puzzle_screen.dart` | YES | YES | ✅ Complete |
| `play_vs_stockfish_screen.dart` | YES | YES | ✅ Complete |
| `practice_mistakes_screen.dart` | YES | YES | ✅ Complete |
| `analysis_screen.dart` | YES | YES | ✅ Complete |

---

## Technical Notes

### Audio Service
**Location:** `lib/core/services/audio_service.dart`

### Board Settings Provider
**Location:** `lib/core/providers/board_settings_provider.dart`

### Board Settings Sheet (UI)
**Location:** `lib/core/widgets/board_settings_sheet.dart`

---

## Haptic Feedback Implementation Plan

```dart
// In board_settings_provider.dart - add to state:
final bool vibrationEnabled;

// In board_settings_sheet.dart - add toggle:
SwitchListTile(
  title: Text('Vibration'),
  subtitle: Text('Vibrate on moves'),
  value: settings.vibrationEnabled,
  onChanged: (value) => ref.read(boardSettingsProvider.notifier).setVibrationEnabled(value),
),

// When making a move (in all board screens):
if (boardSettings.vibrationEnabled) {
  HapticFeedback.lightImpact();
}
```

---

## Sound Files
Located in `assets/sounds/`:
- `move.wav` - Regular move
- `capture.wav` - Capture
- `check.wav` - Check (volume: 0.5)
- `castle.wav` - Castling
- `illegal.wav` - Illegal move attempt
- `end-level.wav` - Checkmate/Game end

---

## Priority Order

1. 🔴 **Fix Mute** - Bug, users expect it to work
2. 🔴 **Fix Stuttering** - Bad UX on mobile
3. 🟡 **Add Vibration** - Feature request
4. 🟡 **Test Notifications** - Verification
