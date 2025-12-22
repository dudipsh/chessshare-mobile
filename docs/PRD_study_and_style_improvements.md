# PRD: Study Screen Enhancement & UI Style Consistency

## Overview
This document outlines improvements to the Study screen functionality and a unified design system to be applied across all app screens, starting with the Home screen.

---

## Part 1: Study Screen Enhancements

### Current State
- Study screen has 2 tabs: "Explore" and "My Studies"
- No local caching - data fetched from server on each visit
- No tracking of user interaction history (views, likes)

### Proposed Changes

#### 1.1 New Tabs Structure
| Tab | Description | Data Source |
|-----|-------------|-------------|
| **Explore** | Public studies with search | Server → Local cache |
| **My Studies** | User's created studies | Server → Local cache |
| **History** | Recently viewed boards | Local DB (board_views) |
| **Liked** | User's liked boards | Server → Local cache |

#### 1.2 Local-First Architecture

**Principle**: Display cached data immediately, then sync in background.

```
User opens screen
    ↓
Load from SQLite cache (instant)
    ↓
Display UI with cached data
    ↓
Background: Fetch from server
    ↓
Update cache + UI if changed
```

**Database Tables Needed:**

```sql
-- Track viewed boards locally
CREATE TABLE board_views (
  board_id TEXT PRIMARY KEY,
  viewed_at INTEGER NOT NULL,
  view_count INTEGER DEFAULT 1
);

-- Cache liked boards
CREATE TABLE board_likes_cache (
  board_id TEXT PRIMARY KEY,
  liked_at INTEGER NOT NULL
);

-- Cache study boards for offline access
CREATE TABLE study_boards_cache (
  id TEXT PRIMARY KEY,
  data TEXT NOT NULL,  -- JSON serialized StudyBoard
  cached_at INTEGER NOT NULL,
  source TEXT NOT NULL  -- 'explore', 'my_studies', 'liked'
);
```

#### 1.3 Provider Structure

```
study_provider.dart (existing)
├── studyListProvider (explore + my studies)
│
study_history_provider.dart (new)
├── studyHistoryProvider
│   ├── loadHistory() - from local DB
│   ├── recordView(boardId) - save to local DB
│   └── clearHistory()
│
study_likes_provider.dart (new)
├── studyLikesProvider
│   ├── loadLikedBoards() - cache first, then server
│   ├── toggleLike(boardId) - optimistic update
│   └── syncLikes() - background sync
```

#### 1.4 User Flows

**Viewing a Board:**
1. User taps on board card
2. `recordView(boardId)` called
3. Board added/updated in `board_views` table
4. History tab reflects new view

**Liking a Board:**
1. User taps like button
2. Optimistic UI update (heart fills)
3. Save to local `board_likes_cache`
4. Background: POST to server
5. If server fails → revert UI + show error

---

## Part 2: UI Style Consistency

### Current State
- Profile screen has polished, consistent styling
- Other screens (Home, Games, Study) have inconsistent styles
- No shared design tokens for spacing, cards, headers

### Design System Components

#### 2.1 Shared Style Tokens

```dart
// lib/app/theme/design_tokens.dart
class DesignTokens {
  // Spacing
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;

  // Border Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  // Card elevation
  static const double elevationLow = 2;
  static const double elevationMed = 4;
  static const double elevationHigh = 8;
}
```

#### 2.2 Reusable Components

| Component | Description | Used In |
|-----------|-------------|---------|
| `AppCard` | Consistent card with shadow/border | All screens |
| `AppSectionHeader` | Section title with optional action | Home, Profile |
| `AppTabBar` | Styled tab bar matching Profile | Study, Profile |
| `AppEmptyState` | Consistent empty state UI | All list screens |
| `AppLoadingShimmer` | Loading skeleton animation | All screens |

#### 2.3 Home Screen Improvements

**Current Home Screen:**
- Basic layout
- Inconsistent card styles
- No visual hierarchy

**Proposed Home Screen:**
```
┌─────────────────────────────────┐
│  Welcome back, {username}! 👋   │  ← Personalized header
├─────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐       │
│  │ Daily   │ │ Quick   │       │  ← Action cards (Profile style)
│  │ Puzzle  │ │ Play    │       │
│  └─────────┘ └─────────┘       │
├─────────────────────────────────┤
│  Recent Games ──────── See All │  ← Section header
│  ┌─────────────────────────────┐│
│  │ Game card (styled)          ││
│  └─────────────────────────────┘│
├─────────────────────────────────┤
│  Popular Studies ───── See All │
│  ┌────┐ ┌────┐ ┌────┐          │  ← Horizontal scroll
│  │    │ │    │ │    │          │
│  └────┘ └────┘ └────┘          │
└─────────────────────────────────┘
```

**Style Elements from Profile to Apply:**
1. Card shadows with subtle borders
2. Rounded corners (16px radius)
3. Consistent icon containers with tinted backgrounds
4. Section headers with uppercase labels
5. Smooth transitions and micro-interactions
6. Dark/light mode proper contrast

---

## Part 3: Implementation Plan

### Phase 1: Local Database Schema
- [ ] Add `board_views` table to local_database.dart
- [ ] Add `board_likes_cache` table
- [ ] Add `study_boards_cache` table
- [ ] Create migration if needed

### Phase 2: Study Providers
- [ ] Create `study_history_provider.dart`
- [ ] Create `study_likes_provider.dart`
- [ ] Update `study_provider.dart` with caching logic
- [ ] Add `StudyCacheService` for SQLite operations

### Phase 3: Study Screen UI
- [ ] Add History tab to study_screen.dart
- [ ] Add Liked tab to study_screen.dart
- [ ] Create `StudyHistoryGrid` widget
- [ ] Create `StudyLikedGrid` widget
- [ ] Wire up providers to UI

### Phase 4: Design System
- [ ] Create `design_tokens.dart`
- [ ] Create shared widgets (AppCard, AppSectionHeader, etc.)
- [ ] Document usage in code comments

### Phase 5: Home Screen Redesign
- [ ] Apply new design tokens
- [ ] Add personalized greeting
- [ ] Restyle action cards
- [ ] Add section headers
- [ ] Improve card styling
- [ ] Test dark/light modes

### Phase 6: Other Screens
- [ ] Apply style to Games screen
- [ ] Apply style to remaining screens
- [ ] Ensure consistency

---

## Success Metrics
1. **Performance**: Study screen loads < 200ms with cached data
2. **Offline**: History tab works fully offline
3. **Consistency**: All screens pass visual design review
4. **UX**: Smooth transitions, no layout jumps on data load

---

## Notes
- Web project has "Explore" and "My Studies" - we're adding History and Liked
- Likes sync with server's `board_likes` table
- History is local-only (privacy, no server sync needed)
- Style changes should not break existing functionality
