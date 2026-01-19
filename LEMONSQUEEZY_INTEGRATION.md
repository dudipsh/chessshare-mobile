# LemonSqueezy Integration for Chess Mastery Flutter App

## Overview

This document describes how to integrate with the existing LemonSqueezy payment system used by the ChessShare web app. Both apps share the same Supabase backend, so we reuse the existing subscription infrastructure.

---

## Environment Configuration

```env
# LemonSqueezy Store
LEMONSQUEEZY_STORE_ID=chessshare

# Product Variant IDs
LEMONSQUEEZY_BASIC_VARIANT_ID=531f2049-8a77-42e2-ae95-b53c820af73b
LEMONSQUEEZY_PRO_VARIANT_ID=9b16dc1d-d971-4ff2-831a-69fe9042c00a
```

---

## Subscription Tiers & Limits

| Feature | FREE | BASIC ($4.99/mo) | PRO ($9.99/mo) |
|---------|------|------------------|----------------|
| Daily Board Views | 3 | 50 | Unlimited |
| Max Boards | 5 | 20 | Unlimited |
| Daily Game Reviews | 1 | 3 | Unlimited |
| Create Clubs | ❌ | ✅ | ✅ |
| Change Cover | ❌ | ✅ | ✅ |

---

## Database Schema (Existing in Supabase)

### profiles table (subscription fields)
```sql
subscription_type TEXT           -- 'FREE', 'BASIC', 'PRO'
subscription_start_date DATE     -- When subscription started
subscription_end_date DATE       -- When subscription expires/renews
lemonsqueezy_subscription_id TEXT -- For plan management
lemonsqueezy_customer_id TEXT    -- For billing portal
```

### subscription_notifications table (Real-time)
```sql
id UUID
user_id UUID                     -- References auth.users
event_type TEXT                  -- 'created', 'updated', 'cancelled'
new_subscription_type TEXT       -- 'BASIC', 'PRO', or NULL
created_at TIMESTAMP
-- Auto-cleanup: Rows older than 1 hour are deleted
```

### free_user_daily_views table (Rate limiting)
```sql
user_id UUID
board_id UUID
view_date DATE
viewed_at TIMESTAMP
-- Unique constraint: (user_id, board_id, view_date)
```

---

## RPC Functions Available

| Function | Purpose |
|----------|---------|
| `update_user_subscription(user_id, type, dates, notes)` | Update subscription |
| `get_user_subscription_info(user_id)` | Get subscription status |
| `can_free_user_view_board(user_id, board_id)` | Check if can view board |
| `record_free_user_board_view(user_id, board_id)` | Record a board view |
| `get_free_user_daily_views_count(user_id)` | Get daily view count |
| `get_free_user_remaining_views(user_id)` | Get remaining views today |
| `get_today_game_review_count(user_id)` | Get game reviews done today |

---

## Checkout Flow for Flutter

### 1. Build Checkout URL
```dart
String buildCheckoutUrl({
  required String variantId,
  required String userId,
  required String email,
}) {
  final baseUrl = 'https://chessshare.lemonsqueezy.com/checkout/buy/$variantId';
  final params = {
    'checkout[custom][user_id]': userId,
    'checkout[email]': email,
    'checkout[success_url]': 'chessshare://billing/success',
  };
  return Uri.parse(baseUrl).replace(queryParameters: params).toString();
}
```

### 2. Open in Browser
```dart
// Use url_launcher to open checkout in system browser
await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
```

### 3. Listen for Subscription Update
```dart
// Listen to subscription_notifications via Supabase Realtime
final subscription = supabase
  .from('subscription_notifications')
  .stream(primaryKey: ['id'])
  .eq('user_id', userId)
  .listen((data) {
    if (data.isNotEmpty) {
      // Subscription updated! Refresh user profile
      refreshSubscription();
    }
  });

// Timeout after 4 minutes
Future.delayed(Duration(minutes: 4), () => subscription.cancel());
```

### 4. Handle Deep Link (Success URL)
```dart
// Register custom URL scheme: chessshare://
// Handle: chessshare://billing/success
```

---

## Subscription Status Checking

### Get Current Subscription
```dart
Future<SubscriptionInfo> getSubscriptionInfo(String userId) async {
  final response = await supabase.rpc('get_user_subscription_info', params: {
    'p_user_id': userId,
  });
  return SubscriptionInfo.fromJson(response);
}
```

### Check Limits
```dart
// Check if can view board (FREE users)
Future<bool> canViewBoard(String userId, String boardId) async {
  final response = await supabase.rpc('can_free_user_view_board', params: {
    'p_user_id': userId,
    'p_board_id': boardId,
  });
  return response as bool;
}

// Check remaining game reviews
Future<int> getRemainingGameReviews(String userId, SubscriptionType type) async {
  final limit = getLimit(type).dailyGameReviews;
  if (limit == -1) return 999; // Unlimited

  final used = await supabase.rpc('get_today_game_review_count', params: {
    'p_user_id': userId,
  });
  return limit - (used as int);
}
```

---

## Plan Change Flow

### Upgrade/Downgrade
```dart
Future<void> changePlan(String newPlanType) async {
  // Call Edge Function
  final response = await supabase.functions.invoke('change-subscription', body: {
    'newPlan': newPlanType, // 'BASIC' or 'PRO'
  });

  if (response.status == 200) {
    // Optimistic update - refresh will confirm via Realtime
    refreshSubscription();
  }
}
```

---

## Implementation Checklist

### Services to Create
- [ ] `SubscriptionService` - Handle subscription logic
- [ ] `LemonSqueezyService` - Build checkout URLs, handle deep links

### Providers to Create
- [ ] `SubscriptionProvider` - State management for subscription

### Screens to Create/Update
- [ ] `SubscriptionScreen` - Show current plan & upgrade options
- [ ] `PaywallSheet` - Show when user hits a limit

### Integration Points
- [ ] Game Review - Check daily limit before allowing review
- [ ] Board Creation - Check max boards limit
- [ ] Study Board View - Check/record daily views for FREE users
- [ ] Club Creation - Check subscription tier

### Deep Link Setup
- [ ] iOS: Add `chessshare://` URL scheme to Info.plist
- [ ] Android: Add intent filter for `chessshare://`

---

## Webhook Events (Handled by Existing Backend)

| Event | Action |
|-------|--------|
| `subscription_created` | Activates subscription, saves LemonSqueezy IDs |
| `subscription_updated` | Updates renewal date or downgrades |
| `subscription_cancelled` | Downgrades to FREE |
| `subscription_paused` | Log only (retains access) |
| `subscription_resumed` | Reactivates subscription |

---

## Security Notes

1. **Always pass user_id** in checkout URL custom data
2. **Never trust client** - All limits enforced via RPC functions
3. **Realtime RLS** - subscription_notifications filtered by user_id
4. **Webhook signature** - Verified with HMAC-SHA256 (backend handles this)

---

## Testing

1. Use LemonSqueezy test mode for development
2. Test checkout flow with test card: `4242 4242 4242 4242`
3. Test webhook locally with ngrok or similar
4. Verify Realtime subscription updates work
