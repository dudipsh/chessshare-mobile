# Chess Mastery Flutter - Feature Roadmap

> Based on comprehensive analysis of web app (chessy-linker) vs Flutter app
> Last Updated: December 2024

---

## Current Status Summary

| Category | Web App | Flutter App | Status |
|----------|---------|-------------|--------|
| Core Features | 33 | 9 | ~27% complete |
| Screens/Pages | 28 | 12 | ~43% complete |
| Services | 40+ | 15 | ~37% complete |

### Completed Features
- [x] Google Sign-In + Supabase Auth
- [x] Import games (Chess.com & Lichess)
- [x] Game analysis with Stockfish
- [x] Move classification (Brilliant, Best, Good, Inaccuracy, Mistake, Blunder)
- [x] Accuracy calculation
- [x] Book move detection
- [x] Study boards - viewing & practicing
- [x] Puzzle solving from analysis mistakes
- [x] Player insights & analytics
- [x] Profile with linked chess accounts
- [x] Chess account stats display (ratings from Chess.com/Lichess)

---

# PRIORITY 0: INFRASTRUCTURE (Build First)

## 0.1 Feature Flag System
**Impact:** Critical | **Complexity:** Medium | **Est. Time:** 2-3 days

### Purpose
Control feature availability dynamically without app updates. Enable/disable features for:
- Free vs Premium users
- A/B testing
- Gradual rollouts
- Kill switches for broken features

### Implementation

**Files to Create:**
```
lib/core/
├── feature_flags/
│   ├── feature_flag_service.dart      # Fetch flags from Supabase
│   ├── feature_flag_provider.dart     # Riverpod state management
│   └── feature_flags.dart             # Flag definitions enum
```

**Flag Definitions:**
```dart
enum FeatureFlag {
  freeUserLimits,        // Enable subscription limits
  gamification,          // XP & Levels system
  dailyPuzzles,          // Daily puzzle feature
  practiceMistakes,      // Spaced repetition feature
  boardCreation,         // Allow users to create boards
  clubs,                 // Club system
  localNotifications,    // Reminder notifications
}
```

**How Flags Work (from Web):**
1. Flags stored in Supabase `feature_flags` table
2. User-specific flags in `user_feature_flags` table
3. Check via RPC: `get_user_feature_flags(user_id)`
4. Cache locally, refresh on app start
5. Admins always have all features enabled

### Guard Widget
```dart
class FeatureGuard extends ConsumerWidget {
  final FeatureFlag flag;
  final Widget child;
  final Widget? fallback;

  // Shows child if flag enabled, otherwise fallback or nothing
}
```

---

## 0.2 Subscription & Limits System
**Impact:** Critical | **Complexity:** Medium-High | **Est. Time:** 1 week

### Subscription Tiers

| Feature | FREE | BASIC | PRO |
|---------|------|-------|-----|
| **Game Analysis** | 2/day | 10/day | Unlimited |
| **Study Boards View** | 10/day | 50/day | Unlimited |
| **Study Variations** | First only | All | All |
| **Board Creation** | No | 5 boards | Unlimited |
| **Club Creation** | No | No | Yes |
| **Cover Image Upload** | No | Yes | Yes |
| **Priority Support** | No | No | Yes |
| **Price** | Free | $4.99/mo | $9.99/mo |

### Implementation

**Files to Create:**
```
lib/core/
├── subscription/
│   ├── subscription_service.dart      # Check/record limits
│   ├── subscription_provider.dart     # State management
│   ├── subscription_tier.dart         # Tier definitions
│   └── limits_tracker.dart            # Daily usage tracking
```

**Key Methods:**
```dart
class SubscriptionService {
  // Check if user can perform action
  Future<bool> canAnalyzeGame(String userId);
  Future<bool> canViewBoard(String userId, String boardId);
  Future<bool> canPlayVariation(String userId, int variationIndex);

  // Record usage (for daily limits)
  Future<void> recordAnalysis(String userId);
  Future<void> recordBoardView(String userId, String boardId);

  // Get remaining quota
  Future<int> getRemainingAnalyses(String userId);
  Future<int> getRemainingBoardViews(String userId);
}
```

**Limit Enforcement Flow:**
```
User Action → Check Limit →
  ├── Within Limit → Allow + Record Usage
  └── Exceeded → Show Upgrade Modal
```

### Supabase RPC Functions Needed
```sql
-- Track daily usage
get_free_user_daily_analysis_count(user_uuid)
record_free_user_analysis(user_uuid)
can_free_user_analyze(user_uuid) -- returns boolean

-- Board view limits
get_free_user_daily_views_count(user_uuid)
record_free_user_board_view(user_uuid, board_uuid)
can_free_user_view_board(user_uuid, board_uuid)
```

