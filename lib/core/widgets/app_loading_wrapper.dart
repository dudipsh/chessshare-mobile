import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Wrapper that shows animated loading screen while app initializes
class AppLoadingWrapper extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onInit;

  const AppLoadingWrapper({
    super.key,
    required this.child,
    required this.onInit,
  });

  @override
  State<AppLoadingWrapper> createState() => _AppLoadingWrapperState();
}

class _AppLoadingWrapperState extends State<AppLoadingWrapper> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await widget.onInit();
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return widget.child;
    }

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _LoadingScreen(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1a1a1a) : const Color(0xFFEEEDCF);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Image.asset(
          'assets/images/app_icon.png',
          width: 120,
          height: 120,
        ).animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.15, 1.15),
              duration: 800.ms,
              curve: Curves.easeInOut,
            ),
      ),
    );
  }
}
