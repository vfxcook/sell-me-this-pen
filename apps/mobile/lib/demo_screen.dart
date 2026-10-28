import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../demo_showcase.dart';
import '../theme.dart';
import '../widgets.dart';

/// Demo Mode — the showcase that shows the app's power.
///
/// Runs fully on-device from [DemoShowcase]: no backend, no keys, no
/// network. The audience reactions play in one by one like a live
/// simulation, then the verdict report appears. The DemoBanner stays
/// on screen in both phases so sample data is never mistaken for a
/// real result.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  static const _step = Duration(milliseconds: 900);
  final _scrollController = ScrollController();
  Timer? _timer;
  int _shown = 0;
  bool _verdict = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_step, (_) {
      if (!mounted) return;
      if (_shown >= DemoShowcase.events.length) {
        _timer?.cancel();
        return;
      }
      setState(() => _shown++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _replay() {
    setState(() {
      _shown = 0;
      _verdict = false;
    });
    _start();
  }

  void _skip() {
    _timer?.cancel();
    setState(() => _shown = DemoShowcase.events.length);
  }

  Widget _section(String title, List<String> items) {
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

  List<String> _strings(dynamic value) {
    if (value is List) return value.map((e) => '$e').toList();
    if (value is String) return [value];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final total = DemoShowcase.events.length;
    final allShown = _shown >= total;
    final results = DemoShowcase.results;
    final metrics = results['metrics'];
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Mode')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DemoBanner(),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DemoShowcase.ideaTitle,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text(DemoShowcase.ideaDescription),
                  const SizedBox(height: 8),
                  Text(DemoShowcase.audienceNote,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text(
                    'Works offline — no backend, no keys needed.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!_verdict) ...[
              const SectionTitle('Live audience reactions'),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : _shown / total,
                      backgroundColor: AppColors.surface,
                      color: AppColors.accentPink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$_shown of $total',
                      style: const TextStyle(
                          color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 16),
              ...DemoShowcase.events
                  .take(_shown)
                  .map((event) => EventCard(event: event)),
              const SizedBox(height: 16),
              if (!allShown)
                OutlinedButton(
                  onPressed: _skip,
                  child: const Text('Skip to the end'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => setState(() => _verdict = true),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('See the verdict'),
                ),
            ] else ...[
              const SectionTitle('Verdict (sample)'),
              AppCard(
                child: Text(results['summary'] as String? ?? '',
                    style: const TextStyle(fontSize: 16)),
              ),
              if (metrics is List) ...[
                const SectionTitle('Metrics (sample counts)'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: metrics.map((m) {
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
                    }).toList(),
                  ),
                ),
              ],
              _section('Positive themes',
                  _strings(results['positive_themes'])),
              _section('Negative themes / objections',
                  _strings(results['negative_themes'])),
              _section(
                  'Common objections', _strings(results['objections'])),
              _section(
                  'Repeated questions', _strings(results['questions'])),
              _section('Suggestions', _strings(results['suggestions'])),
              _section(
                  'Key takeaways', _strings(results['key_takeaways'])),
              const SectionTitle('Limitations'),
              AppCard(
                child: Text(
                  results['disclaimer'] as String? ?? '',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.push('/create-idea'),
                icon: const Icon(Icons.add),
                label: const Text('Test your own idea'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _replay,
                icon: const Icon(Icons.replay),
                label: const Text('Replay demo'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to Home'),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