### Upgrade Modal
When limit reached, show modal with:
- Current plan info
- What they're missing
- Upgrade button (links to web for payment)

---

## 0.3 Gamification System
**Impact:** High | **Complexity:** Medium | **Est. Time:** 1 week

### XP & Level System

**Level Formula:** `Level = floor(XP / 200) + 1`
- Level 1: 0-199 XP
- Level 2: 200-399 XP
- Level 3: 400-599 XP
- etc.

### XP Awards

| Action | XP | Conditions |
|--------|-----|------------|
| **Complete Study Line** | 50 | First time only, not own board |
| **Solve Daily Puzzle** | 25-50 | Based on difficulty |
| **Complete Game Analysis** | 30 | Per game |
| **Daily Login Streak** | Variable | See below |
| **Practice Mistake** | 15 | Per correct answer |

### Daily Login Streak Bonuses

| Streak | Bonus XP |
|--------|----------|
| 2 days | +25 |
| 3 days | +35 |
| 5 days | +50 |
| 7 days | +75 |
| 14 days | +150 |
| 30 days | +300 |

### Implementation

**Files to Create:**
```
lib/features/gamification/
├── models/
│   ├── xp_event.dart
│   └── level_info.dart
├── services/
│   ├── gamification_service.dart     # XP logic & API
│   └── daily_login_service.dart      # Streak tracking
├── providers/
│   └── gamification_provider.dart
└── widgets/
    ├── xp_popup.dart                 # +50 XP animation
    ├── level_badge.dart              # Level display
    └── streak_modal.dart             # Daily streak popup
```

**GamificationService:**
```dart
class GamificationService {
  // Award XP
  Future<XpResult> awardXp(String userId, XpEventType event, {String? relatedId});

  // Get user stats
  Future<UserXpProfile> getUserProfile(String userId);

  // Check daily login
  Future<StreakResult> checkDailyLogin(String userId);

  // Fetch XP config from server
  Future<Map<XpEventType, int>> fetchXpConfiguration();
}
```

**XP Popup Widget:**
```dart
// Shows animated popup when XP earned:
// +50 XP Earned!
// Level 3 (150/200 XP)
// [Progress bar]
// Level Up! → "Chess Explorer" Unlocked
```

### Level Titles
| Level | Title |
|-------|-------|
| 1 | Beginner |
| 2 | Apprentice |
| 3 | Chess Explorer |
| 5 | Tactician |
| 10 | Strategist |
| 15 | Chess Master |
| 20 | Grandmaster |
| 25+ | Legend |

---

## 0.4 Local Notifications System
**Impact:** Medium | **Complexity:** Low-Medium | **Est. Time:** 2-3 days

### Purpose
Remind users to practice, maintain streaks, and stay engaged.

### Notification Types

| Type | When | Message Example |
|------|------|-----------------|
| **Daily Puzzle** | 9:00 AM | "Your daily puzzle is ready! Keep your streak going." |
| **Study Reminder** | 7:00 PM | "Time to practice! You have 3 boards to review." |
| **Streak Warning** | 8:00 PM | "Don't lose your 5-day streak! Complete a puzzle now." |
| **Analysis Ready** | After analysis | "Your game analysis is complete. See your mistakes." |
| **Weekly Summary** | Sunday 10 AM | "This week: 5 games analyzed, 82% accuracy. Keep improving!" |

### Implementation

**Package:** `flutter_local_notifications`

**Files to Create:**
```
lib/core/notifications/
├── local_notification_service.dart    # Setup & send notifications
├── notification_scheduler.dart        # Schedule recurring notifications
└── notification_settings.dart         # User preferences
```

**Settings (User Configurable):**
```dart
class NotificationSettings {
  bool dailyPuzzleReminder = true;
  TimeOfDay puzzleReminderTime = TimeOfDay(hour: 9, minute: 0);

  bool studyReminder = true;
  TimeOfDay studyReminderTime = TimeOfDay(hour: 19, minute: 0);

  bool streakWarning = true;
  bool weeklyDigest = true;
}
```

**Key Features:**
- Schedule notifications at user-preferred times
- Cancel notifications when action completed
- Respect user preferences
- Deep link to relevant screen when tapped

---

# PRIORITY 1: CRITICAL FEATURES

## 1.1 Practice Mistakes / Spaced Repetition
**Impact:** Very High | **Complexity:** High | **Est. Time:** 1-2 weeks

**What it does:** Save mistakes from game analysis to practice later with SM-2 scheduling

