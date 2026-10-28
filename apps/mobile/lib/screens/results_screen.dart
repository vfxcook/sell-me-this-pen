import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Results Overview + Detailed Feedback (PRD screens 09–10).
/// Every section renders backend-supplied values only. A metric is
/// shown with its denominator/method only when the backend supplies
/// them; no percentage is computed or implied by this screen.
class ResultsScreen extends ConsumerWidget {
  final String simulationId;
  const ResultsScreen({super.key, required this.simulationId});

  List<String> _strings(dynamic value) {
    if (value is List) return value.map((e) => '$e').toList();
    if (value is String) return [value];
    return const [];
  }

  Widget _section(BuildContext context, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        ...items.map((item) => AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(item)),
                ],
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(resultsProvider(simulationId));
    final simAsync = ref.watch(simulationProvider(simulationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: resultsAsync.when(
        data: (results) {
          final isDemo = simAsync.maybeWhen(
              data: (s) => s.isDemo, orElse: () => false);
          final summary = results['summary'] as String? ??
              results['overall_feedback_summary'] as String?;
          final metrics = results['metrics'];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDemo) const DemoBanner(),
                if (isDemo) const SizedBox(height: 16),
                if (summary != null)
                  AppCard(
                    child: Text(summary,
                        style: const TextStyle(fontSize: 16)),
                  ),
                // Backend returns metrics as a LIST of
                // {name, numerator, denominator, method}; accept a Map
                // too so other backends still render.
                if (metrics is List || metrics is Map) ...[
                  const SectionTitle('Metrics (as reported)'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (metrics is List)
                          ...metrics.map((m) {
                            if (m is! Map) return Text('$m');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${m['name'] ?? 'metric'}: '
                                '${m['numerator'] ?? 'not reported'} '
                                '(denominator: '
                                '${m['denominator'] ?? 'not reported'}, '
                                'method: ${m['method'] ?? 'not reported'})',
                              ),
                            );
                          }),
                        if (metrics is Map)
                          ...metrics.entries.map((e) {
                            final v = e.value;
                            final text = v is Map
                                ? '${e.key}: ${v['value'] ?? v} '
                                    '(denominator: ${v['denominator'] ?? 'not reported'}, '
                                    'method: ${v['method'] ?? 'not reported'})'
                                : '${e.key}: $v';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(text),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
                _section(context, 'Positive themes',
                    _strings(results['positive_themes'])),
                _section(context, 'Negative themes / objections',
                    _strings(results['negative_themes'])),
                _section(context, 'Common objections',
                    _strings(results['objections'])),
                _section(context, 'Repeated questions',
                    _strings(results['questions'])),
                _section(context, 'Suggestions',
                    _strings(results['suggestions'])),
                _section(context, 'Key takeaways',
                    _strings(results['key_takeaways'])),
                const SectionTitle('Limitations'),
                AppCard(
                  child: Text(
                    // Prefer the backend's own disclaimer when present;
                    // fall back to the PRD 11.3 wording (identical text).
                    results['disclaimer'] as String? ??
                        'This report is generated from AI-simulated audience '
                            'interactions. Results are exploratory and do not '
                            'represent verified human consumer behavior, actual '
                            'purchase intent, or statistically representative '
                            'market research.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(resultsProvider(simulationId)),
        ),
      ),
    );
  }
}
