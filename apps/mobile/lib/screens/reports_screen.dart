import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Reports (PRD screen 13). Placeholder list: completed simulations
/// from the backend, each opening its results report. Export/sharing
/// are Phase 4 backend features; this screen does not invent report
/// content or links.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simsAsync = ref.watch(simulationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: simsAsync.when(
        data: (sims) {
          final completed =
              sims.where((s) => s.status == 'completed').toList();
          if (completed.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No completed reports yet. Reports appear here after '
                  'a simulation finishes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completed.length,
            itemBuilder: (_, i) {
              final sim = completed[i];
              return AppCard(
                onTap: () => context.push('/results/${sim.id}'),
                child: Row(
                  children: [
                    const Icon(Icons.article_outlined,
                        color: AppColors.accentBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(sim.ideaTitle ?? 'Report ${sim.id}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ],
                ),
              );
            },
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
