import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';

class UnauthenticatedView extends StatelessWidget {
  const UnauthenticatedView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, size: 50, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text('Sign in to view your profile', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Sync your games, puzzles, and stats',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.pushNamed('login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
