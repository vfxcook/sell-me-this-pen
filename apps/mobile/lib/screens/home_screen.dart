import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Home / Idea Lab (PRD screen 03).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ideas = ref.watch(ideasProvider);
    final simulations = ref.watch(simulationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Idea Lab')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ideasProvider);
          ref.invalidate(simulationsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Good to see you.',
                  style: TextStyle(color: AppColors.textSecondary)),
              Text('What shall we test today?',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              // Credit balance: placeholder 0 until Phase 5 billing lands.
              // No price or allowance is claimed here.
              const AppCard(
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.accentBlue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Credit balance',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text('0',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/create-idea'),
                icon: const Icon(Icons.add),
                label: const Text('New Idea'),
              ),
              const SectionTitle('Recent ideas'),
              ideas.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const AppCard(
                      child: Text(
                        'No ideas yet. Create your first idea to test it.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return Column(
                    children: list
                        .take(5)
                        .map((idea) => AppCard(
                              onTap: () => context.push('/saved-ideas'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(idea.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  if (idea.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(idea.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(ideasProvider),
                ),
              ),
              const SectionTitle('Recent simulations'),
              simulations.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const AppCard(
                      child: Text(
                        'No simulations yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return Column(
                    children: list
                        .take(5)
                        .map((sim) => AppCard(
                              onTap: () => context.push('/progress/${sim.id}'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        sim.ideaTitle ?? 'Simulation ${sim.id}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  Text(sim.status,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
                loading: () => const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator())),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(simulationsProvider),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.push('/saved-ideas'),
                child: const Text('View all saved ideas'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
