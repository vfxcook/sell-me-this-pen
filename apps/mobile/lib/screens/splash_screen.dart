import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) context.go('/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.accentPink,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Sell Me This Pen',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text('Pitch it. Test it. Improve it.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.accentPink),
          ],
        ),
      ),
    );
  }
}
