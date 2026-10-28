import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/audience_screen.dart';
import 'screens/config_screen.dart';
import 'screens/create_idea_screen.dart';
import 'screens/demo_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_feed_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/results_screen.dart';
import 'screens/saved_ideas_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/simulations_screen.dart';
import 'screens/splash_screen.dart';

/// Bottom navigation tabs (PRD 6.3). Flow screens (create → audience →
/// configure → progress → live → results) sit outside the shell so the
/// bottom bar does not compete with the flow's own navigation.
GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: navigationShell.goBranch,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.science_outlined), label: 'Simulations'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.article_outlined), label: 'Reports'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            ),
          );
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/simulations',
                builder: (_, __) => const SimulationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/demo', builder: (_, __) => const DemoScreen()),
      GoRoute(path: '/create-idea', builder: (_, __) => const CreateIdeaScreen()),
      GoRoute(path: '/audience', builder: (_, __) => const AudienceScreen()),
      GoRoute(path: '/configure', builder: (_, __) => const ConfigScreen()),
      GoRoute(
        path: '/progress/:id',
        builder: (_, state) =>
            ProgressScreen(simulationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/live/:id',
        builder: (_, state) =>
            LiveFeedScreen(simulationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/results/:id',
        builder: (_, state) =>
            ResultsScreen(simulationId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/saved-ideas', builder: (_, __) => const SavedIdeasScreen()),
    ],
  );
}
