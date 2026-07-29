import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'login_screen.dart';

/// Shown for the moment it takes to read the stored session off disk.
///
/// Deliberately the brand mark rather than a bare spinner: this is the first
/// thing anyone sees on launch, and a blank screen with a wheel on it reads as
/// a hang.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppTheme.brand,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: 78, onDark: true),
          SizedBox(height: 30),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(Colors.white70),
            ),
          ),
        ],
      ),
    ),
  );
}
