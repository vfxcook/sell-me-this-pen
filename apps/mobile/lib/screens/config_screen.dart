import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Simulation Configuration (PRD screen 06).
/// Estimated cost is shown as 'TBD until benchmarked' — never a
/// invented credit price. Agent counts are never shown here, because
/// the engine derives them and they are only known after prepare.
class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  bool _launching = false;
  String? _error;

  Future<void> _launch() async {
    final draft = ref.read(draftIdeaProvider);
    final audience = ref.read(audienceProvider);
    final mode = ref.read(simulationModeProvider);
    if (draft.title.trim().isEmpty || draft.description.trim().isEmpty) {
      setState(() => _error = 'Complete the idea title and description first.');
      return;
    }
    setState(() {
      _launching = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      // Backend IdeaIn takes price_amount (int), not a "price" string.
      final priceAmount =
          draft.price == null ? null : int.tryParse(draft.price!);
      final ideaBody = {
        'title': draft.title,
        'description': draft.description,
        if (draft.category != null) 'category': draft.category,
        if (priceAmount != null) 'price_amount': priceAmount,
      };
      final idea = await api.createIdea(ideaBody);
      final simulation = await api.createSimulation(
        ideaId: idea.id,
        audience: audience.toJson(),
        mode: mode.value,
      );
      if (!mounted) return;
      context.push('/progress/${simulation.id}');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftIdeaProvider);
    final audience = ref.watch(audienceProvider);
    final mode = ref.watch(simulationModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configure Simulation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Idea'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(draft.title,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(draft.description,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SectionTitle('Audience'),
            AppCard(child: Text(audience.preset)),
            const SectionTitle('Simulation mode'),
            ...SimulationMode.values.map((m) => AppCard(
                  onTap: () =>
                      ref.read(simulationModeProvider.notifier).state = m,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(m.description,
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Radio<SimulationMode>(
                        value: m,
                        groupValue: mode,
                        onChanged: (v) => ref
                            .read(simulationModeProvider.notifier)
                            .state = v!,
                      ),
                    ],
                  ),
                )),
            const SectionTitle('Estimated cost'),
            const AppCard(
              child: Text(
                'TBD until benchmarked',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Credit costs depend on measured engine usage (agents, '
              'rounds, model). No price is shown until benchmarking '
              'completes, so nothing here is a quote.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _launching ? null : _launch,
              child: _launching
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Launch Simulation'),
            ),
          ],
        ),
      ),
    );
  }
}
