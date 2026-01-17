import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/supabase_service.dart';

/// Version control configuration from server
class VersionConfig {
  final String minVersionAndroid;
  final String minVersionIos;
  final String latestVersionAndroid;
  final String latestVersionIos;
  final bool forceUpdate;
  final String updateMessageEn;
  final String updateMessageHe;
  final String playStoreUrl;
  final String appStoreUrl;

  const VersionConfig({
    required this.minVersionAndroid,
    required this.minVersionIos,
    required this.latestVersionAndroid,
    required this.latestVersionIos,
    required this.forceUpdate,
    required this.updateMessageEn,
    required this.updateMessageHe,
    required this.playStoreUrl,
    required this.appStoreUrl,
  });

  factory VersionConfig.fromJson(Map<String, dynamic> json) {
    return VersionConfig(
      minVersionAndroid: json['min_version_android'] as String? ?? '1.0.0',
      minVersionIos: json['min_version_ios'] as String? ?? '1.0.0',
      latestVersionAndroid: json['latest_version_android'] as String? ?? '1.0.0',
      latestVersionIos: json['latest_version_ios'] as String? ?? '1.0.0',
      forceUpdate: json['force_update'] as bool? ?? false,
      updateMessageEn: json['update_message_en'] as String? ?? 'Please update the app.',
      updateMessageHe: json['update_message_he'] as String? ?? 'אנא עדכן את האפליקציה.',
      playStoreUrl: json['play_store_url'] as String? ?? '',
      appStoreUrl: json['app_store_url'] as String? ?? '',
    );
  }

  String get minVersion => Platform.isIOS ? minVersionIos : minVersionAndroid;
  String get latestVersion => Platform.isIOS ? latestVersionIos : latestVersionAndroid;
  String get storeUrl => Platform.isIOS ? appStoreUrl : playStoreUrl;
}

/// Result of update check
enum UpdateStatus {
  upToDate,
  updateAvailable,
  forceUpdateRequired,
  error,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final String? message;
  final String? storeUrl;
  final String? currentVersion;
  final String? latestVersion;

  const UpdateCheckResult({
    required this.status,
    this.message,
    this.storeUrl,
    this.currentVersion,
    this.latestVersion,
  });
}

/// Service to check for app updates and handle force update
class ForceUpdateService {
  static VersionConfig? _cachedConfig;

  /// Check if update is required
  static Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      debugPrint('ForceUpdateService: Current version: $currentVersion');

      // Fetch version config from server
      final config = await _fetchVersionConfig();
      if (config == null) {
        return const UpdateCheckResult(status: UpdateStatus.error);
      }

      _cachedConfig = config;

      final minVersion = config.minVersion;
      final latestVersion = config.latestVersion;

      debugPrint('ForceUpdateService: Min version: $minVersion, Latest: $latestVersion');

      // Check if current version is below minimum (force update)
      if (_isVersionLower(currentVersion, minVersion)) {
        return UpdateCheckResult(
          status: UpdateStatus.forceUpdateRequired,
          message: config.updateMessageHe,
          storeUrl: config.storeUrl,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
        );
      }

      // Check if update is available (optional update)
      if (_isVersionLower(currentVersion, latestVersion)) {
        return UpdateCheckResult(
          status: UpdateStatus.updateAvailable,
          message: config.updateMessageHe,
          storeUrl: config.storeUrl,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
        );
      }

      return UpdateCheckResult(
        status: UpdateStatus.upToDate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
      );
    } catch (e) {
      debugPrint('ForceUpdateService: Error checking for update: $e');
      return const UpdateCheckResult(status: UpdateStatus.error);
    }
  }

  /// Fetch version config from Supabase
  static Future<VersionConfig?> _fetchVersionConfig() async {
    try {
      final response = await SupabaseService.client
          .from('app_config')
          .select('value')
          .eq('key', 'version_control')
          .single();

      final value = response['value'];
      if (value != null) {
        return VersionConfig.fromJson(value as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('ForceUpdateService: Error fetching version config: $e');
      return null;
    }
  }

  /// Compare two version strings (e.g., "1.0.0" vs "1.0.1")
  /// Returns true if version1 is lower than version2
  static bool _isVersionLower(String version1, String version2) {
    final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad with zeros if needed
    while (v1Parts.length < 3) {
      v1Parts.add(0);
    }
    while (v2Parts.length < 3) {
      v2Parts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (v1Parts[i] < v2Parts[i]) return true;
      if (v1Parts[i] > v2Parts[i]) return false;
    }

    return false; // versions are equal
  }

  /// Open the appropriate app store
  static Future<void> openStore() async {
    final config = _cachedConfig;
    if (config == null) return;

    final url = config.storeUrl;
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('ForceUpdateService: Error opening store: $e');
    }
  }
}
