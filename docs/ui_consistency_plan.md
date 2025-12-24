# UI Consistency Plan - Premium Design System

## Current State Analysis

### Profile Screen (Target Design - Best UI)
- **Header**: NestedScrollView with SliverAppBar, collapsible header with avatar
- **Navigation**: Clean custom TabBar with underline indicator
- **Cards**: Soft background cards with `SectionCard` component
- **Stats**: Circular icon badges with primary color accent
- **Colors**: Consistent use of `isDark` with `Colors.grey[850]` / `Colors.grey[100]`
- **Empty States**: Clean with icon in circle, title, subtitle

### Games Screen (Issues)
- ❌ Standard AppBar (not matching Profile style)
- ❌ Different filter/action button styling
- ❌ Stats bar has different design language
- ❌ Platform switcher is custom but not matching overall style
- ✅ Uses RefreshIndicator
- ✅ Has search functionality

### Study Screen (Issues)
- ❌ TabBar in AppBar.bottom (different from Profile tabs)
- ❌ No collapsible header
- ❌ Stats use different `_buildMiniStat` component
- ❌ Gamification badges in AppBar (should be in header like Profile)
- ✅ Uses EmptyStateWidget from design_components
- ✅ Clean grid layout

### Daily Puzzle Screen (Issues)
- ❌ Very simple AppBar
- ❌ No header section
- ❌ Streak badge in AppBar actions (not consistent)
- ❌ Date navigation is inline, not as clean header
- ❌ Missing premium feel

### Puzzles List Screen (Issues)
- ❌ Basic AppBar with popup menu
- ❌ Card design uses outline border (not soft background)
- ❌ Empty state uses different styling
- ❌ No stats or header section

---

## Design System Elements (From Profile)

### 1. Color System
```dart
// Dark mode backgrounds
cardBg: Colors.grey[850]
surfaceBg: Colors.grey[900]
borderColor: Colors.grey[700] or Colors.grey[800]

// Light mode backgrounds
cardBg: Colors.grey[100]
surfaceBg: Colors.white
borderColor: Colors.grey[200] or Colors.grey[300]

// Accent colors
primary: AppColors.primary
secondary: AppColors.accent
```

### 2. Card Component
```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: isDark ? Colors.grey[850] : Colors.grey[100],
    borderRadius: BorderRadius.circular(12),
  ),
  child: content,
)
```

### 3. Section Title Style
```dart
Text(
  title,
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: isDark ? Colors.white : Colors.black87,
  ),
)
```

### 4. Stat Box Pattern
```dart
Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: AppColors.primary.withValues(alpha: 0.1),
    shape: BoxShape.circle,  // or borderRadius for boxes
  ),
  child: Icon(...),
)
```

### 5. Tab Bar (Custom)
```dart
Container(
  decoration: BoxDecoration(
    color: isDark ? Colors.grey[900] : Colors.white,
    border: Border(bottom: BorderSide(...)),
  ),
  child: Row(
    children: tabs.map((t) => _buildTab(t)),
  ),
)
```

### 6. Empty State
Use `EmptyStateWidget` from `design_components.dart`:
- Rounded square icon container (20px radius)
- Title: 18px, w600
- Subtitle: 14px, grey
- Optional action button

---

## Implementation Plan

### Phase 1: Bug Fixes (Priority)
1. **Fix Other User Profile Chess Accounts**
   - Problem: `ProfileNotifier._loadFromCache()` ignores userId
   - Solution: Don't use cache for other users, fetch fresh data

2. **Add Boards Tab to Profile**
   - Add "Boards" to ProfileTabBar (3 tabs: Overview, Boards, Stats)
   - Wire up BoardsTab component
   - Load boards when Boards tab selected

### Phase 2: Common Components
1. Create `AppSliverHeader` - reusable collapsible header
2. Create `AppPageScaffold` - standardized page structure
3. Create `AppTabBar` - consistent tab styling
4. Enhance `SectionCard` - more flexible options

### Phase 3: Screen Updates

#### Games Screen
- [ ] Replace AppBar with SliverAppBar + collapsible header
- [ ] Add gamification badges in header (like Profile)
- [ ] Move stats to collapsible header section
- [ ] Keep TabBar-style filter (All, Chess.com, Lichess)
- [ ] Use SectionCard for stats display
- [ ] Consistent card styling for game items

#### Study Screen
- [ ] Match Profile header structure (SliverAppBar)
- [ ] Move gamification badges from AppBar actions to header
- [ ] Keep tabs but style like Profile TabBar (in body, not AppBar.bottom)
- [ ] Consistent empty states (already using EmptyStateWidget)
- [ ] Stats header should use SectionCard style

#### Daily Puzzle Screen
- [ ] Add subtle header with streak and level badges
- [ ] Date navigation in clean card style
- [ ] Improve puzzle info presentation
- [ ] Add "Daily Challenge" branding section
- [ ] Keep chessboard as main focus

#### Puzzles List Screen
- [ ] Add header section with puzzle stats (total, solved, accuracy)
- [ ] Gamification badges
- [ ] Cards with soft background (no outline)
- [ ] Filter/sort options matching Games style
- [ ] Consistent empty state

---

## Visual Hierarchy (All Screens)

```
┌─────────────────────────────────────────┐
│  AppBar (pinned)                        │
│  - Title (left)                         │
│  - Actions: search, settings (right)    │
├─────────────────────────────────────────┤
│  Collapsible Header (optional)          │
│  - Avatar/Icon + Name (Profile style)   │
│  - Quick stats row                      │
│  - Gamification badges                  │
├─────────────────────────────────────────┤
│  Tab Bar (if applicable)                │
│  - Custom style, underline indicator    │
│  - Primary color for selected           │
├─────────────────────────────────────────┤
│  Content Area (scrollable)              │
│  - Padding: 16px all sides              │
│  - Cards with 12px border radius        │
│  - 12-16px spacing between sections     │
└─────────────────────────────────────────┘
```

---

## Files to Modify

### Bug Fixes
1. `lib/features/profile/providers/profile_provider.dart`
2. `lib/features/profile/widgets/profile_tab_bar.dart`
3. `lib/features/profile/widgets/profile_content.dart`

### Design Updates
4. `lib/features/games/screens/games_list_screen.dart`
5. `lib/features/study/screens/study_screen.dart`
6. `lib/features/puzzles/screens/daily_puzzle_screen.dart`
7. `lib/features/puzzles/screens/puzzles_list_screen.dart`

### New Components (if needed)
8. `lib/core/widgets/app_page_header.dart`
9. `lib/core/widgets/app_stats_row.dart`
