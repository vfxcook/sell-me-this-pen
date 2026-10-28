import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Live Simulation feed (PRD screen 08).
/// Renders ONLY events returned by GET /api/v1/simulations/{id}/events.
/// There is no sample conversation in this file: an empty backend
/// response renders an empty state, and a backend error renders an
/// error state. The DEMO banner appears only when the backend reports
/// is_demo=true.
class LiveFeedScreen extends ConsumerStatefulWidget {
  final String simulationId;
  const LiveFeedScreen({super.key, required this.simulationId});

  @override
  ConsumerState<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends ConsumerState<LiveFeedScreen> {
  String _filter = 'All';

  static const List<String> _filters = [
    'All',
    'Positive',
    'Negative',
    'Neutral',
    'Question',
    'Suggestion',
  ];

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider(widget.simulationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Live Simulation')),
      body: eventsAsync.when(
        data: (response) {
          final filtered = _filter == 'All'
              ? response.events
              : response.events
                  .where((e) =>
                      (e.classification ?? '').toLowerCase() ==
                      _filter.toLowerCase())
                  .toList();
          return Column(
            children: [
              if (response.isDemo) const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: DemoBanner(),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: _filters
                      .map((f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f),
                              selected: _filter == f,
                              onSelected: (_) =>
                                  setState(() => _filter = f),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No events match this filter yet. Events '
                            'appear here only as the backend returns them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(eventsProvider(widget.simulationId)),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              EventCard(event: filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(eventsProvider(widget.simulationId)),
        ),
      ),
    );
  }
}
