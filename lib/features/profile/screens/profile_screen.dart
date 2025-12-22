import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/other_user_profile_content.dart';
import '../widgets/profile_content.dart';
import '../widgets/unauthenticated_view.dart';

class ProfileScreen extends ConsumerWidget {
  final String? viewUserId;
  final String? viewUserName;
  final String? viewUserAvatar;

  const ProfileScreen({
    super.key,
    this.viewUserId,
    this.viewUserName,
    this.viewUserAvatar,
  });

  bool get isViewingOtherUser => viewUserId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isViewingOtherUser) {
      return _buildOtherUserProfile(context, ref, isDark);
    }

    if (!authState.isAuthenticated) {
      return const UnauthenticatedView();
    }

    return _buildOwnProfile(ref, authState, isDark);
  }

  Widget _buildOtherUserProfile(BuildContext context, WidgetRef ref, bool isDark) {
    final profileState = ref.watch(profileProvider(viewUserId!));

    return Scaffold(
      appBar: AppBar(
        title: Text(viewUserName ?? 'Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : OtherUserProfileContent(
              profileState: profileState,
              userName: viewUserName,
              userAvatar: viewUserAvatar,
              isDark: isDark,
            ),
    );
  }

  Widget _buildOwnProfile(WidgetRef ref, AppAuthState authState, bool isDark) {
    final userId = authState.profile!.id;
    final profileState = ref.watch(profileProvider(userId));

    return Scaffold(
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ProfileContent(
              authState: authState,
              profileState: profileState,
              isDark: isDark,
            ),
    );
  }
}
