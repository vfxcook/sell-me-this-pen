import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api.dart' as api;
import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Simulation Progress (PRD screen 07).
/// Progress is the backend's real status string plus the event count
/// fetched from the backend. No invented percentages are shown: if the
/// backend does not report a percentage, none is displayed.
class ProgressScreen extends ConsumerStatefulWidget {
  final String simulationId;
  const ProgressScreen({super.key, required this.simulationId});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  Timer? _timer;
  api.Simulation? _simulation;
  int? _eventCount;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final api = ref.read(apiClientProvider);
      final sim = await api.getSimulation(widget.simulationId);
      final events = await api.getEvents(widget.simulationId);
      if (!mounted) return;
      setState(() {
        _simulation = sim;
        _eventCount = events.events.length;
        _error = null;
        _loading = false;
      });
      if (sim.status == 'completed' || sim.status == 'failed') {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sim = _simulation;
    return Scaffold(
      appBar: AppBar(title: const Text('Simulation Progress')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sim?.isDemo == true) const DemoBanner(),
            if (sim?.isDemo == true) const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current phase',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(sim?.status ?? 'Loading…',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 12),
                  Text(
                    _eventCount == null
                        ? 'Fetching events…'
                        : '$_eventCount events received from the backend so far.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  if (sim?.actualAgentCount != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Simulated agents (as reported by the engine): '
                      '${sim!.actualAgentCount}',
                      style:
                          const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorState(message: _error!, onRetry: _refresh),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/live/${widget.simulationId}'),
              child: const Text('View Live Feed'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: sim?.status == 'completed'
                  ? () => context.push('/results/${widget.simulationId}')
                  : null,
              child: const Text('View Results'),
            ),
            if (sim != null &&
                sim.status != 'completed' &&
                sim.status != 'failed') ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(apiClientProvider)
                        .cancelSimulation(widget.simulationId);
                    if (mounted) context.pop();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())));
                    }
                  }
                },
                child: const Text('Cancel Simulation'),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'The simulation continues server-side if you leave this '
              'screen. Come back to see the completed result.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
