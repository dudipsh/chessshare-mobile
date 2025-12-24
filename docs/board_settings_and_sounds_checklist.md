# Board Settings & Sounds - Implementation Checklist

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

## What Needs to be Added

### 1. `practice_mistakes_screen.dart`
**Location:** `lib/features/games/screens/practice_mistakes_screen.dart`

**Add:**
- [ ] Import `board_settings_provider.dart`
- [ ] Import `board_settings_sheet.dart`
- [ ] Import `audio_service.dart`
- [ ] AppBar action with settings gear icon
- [ ] Use `boardSettingsProvider` for board colors/piece set
- [ ] Call `AudioService.playMoveSound()` on moves

### 2. `analysis_screen.dart`
**Location:** `lib/features/analysis/screens/analysis_screen.dart`

**Add:**
- [ ] Import `board_settings_provider.dart`
- [ ] Import `board_settings_sheet.dart`
- [ ] Import `audio_service.dart`
- [ ] AppBar action with settings gear icon
- [ ] Use `boardSettingsProvider` for board colors/piece set
- [ ] Call `AudioService.playMoveSound()` on moves

### 3. `game_review_screen.dart`
**Location:** `lib/features/games/screens/game_review_screen.dart`

**Add:**
- [ ] Import `audio_service.dart`
- [ ] Call `AudioService.playMoveSound()` when navigating moves

### 4. `puzzle_screen.dart`
**Location:** `lib/features/puzzles/screens/puzzle_screen.dart`

**Add:**
- [ ] Import `audio_service.dart`
- [ ] Call `AudioService.playMoveSound()` on moves

### 5. `daily_puzzle_screen.dart`
**Location:** `lib/features/puzzles/screens/daily_puzzle_screen.dart`

**Add:**
- [ ] Import `audio_service.dart`
- [ ] Call `AudioService.playMoveSound()` on moves

### 6. `play_vs_stockfish_screen.dart`
**Location:** `lib/features/games/screens/play_vs_stockfish_screen.dart`

**Add:**
- [ ] Import `audio_service.dart`
- [ ] Call `AudioService.playMoveSound()` on moves

---

## Required Imports

```dart
// For settings gear
import '../../../core/providers/board_settings_provider.dart';
import '../../../core/widgets/board_settings_sheet.dart';

// For sounds
import '../../../core/services/audio_service.dart';
```

## Settings Gear Implementation Pattern

```dart
// In AppBar actions:
IconButton(
  icon: const Icon(Icons.settings),
  onPressed: () => showBoardSettingsSheet(
    context: context,
    ref: ref,
    onFlipBoard: () {
      setState(() {
        _orientation = _orientation == Side.white ? Side.black : Side.white;
      });
    },
  ),
  tooltip: 'Board settings',
),

// In build method, get board settings:
final boardSettings = ref.watch(boardSettingsProvider);
final lightSquare = boardSettings.colorScheme.lightSquare;
final darkSquare = boardSettings.colorScheme.darkSquare;
final pieceAssets = boardSettings.pieceSet.pieceSet.assets;
```

## Sound Implementation Pattern

```dart
// Get audio service
final audioService = ref.read(audioServiceProvider);

// After a move is made, determine move type and play sound:
void _playMoveSound(NormalMove move, Chess positionBefore, Chess positionAfter) {
  final san = positionBefore.makeSan(move).$2;
  final isCapture = san.contains('x');
  final isCheck = san.contains('+') || san.contains('#');
  final isCastle = san == 'O-O' || san == 'O-O-O';
  final isCheckmate = positionAfter.isCheckmate;

  audioService.playMoveSound(
    isCapture: isCapture,
    isCheck: isCheck,
    isCastle: isCastle,
    isCheckmate: isCheckmate,
  );
}
```

---

## Priority Order

1. **High Priority** (missing both settings + sounds):
   - `practice_mistakes_screen.dart`
   - `analysis_screen.dart`

2. **Medium Priority** (missing sounds only):
   - `game_review_screen.dart`
   - `puzzle_screen.dart`
   - `daily_puzzle_screen.dart`
   - `play_vs_stockfish_screen.dart`

---

## Sound Files Required
Located in `assets/sounds/`:
- `move.wav` - Regular move
- `capture.wav` - Capture
- `check.wav` - Check
- `castle.wav` - Castling
- `illegal.wav` - Illegal move attempt
- `end-level.wav` - Checkmate/Game end
