# Chess Board Performance Investigation

## Problem
Moving pieces on the chessboard feels laggy/stuttery. This is unacceptable for a chess app - piece movement must be instant and smooth.

---

## Investigation Checklist

### Phase 1: Identify the Bottleneck

#### 1.1 Check Timing Logs
- [ ] Run app and make moves in puzzle screen
- [ ] Capture logs with `[TIMING]` prefix
- [ ] Analyze which operation takes longest:
  - `_playMoveSound` operations
  - `Provider.makeMove` operations
  - Total `onMove` time

**Expected**: Each operation should be < 5ms. Total should be < 16ms (one frame at 60fps)

#### 1.2 Flutter Performance Overlay
- [ ] Enable performance overlay: `MaterialApp(showPerformanceOverlay: true)`
- [ ] Check if UI thread (blue) or GPU thread (green) is spiking
- [ ] Look for jank (frames > 16ms)

#### 1.3 DevTools Performance Tab
- [ ] Run `flutter run --profile`
- [ ] Open DevTools (press 'p' in terminal)
- [ ] Record a trace while making moves
- [ ] Look for:
  - Long build times
  - Excessive widget rebuilds
  - Layout thrashing

---

### Phase 2: Potential Causes & Fixes

#### 2.1 Chessground Package Issues
The `chessground` package might be doing expensive operations on every move.

**Check:**
- [ ] Read chessground source code for onMove callback
- [ ] Check if it's doing synchronous work before/after callback
- [ ] Look for any blocking operations

**Possible fixes:**
- [ ] Fork and optimize chessground
- [ ] Use a different chess board package
- [ ] Build custom lightweight board widget

#### 2.2 Excessive Widget Rebuilds
The entire screen might be rebuilding on every state change.

**Check:**
- [ ] Add `debugPrint('Building PuzzleScreen')` in build method
- [ ] Count how many times it prints per move
- [ ] Check if unrelated widgets are rebuilding

**Possible fixes:**
- [ ] Use `const` constructors where possible
- [ ] Split into smaller widgets with their own providers
- [ ] Use `select` to watch only specific state fields:
  ```dart
  final fen = ref.watch(puzzleSolveProvider.select((s) => s.currentFen));
  ```

#### 2.3 ValidMoves Calculation
`_convertToValidMoves` might be expensive if called during render.

**Check:**
- [ ] Add timing to `_convertToValidMoves`
- [ ] Check if it's called multiple times per move

**Possible fixes:**
- [ ] Cache valid moves in state
- [ ] Only recalculate when position changes

#### 2.4 FEN Parsing on Every Sound
`_playMoveSound` parses FEN and creates Chess position just for sound.

**Check:**
- [ ] This is redundant - position already exists in provider

**Fix:**
- [ ] Pass move type info from provider instead of recalculating
- [ ] Or remove sound logic from screen entirely

#### 2.5 Sound/Haptic Still Blocking
Even with PostFrameCallback, the scheduling itself might cause micro-delays.

**Check:**
- [ ] Try completely disabling sound and haptic
- [ ] See if movement becomes smooth

**Fix:**
- [ ] Use `Timer.run()` instead of PostFrameCallback
- [ ] Or use Isolate for sound
- [ ] Switch to lichess/flutter-sound-effect package

#### 2.6 State Update Triggering Full Rebuild
`state = state.copyWith(...)` might trigger expensive rebuilds.

**Check:**
- [ ] Use Flutter DevTools widget rebuild counts
- [ ] Check if Chessboard widget has efficient `shouldRepaint`

**Fix:**
- [ ] Use more granular state (separate providers for different concerns)
- [ ] Implement custom `==` operator for state

---

### Phase 3: Alternative Solutions

#### 3.1 Replace Audio Package
Current: `audioplayers`
Alternative: `flutter_sound_effect` by lichess

```yaml
dependencies:
  sound_effect:
    git:
      url: https://github.com/lichess-org/flutter-sound-effect
```

This package is specifically designed for chess apps with minimal latency.

#### 3.2 Optimized Move Handling
Instead of:
```dart
onMove: (move, {isDrop}) {
  _playMoveSound(move, state.currentFen);  // Expensive!
  notifier.makeMove(move);
}
```

Do:
```dart
onMove: (move, {isDrop}) {
  notifier.makeMove(move);  // Provider handles everything
  // Sound/haptic triggered AFTER state update, in provider
}
```

#### 3.3 Move Sound Info from Provider
Add to state:
```dart
class PuzzleSolveState {
  // ...existing fields...
  final MoveType? lastMoveType;  // capture, check, castle, normal
}
```

Then play sound based on state change, not in callback.

#### 3.4 Use RepaintBoundary
Wrap chessboard in RepaintBoundary to isolate repaints:
```dart
RepaintBoundary(
  child: Chessboard(...),
)
```

#### 3.5 Defer Non-Critical Work
```dart
onMove: (move, {isDrop}) {
  // Only do the essential work
  notifier.makeMove(move);

  // Defer everything else
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Sound, haptic, analytics, etc.
  });
}
```

---

### Phase 4: Testing Procedure

#### 4.1 Baseline Test
1. Disable ALL sound and haptic
2. Make 10 moves rapidly
3. Record if lag still exists
4. Result: _______________

#### 4.2 Sound Only Test
1. Enable sound, disable haptic
2. Make 10 moves rapidly
3. Record if lag exists
4. Result: _______________

#### 4.3 Haptic Only Test
1. Disable sound, enable haptic
2. Make 10 moves rapidly
3. Record if lag exists
4. Result: _______________

#### 4.4 Provider-Only Test
1. Comment out `_playMoveSound` call entirely
2. Make 10 moves rapidly
3. Record if lag exists
4. Result: _______________

#### 4.5 Minimal Board Test
1. Create test screen with ONLY chessboard, no providers
2. Make moves (they won't work but piece should drag smoothly)
3. Record if dragging is smooth
4. Result: _______________

---

### Phase 5: Implementation Priority

1. **Immediate**: Run baseline test (disable sound/haptic)
2. **If still laggy**: Problem is in chessground or state management
3. **If smooth**: Problem is in sound/haptic code
4. **Next step based on result**:
   - If chessground issue → Consider forking or replacing
   - If state issue → Optimize rebuilds with select()
   - If sound issue → Switch to lichess sound_effect package

---

## Quick Wins to Try First

```dart
// 1. In puzzle_screen.dart, temporarily disable sound/haptic:
onMove: (move, {isDrop}) {
  // _playMoveSound(move, state.currentFen);  // DISABLED
  notifier.makeMove(move);
},

// 2. Add RepaintBoundary around board:
RepaintBoundary(
  child: Chessboard(...),
)

// 3. Use Timer.run instead of PostFrameCallback:
Timer.run(() {
  player.resume();
});
```

---

## Files to Investigate

| File | What to Check |
|------|---------------|
| `lib/features/puzzles/screens/puzzle_screen.dart` | onMove callback, rebuilds |
| `lib/features/puzzles/providers/puzzle_provider.dart` | makeMove performance, state updates |
| `lib/core/services/audio_service.dart` | Sound playback timing |
| `lib/core/providers/board_settings_provider.dart` | Haptic trigger timing |
| `packages/chessground/` | External package - may need fork |

---

## Success Criteria

- [ ] Piece movement feels instant (< 16ms total)
- [ ] No visual stutter when moving pieces
- [ ] Sound plays without affecting movement
- [ ] Haptic feedback works without affecting movement
- [ ] Consistent performance across iOS and Android
