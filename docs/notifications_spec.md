# Notifications System - Specification Document

## Overview
מערכת התראות לאפליקציית ChessShare שמטרתה לעודד משתמשים לתרגל שחמט באופן יומיומי.

---

## 1. Notification Types

### 1.1 Daily Puzzle Reminder
**מטרה:** להזכיר למשתמש לפתור את הפאזל היומי

| Property | Value |
|----------|-------|
| ID | `daily_puzzle` |
| Default Time | 09:00 |
| Frequency | יומי |
| Icon | `extension` (puzzle piece) |
| Color | `#4CAF50` (green) |

**Content:**
```
Title: "Your Daily Puzzle Awaits"
Body: "Challenge yourself with today's puzzle and keep your streak going!"
```

**Trigger Conditions:**
- רק אם המשתמש לא פתר את הפאזל היומי היום
- לא שולח אם האפליקציה פתוחה

---

### 1.2 Game Puzzles Reminder (NEW)
**מטרה:** להזכיר למשתמש שיש לו פאזלים מהמשחקים שניתח

| Property | Value |
|----------|-------|
| ID | `game_puzzles` |
| Default Time | 19:00 |
| Frequency | יומי (אם יש פאזלים לא פתורים) |
| Icon | `sports_esports` |
| Color | `#2196F3` (blue) |

**Content:**
```
Title: "Practice Your Mistakes"
Body: "You have {count} puzzles from your games waiting. Learn from your errors!"
```

**Alternative (single puzzle):**
```
Title: "Practice Your Mistake"
Body: "A puzzle from your {opponent} game is waiting. Turn mistakes into mastery!"
```

**Trigger Conditions:**
- יש פאזלים שנוצרו מניתוח משחקים שלא נפתרו
- לפחות משחק אחד נותח ב-7 ימים האחרונים
- לא שולח אם כל הפאזלים נפתרו

---

### 1.3 Streak Warning
**מטרה:** להזהיר את המשתמש שהסטריק שלו בסכנה

| Property | Value |
|----------|-------|
| ID | `streak_warning` |
| Default Time | 20:00 |
| Frequency | יומי (אם לא היתה פעילות) |
| Icon | `local_fire_department` |
| Color | `#FF9800` (orange) |

**Content:**
```
Title: "Your Streak is at Risk!"
Body: "Complete a puzzle to keep your {streak_count} day streak alive!"
```

**Trigger Conditions:**
- למשתמש יש סטריק פעיל (> 1 יום)
- לא עשה פעילות היום (פאזל/לימוד)
- בטל אוטומטית אם המשתמש עשה פעילות

---

### 1.4 Weekly Summary
**מטרה:** סיכום שבועי של ההתקדמות

| Property | Value |
|----------|-------|
| ID | `weekly_digest` |
| Default Time | Sunday 10:00 |
| Frequency | שבועי |
| Icon | `bar_chart` |
| Color | `#9C27B0` (purple) |

**Content:**
```
Title: "Your Weekly Chess Journey"
Body: "This week: {puzzles_solved} puzzles, {games_analyzed} games analyzed, {accuracy}% avg accuracy"
```

---

## 2. Notification Design

### 2.1 Android
```
┌─────────────────────────────────────┐
│ [icon] ChessShare         now    ▼ │
├─────────────────────────────────────┤
│ [large_icon]  Title text here       │
│               Body text with more   │
│               details...            │
│                                     │
│               [Action 1] [Action 2] │
└─────────────────────────────────────┘
```

**Android Notification Channels:**
1. `chess_reminders_high` - Daily puzzle, Streak (High importance)
2. `chess_reminders_default` - Game puzzles, Weekly (Default importance)

### 2.2 iOS
Standard iOS notification with:
- Rich content (image of puzzle position if available)
- Sound: custom chess sound or default
- Badge: number of pending items

---

## 3. User Settings (Profile Screen)

### 3.1 Settings UI
```
Notifications
├── Enable Notifications [Toggle]
│
├── Daily Puzzle
│   ├── Enable [Toggle]
│   └── Time [TimePicker] 09:00
│
├── Game Puzzles (NEW)
│   ├── Enable [Toggle]
│   └── Time [TimePicker] 19:00
│
├── Streak Warning
│   ├── Enable [Toggle]
│   └── Time [TimePicker] 20:00
│
├── Weekly Summary
│   └── Enable [Toggle]
│
└── [Test Notification] button
```

### 3.2 Data Model Update
```dart
class NotificationSettings {
  // Existing
  bool notificationsEnabled;
  bool dailyPuzzleEnabled;
  TimeOfDay dailyPuzzleTime;
  bool streakWarningEnabled;
  TimeOfDay streakWarningTime;
  bool weeklyDigestEnabled;

  // NEW
  bool gamePuzzlesEnabled;        // default: true
  TimeOfDay gamePuzzlesTime;      // default: 19:00
  int minUnsolvedPuzzles;         // minimum puzzles to trigger (default: 1)
}
```

---

## 4. Logic & Triggers

### 4.1 When to Send Game Puzzles Notification

