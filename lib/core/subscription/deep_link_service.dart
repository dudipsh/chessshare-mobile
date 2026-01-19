import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'lemonsqueezy_service.dart';

/// Callback for when checkout is successful
typedef OnCheckoutSuccess = void Function();

/// Service for handling deep links, particularly for LemonSqueezy checkout
class DeepLinkService {
  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._();

  DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;

  /// Callback when checkout success deep link is received
  OnCheckoutSuccess? onCheckoutSuccess;

  /// Initialize the deep link handler
  Future<void> initialize() async {
    // Handle initial link (app launched from deep link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error getting initial link: $e');
    }

    // Handle links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (e) {
        debugPrint('DeepLinkService: Error in link stream: $e');
      },
    );
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri) {
    debugPrint('DeepLinkService: Received deep link: $uri');

    // Check if it's a LemonSqueezy checkout success
    if (LemonSqueezyService.isSuccessDeepLink(uri)) {
      debugPrint('DeepLinkService: Checkout success!');
      onCheckoutSuccess?.call();
      return;
    }

    // Handle other deep links here
    // e.g., chessshare://board/123, chessshare://game/456
    _handleOtherDeepLinks(uri);
  }

  /// Handle other types of deep links
  void _handleOtherDeepLinks(Uri uri) {
    // Add support for other deep links as needed
    // For example:
    // - chessshare://board/{boardId}
    // - chessshare://game/{gameId}
    // - chessshare://profile/{userId}

    debugPrint('DeepLinkService: Unhandled deep link: $uri');
  }

  /// Dispose the service
  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}
