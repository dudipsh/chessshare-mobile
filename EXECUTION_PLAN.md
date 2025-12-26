# Execution Plan: Consistency & UX Fixes

## Current State Analysis

### Key Findings from Codebase Exploration

1. **No Unified Board Shell** - Each screen (Study, Game Review, Puzzle, Analysis, Play vs Stockfish, Practice Mistakes) implements its own board building with duplicated `_buildBoardSettings()` methods
2. **Captured Pieces NOT Implemented** - Zero UI for displaying captured pieces anywhere
3. **ChessboardSettings Duplicated 5+ Times** - Same 25-line configuration block repeated in:
   - `study_board_screen.dart:302-327`
   - `puzzle_screen.dart:178-208`
   - `analysis_screen.dart:224-261`
   - `review_chessboard.dart:34-64`
   - Plus inline versions in other screens
4. **Study Screen** - Uses separate navigation, no hamburger found in Study Game screen itself
5. **Evaluation Bar Exists** - Two versions: dynamic (`evaluation_bar.dart`) and static (`static_evaluation_bar.dart`)
6. **Stockfish Integration** - Well-structured with `GlobalStockfishManager` and pooling

### Reference Project Patterns (chessy-linker)

- Unified board modes (preview, study, analytics, puzzle)
- Captured pieces with material advantage calculation
- Vertical evaluation bar on left side of board
- Responsive multi-panel layouts
- Tab-based mode switching (Overview/Study/Analytics)

---

## Phase 1: Foundation - Unified Board Shell

**Goal:** Create a single, reusable board component that handles all common board functionality.

### Task 1.1: Create Board Settings Factory
**Files:** Create `lib/core/widgets/board_settings_factory.dart`

**Changes:**
- Extract duplicated `ChessboardSettings` creation into a single factory
- Support all existing color schemes and piece sets
- Reduce code duplication across 5+ screens

**Acceptance Criteria:**
- Single source of truth for board settings
- All screens use the factory instead of inline creation

### Task 1.2: Create Chess Board Shell Component
**Files:** Create `lib/core/widgets/chess_board_shell.dart`