**Components:**
- `PersonalMistakesService` - Save/load mistakes
- `SpacedRepetitionService` - SM-2 algorithm
- `PracticeMistakesScreen` - Practice interface
- Local DB storage + Supabase sync

**Limit:** FREE users can save up to 10 mistakes, PRO unlimited

---

## 1.2 Daily Puzzles
**Impact:** Very High | **Complexity:** Medium | **Est. Time:** 1 week

**What it does:** Daily puzzle challenges with streak tracking

**Components:**
- Fetch from Lichess API or custom DB
- Date-based selection
- Streak tracking
- XP rewards

**Limit:** FREE users get 1 puzzle/day, PRO get 5

---

## 1.3 Board Creation & Editing
**Impact:** High | **Complexity:** High | **Est. Time:** 2 weeks

**What it does:** Create and share study boards

**Components:**
- Position editor
- Variation builder with PGN
- Cover image upload
- Privacy settings

**Limit:** FREE cannot create, BASIC can create 5, PRO unlimited

---

# PRIORITY 2: IMPORTANT FEATURES

## 2.1 Full Theme Customization
**Est. Time:** 2-3 days

- Board themes (8+ options)
- Piece sets (5+ options)
- Sound settings
- Persist preferences

---

## 2.2 Library System
**Est. Time:** 1 week

- Create/manage libraries
- Add boards to libraries
- Public/private visibility

---

## 2.3 Search & Discovery
**Est. Time:** 1 week

- Global search
- Filter by category
- Recent searches

---

## 2.4 Push Notifications (Firebase)
**Est. Time:** 1 week

- FCM setup
- Remote notifications
- Topic subscriptions

---

## 2.5 Account Settings
**Est. Time:** 3-4 days

- Notification preferences
- Privacy settings
- Delete account option

---

## 2.6 Multi-Language (Hebrew/English)
**Est. Time:** 1 week

- i18n setup
- RTL support
- Translation files

---

# PRIORITY 3: NICE TO HAVE

- Clubs System
- Follow System
- Leaderboard
- Board History
- Tags System
- Recommendations
- Feedback Button

---

# Implementation Roadmap

```
Phase 0 - Infrastructure (1-2 weeks):
├── 0.1 Feature Flag System
├── 0.2 Subscription & Limits
├── 0.3 Gamification (XP)
└── 0.4 Local Notifications

Phase 1 - Core Value (3-4 weeks):
├── 1.1 Practice Mistakes
├── 1.2 Daily Puzzles
└── 1.3 Board Creation

Phase 2 - Enhancement (2-3 weeks):
├── 2.1 Theme Customization
├── 2.2 Library System
└── 2.5 Account Settings

Phase 3 - Social (2-3 weeks):
├── 2.3 Search & Discovery
├── 2.4 Push Notifications
└── 2.6 Multi-Language

Phase 4 - Polish:
└── Remaining features
```

---

# Technical Architecture

## Provider Structure
```
lib/core/
├── feature_flags/
│   └── feature_flag_provider.dart
├── subscription/
│   └── subscription_provider.dart
├── notifications/
│   └── notification_provider.dart
└── gamification/
    └── gamification_provider.dart
```

## Supabase Tables Needed
```sql
-- Feature flags
feature_flags (id, code, name, is_globally_enabled)
user_feature_flags (user_id, flag_id, enabled)

-- Subscription & limits
user_subscriptions (user_id, tier, expires_at)
daily_usage_logs (user_id, action_type, count, date)

-- Gamification
user_xp (user_id, total_xp, level, updated_at)
xp_events (id, user_id, event_type, xp_amount, related_id, created_at)
xp_configuration (event_type, xp_value, is_active)
daily_login_streaks (user_id, current_streak, longest_streak, last_login_date)

-- Mistakes
personal_mistakes (id, user_id, game_id, fen, correct_move, user_move, next_review_date, ease_factor)
```

## Edge Functions Needed
```
add-xp-event        # Award XP with level-up detection
check-daily-login   # Check and award streak bonuses
```

---

# Quick Reference: Limits by Tier

| Action | FREE | BASIC | PRO |
|--------|------|-------|-----|
| Game Analysis/day | 2 | 10 | ∞ |
| Board Views/day | 10 | 50 | ∞ |
| Study Variations | 1st only | All | All |
| Board Creation | ✗ | 5 | ∞ |
| Saved Mistakes | 10 | 50 | ∞ |
| Daily Puzzles | 1 | 3 | 5 |
| Club Creation | ✗ | ✗ | ✓ |
| Cover Upload | ✗ | ✓ | ✓ |

---

*Document Updated: December 2024*
