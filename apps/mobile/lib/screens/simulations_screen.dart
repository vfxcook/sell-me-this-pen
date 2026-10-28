import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Simulations tab: all simulations from the backend. Tapping routes
/// by status — running ones to Progress, completed ones to Results.
class SimulationsScreen extends ConsumerWidget {
  const SimulationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simsAsync = ref.watch(simulationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Simulations')),
      body: simsAsync.when(
        data: (sims) {
          if (sims.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No simulations yet. Create an idea and launch one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(simulationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sims.length,
              itemBuilder: (_, i) {
                final sim = sims[i];
                return AppCard(
                  onTap: () => context.push(
                    sim.status == 'completed'
                        ? '/results/${sim.id}'
                        : '/progress/${sim.id}',
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sim.ideaTitle ?? 'Simulation ${sim.id}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('Status: ${sim.status}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                            if (sim.isDemo)
                              const Text('DEMO',
                                  style: TextStyle(
                                      color: AppColors.accentBlue,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(simulationsProvider),
        ),
      ),
    );
  }
}