**Changes:**
- Create wrapper component with:
  - Top slot (captured pieces - opponent's captures)
  - Board area (the actual chessboard)
  - Bottom slot (captured pieces - player's captures)
- Support orientation flip (which side is at bottom)
- Fixed height slots (small, consistent across all screens)

**Acceptance Criteria:**
- All board screens have identical top/bottom slot layout
- Empty slots still occupy space (consistent spacing)

### Task 1.3: Create Captured Pieces Display Widget
**Files:** Create `lib/core/widgets/captured_pieces_display.dart`

**Changes:**
- Display captured pieces in a compact row
- Pieces sized small (based on web reference: ~20px)
- Show material advantage indicator
- Support both colors (white/black captures)

**Acceptance Criteria:**
- Shows pieces captured by each side
- Updates in real-time during play
- Material advantage visible
- Consistent with web reference design

### Task 1.4: Create Captured Pieces State Management
**Files:** Create `lib/core/providers/captured_pieces_provider.dart`

**Changes:**
- Track captured pieces from FEN/PGN analysis
- Calculate material advantage (pawn=1, knight/bishop=3, rook=5, queen=9)
- Support undo/redo synchronization

---

## Phase 2: Study Feature Fixes

### Task 2.1: Study Main Page - One Board Per Row (A1)
**Files:** `lib/features/study/screens/study_screen.dart`

**Changes:**
- Modify grid layout from 2+ columns to single column
- Adjust card sizing for full-width display
- Maintain consistent spacing between cards

**Acceptance Criteria:**
- One study board card per row on all screen sizes
- Consistent margins/padding

### Task 2.2: Remove Hamburger + Line Name Opens Drawer (A2)
**Files:** `lib/features/study/screens/study_board_screen.dart`

**Changes:**
- Remove hamburger button from AppBar (if present)
- Make Line name tappable with visual feedback (cursor/ripple)
- Clicking Line name opens variation drawer/selector
- Add proper visual indication (chevron icon, underline, or color change)

**Acceptance Criteria:**
- No hamburger icon visible
- Line name looks clickable (hover/tap feedback)
- Tapping Line name opens drawer

### Task 2.3: Add Evaluation to Line Header (A3)
**Files:**
- `lib/features/study/screens/study_board_screen.dart`
- Create `lib/features/study/widgets/line_header.dart` (if needed)

**Changes:**
- Add evaluation number on the left side of Line name row
- Fetch evaluation from current position (FEN)
- Update on every move, undo, forward, back
- Format: +1.2, -0.4, M3 (mate in 3)

**Acceptance Criteria:**
- Evaluation visible at all times
- Updates dynamically with position changes
- Consistent formatting

### Task 2.4: Gray Button Scheme (A4)
**Files:**
- `lib/features/study/screens/study_board_screen.dart`
- `lib/features/study/widgets/` (any button widgets)

**Changes:**
- Change all Study buttons to gray color scheme
- Define states: default (gray), hover (lighter gray), disabled (very light gray)
- Apply to all control buttons (back, forward, hint, flip, reset)

**Acceptance Criteria:**
- All Study buttons use gray palette
- Clear visual states for default/hover/disabled
- No color leakage from other screens

### Task 2.5: Integrate Board Shell in Study (A5)
**Files:** `lib/features/study/screens/study_board_screen.dart`

**Changes:**
- Replace direct Chessboard usage with ChessBoardShell
- Connect captured pieces provider to Study game state
- Ensure captured pieces update correctly

**Acceptance Criteria:**
- Study screen uses ChessBoardShell
- Captured pieces display above/below board
- Consistent with other screens

---

## Phase 3: My Games Feature Fixes

### Task 3.1: Review Performance Optimization (B1)
**Files:**
- `lib/features/games/providers/game_analysis_provider.dart`
- `lib/core/services/global_stockfish_manager.dart`
- Related analysis code

**Changes:**
- Investigate multi-thread Stockfish options
- Check MultiPV settings (analyzing multiple lines simultaneously)
- Implement progressive loading (show early results while continuing analysis)
- Add visible progress indicator
- Consider caching analyzed positions

**Acceptance Criteria:**
- Time to first meaningful result reduced
- UI never blocks/freezes
- Progress indicator shows during long analysis
- Consider benchmark: measure before/after

### Task 3.2: Integrate Board Shell in My Games (B2)
**Files:**
- `lib/features/games/screens/game_review_screen.dart`
- `lib/features/games/screens/game_review/review_chessboard.dart`
- `lib/features/games/screens/practice_mistakes_screen.dart`
- `lib/features/games/screens/play_vs_stockfish_screen.dart`

**Changes:**
- Replace board implementations with ChessBoardShell
- Connect captured pieces tracking
- Ensure consistency across all My Games screens

**Acceptance Criteria:**
- All My Games boards use ChessBoardShell
- Captured pieces visible and updating
- Identical layout to Study boards

### Task 3.3: Remove First Bar + Reorder Elements (B3)
**Files:** `lib/features/games/screens/game_review_screen.dart`

**Changes:**
- Remove "best tap to explorer" bar completely
- Keep the "nice" bar (second bar)
- Reorder below board:
  1. Move history
  2. Nice bar
- Adjust styling if needed for consistency

**Acceptance Criteria:**
- First bar removed entirely
- Move history appears before the bar
- Layout matches design spec

### Task 3.4: Remove 3 Attempts Limit (B4)
**Files:**
- `lib/features/games/screens/practice_mistakes_screen.dart`
- Related providers/state management

**Changes:**
- Find and remove the 3-attempt limit check
- Allow unlimited Practice attempts
- Remove any UI showing attempt count (if exists)

**Acceptance Criteria:**
- Practice mode continues without limit
- No blocking after 3 attempts
- Clean UI without attempt counter

### Task 3.5: Code Quality & Consistency (B5)
**Files:** Multiple files in `lib/features/games/`

**Changes:**
- Extract shared components to reduce duplication
- Ensure spacing/typography matches Study screens
- Align button styles with gray scheme
- Break large files into smaller components if needed

**Acceptance Criteria:**
- No surprising visual differences between My Games and other screens
- Shared components used instead of duplicates
- Code follows established patterns

---

## Phase 4: Integration & Polish

### Task 4.1: Apply Board Shell to All Remaining Screens
**Files:**
- `lib/features/puzzles/screens/puzzle_screen.dart`
- `lib/features/puzzles/screens/daily_puzzle_screen.dart`
- `lib/features/analysis/screens/analysis_screen.dart`

**Changes:**
- Replace board implementations with ChessBoardShell
- Verify captured pieces work correctly
- Ensure consistent appearance

### Task 4.2: Remove Old Duplicated Code
**Files:** Multiple

**Changes:**
- Remove all old `_buildBoardSettings()` methods
- Remove unused board-building helper functions
- Clean up imports

### Task 4.3: Final QA & Testing
**Changes:**
- Test all board screens (Study, My Games, Puzzles, Analysis)
- Verify captured pieces update correctly
- Check evaluation updates in Study
- Verify performance improvements in Review
- Test on both iOS and Android

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing board functionality | High | Incremental migration, test each screen after change |
| Stockfish performance regression | Medium | Benchmark before/after, keep fallback path |
| Captured pieces calculation errors | Medium | Unit tests for piece counting logic |
| UI inconsistencies after migration | Medium | Visual regression testing |
| Large refactor scope creep | Medium | Strict adherence to task boundaries |

---

## QA Checkpoints

### After Phase 1 (Foundation):
- [ ] BoardSettingsFactory works with all color schemes
- [ ] ChessBoardShell renders correctly in isolation
- [ ] CapturedPiecesDisplay shows correct pieces
- [ ] No visual regressions in any screen

### After Phase 2 (Study):
- [ ] Study list shows one card per row
- [ ] Line name is clickable, opens drawer
- [ ] Evaluation shows and updates
- [ ] All buttons are gray
- [ ] Captured pieces visible

### After Phase 3 (My Games):
- [ ] Review loads faster (measurable improvement)
- [ ] First bar removed
- [ ] Move history before nice bar
- [ ] Practice unlimited
- [ ] Captured pieces visible

### After Phase 4 (Integration):
- [ ] All screens use ChessBoardShell
- [ ] No duplicate code remains
- [ ] Visual consistency across app
- [ ] No performance regressions

---

## Estimated Task Dependencies

```
Phase 1.1 (Settings Factory)
    ↓
Phase 1.2 (Board Shell) ← Phase 1.3 (Captured Display)
    ↓                           ↓
Phase 1.4 (Captured Provider) ←─┘
    ↓
┌───┴───────────────────────────────┐
↓                                   ↓
Phase 2 (Study)                Phase 3 (My Games)
↓                                   ↓
└───────────────┬───────────────────┘
                ↓
           Phase 4 (Integration)
```

---

## Files to Create (New)

1. `lib/core/widgets/board_settings_factory.dart`
2. `lib/core/widgets/chess_board_shell.dart`
3. `lib/core/widgets/captured_pieces_display.dart`
4. `lib/core/providers/captured_pieces_provider.dart`
5. `lib/features/study/widgets/line_header.dart` (optional, for evaluation display)

## Files to Modify (Existing)

1. `lib/features/study/screens/study_screen.dart` - one per row
2. `lib/features/study/screens/study_board_screen.dart` - drawer, eval, buttons, shell
3. `lib/features/games/screens/game_review_screen.dart` - shell, reorder, remove bar
4. `lib/features/games/screens/game_review/review_chessboard.dart` - use shell
5. `lib/features/games/screens/practice_mistakes_screen.dart` - shell, remove limit
6. `lib/features/games/screens/play_vs_stockfish_screen.dart` - shell
7. `lib/features/puzzles/screens/puzzle_screen.dart` - shell
8. `lib/features/puzzles/screens/daily_puzzle_screen.dart` - shell
9. `lib/features/analysis/screens/analysis_screen.dart` - shell
10. `lib/core/services/global_stockfish_manager.dart` - performance

---

## Summary

This plan addresses all PRD requirements through 4 phases:

1. **Phase 1**: Create foundational components (Board Shell, Captured Pieces, Settings Factory)
2. **Phase 2**: Fix Study screens (layout, navigation, evaluation, buttons)
3. **Phase 3**: Fix My Games screens (performance, layout, limits)
4. **Phase 4**: Apply changes to remaining screens and cleanup

Total new files: 4-5
Total modified files: 10-12

The approach prioritizes creating shared infrastructure first, then applying it to each feature area, ensuring consistency and reducing future maintenance burden.