```dart
Future<bool> shouldSendGamePuzzlesNotification() async {
  // 1. Check if enabled
  if (!settings.gamePuzzlesEnabled) return false;

  // 2. Get unsolved game puzzles
  final unsolvedCount = await getUnsolvedGamePuzzlesCount();
  if (unsolvedCount < settings.minUnsolvedPuzzles) return false;

  // 3. Check if user already practiced today
  final todayActivity = await getTodayActivity();
  if (todayActivity.gamePuzzlesSolved > 0) return false;

  // 4. Check time window (don't spam)
  final lastSent = await getLastGamePuzzlesNotification();
  if (lastSent != null && lastSent.isToday) return false;

  return true;
}
```

### 4.2 Daily Puzzle Logic
```dart
Future<bool> shouldSendDailyPuzzleNotification() async {
  if (!settings.dailyPuzzleEnabled) return false;

  // Check if today's puzzle is solved
  final dailyPuzzle = await getDailyPuzzle();
  return !dailyPuzzle.isSolved;
}
```

### 4.3 Smart Dismissal (Already Implemented)
- After 3 ignored notifications, automatically disable that type
- Show dialog explaining: "We noticed you haven't been using these reminders..."
- Option to re-enable or keep disabled

---

## 5. Database Requirements

### 5.1 New Table: `notification_log`
```sql
CREATE TABLE notification_log (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,           -- 'daily_puzzle', 'game_puzzles', etc.
  sent_at TEXT NOT NULL,        -- ISO8601 timestamp
  opened_at TEXT,               -- NULL if not opened
  payload TEXT,                 -- JSON with notification details
  user_id TEXT NOT NULL
);
```

### 5.2 Query: Unsolved Game Puzzles Count
```sql
SELECT COUNT(*) FROM puzzles
WHERE source = 'game_analysis'
AND solved = 0
AND user_id = ?;
```

---

## 6. Testing

### 6.1 Test Button Functionality
```dart
Future<void> testNotification(NotificationType type) async {
  switch (type) {
    case NotificationType.dailyPuzzle:
      await showNotification(
        title: "Test: Daily Puzzle",
        body: "This is how your daily puzzle reminder will look!",
        payload: 'test_daily_puzzle',
      );
      break;
    case NotificationType.gamePuzzles:
      await showNotification(
        title: "Test: Game Puzzles",
        body: "You have 5 puzzles from your games waiting!",
        payload: 'test_game_puzzles',
      );
      break;
    // ... etc
  }
}
```

### 6.2 Debug Mode
Add debug screen showing:
- Scheduled notifications
- Last sent timestamps
- Permission status
- Next trigger time for each type

### 6.3 Manual Testing Steps
1. **Daily Puzzle:**
   - Set time to 1 minute from now
   - Close app
   - Wait for notification
   - Tap → should open daily puzzle screen

2. **Game Puzzles:**
   - Ensure at least 1 unsolved game puzzle exists
   - Set time to 1 minute from now
   - Close app
   - Wait for notification
   - Tap → should open puzzles list filtered to game puzzles

3. **Streak Warning:**
   - Have active streak
   - Don't complete any activity
   - Set time to 1 minute from now
   - Wait for notification

---

## 7. Navigation on Tap

| Notification Type | Destination |
|-------------------|-------------|
| `daily_puzzle` | `/daily-puzzle` |
| `game_puzzles` | `/puzzles?source=game_analysis` |
| `streak_warning` | `/daily-puzzle` |
| `weekly_digest` | `/insights` (or profile stats) |

---

## 8. Implementation Tasks

### Phase 1: Core (3-4 hours)
- [ ] Add `gamePuzzlesEnabled` and `gamePuzzlesTime` to NotificationSettings
- [ ] Create `scheduleGamePuzzlesReminder()` method
- [ ] Add unsolved game puzzles count provider
- [ ] Update notification service with new type

### Phase 2: UI (2-3 hours)
- [ ] Add Game Puzzles section to notification settings UI
- [ ] Add "Test Notification" button for each type
- [ ] Create debug screen for notification status

### Phase 3: Logic (2-3 hours)
- [ ] Implement `shouldSendGamePuzzlesNotification()` logic
- [ ] Add notification tap handling for new type
- [ ] Track notification opens in database

### Phase 4: Testing (1-2 hours)
- [ ] Test on Android physical device
- [ ] Test on iOS simulator/device
- [ ] Test all notification types
- [ ] Test permission flow

---

## 9. Open Questions

1. **Frequency:** Should game puzzles notification be daily or only when new puzzles are generated?
2. **Grouping:** Should we group multiple game puzzles into one notification or send separate?
3. **Rich Media:** Do we want to show the puzzle position as an image in the notification?
4. **Sound:** Custom chess sound for notifications?

---

## 10. Future Enhancements

1. **AI-Powered Timing:** Learn when user is most likely to engage
2. **Contextual Content:** "You made this mistake against e4 openings 3 times this week"
3. **Social Notifications:** "Your friend just beat their puzzle streak!"
4. **Achievement Unlocked:** Notify when close to unlocking achievement
