import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.groups_outlined,
                  size: 64, color: AppColors.accentPink),
              const SizedBox(height: 24),
              Text('Test your idea\nbefore you build it.',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),
              const Text(
                'Launch an idea into a simulated audience, watch how '
                'reactions develop, find the objections early, and '
                'improve the idea before spending money on it.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const AppCard(
                child: Text(
                  'Simulated audiences are AI personas, not real '
                  'customers. Results are exploratory — they do not '
                  'predict sales or replace real market research.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/sign-in'),
                child: const Text('Sign In'),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'First-time users may explore a sample simulation '
                  'without creating an account (labelled DEMO).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
