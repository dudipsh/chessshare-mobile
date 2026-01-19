import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

import 'subscription_tier.dart';

/// LemonSqueezy checkout and billing service
class LemonSqueezyService {
  /// Store identifier
  static const _storeId = 'chessshare';

  /// Base checkout URL
  static String get _baseCheckoutUrl =>
      'https://$_storeId.lemonsqueezy.com/checkout/buy';

  /// Deep link scheme for the app
  static const deepLinkScheme = 'chessshare';

  /// Success URL for checkout
  static const successUrl = '$deepLinkScheme://billing/success';

  /// Get variant ID for a tier
  static String? getVariantId(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.basic:
        return dotenv.env['LEMONSQUEEZY_BASIC_VARIANT_ID'] ??
            '531f2049-8a77-42e2-ae95-b53c820af73b';
      case SubscriptionTier.pro:
        return dotenv.env['LEMONSQUEEZY_PRO_VARIANT_ID'] ??
            '9b16dc1d-d971-4ff2-831a-69fe9042c00a';
      default:
        return null;
    }
  }

  /// Build checkout URL for a subscription tier
  static String buildCheckoutUrl({
    required SubscriptionTier tier,
    required String userId,
    required String email,
  }) {
    final variantId = getVariantId(tier);
    if (variantId == null) {
      throw ArgumentError('No variant ID for tier: $tier');
    }

    final params = <String, String>{
      'checkout[custom][user_id]': userId,
      'checkout[email]': email,
      'checkout[success_url]': successUrl,
    };

    final uri = Uri.parse('$_baseCheckoutUrl/$variantId')
        .replace(queryParameters: params);

    return uri.toString();
  }

  /// Open checkout in external browser
  static Future<bool> openCheckout({
    required SubscriptionTier tier,
    required String userId,
    required String email,
  }) async {
    try {
      final url = buildCheckoutUrl(
        tier: tier,
        userId: userId,
        email: email,
      );

      debugPrint('LemonSqueezyService: Opening checkout URL: $url');

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('LemonSqueezyService: Error opening checkout: $e');
      return false;
    }
  }

  /// Check if a URI is a LemonSqueezy success deep link
  static bool isSuccessDeepLink(Uri uri) {
    return uri.scheme == deepLinkScheme &&
        uri.host == 'billing' &&
        uri.path == '/success';
  }

  /// Parse deep link to extract any parameters
  static Map<String, String> parseDeepLink(Uri uri) {
    return uri.queryParameters;
  }
}

/// Model for checkout session
class CheckoutSession {
  final SubscriptionTier tier;
  final String userId;
  final String email;
  final DateTime startedAt;

  CheckoutSession({
    required this.tier,
    required this.userId,
    required this.email,
  }) : startedAt = DateTime.now();

  /// Check if session has timed out (4 minutes)
  bool get isTimedOut {
    return DateTime.now().difference(startedAt) > const Duration(minutes: 4);
  }
}
