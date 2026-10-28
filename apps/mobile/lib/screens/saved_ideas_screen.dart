import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Saved Ideas (PRD screen 12): idea cards, search, history.
/// Archived items are a backend concern; this screen lists what the
/// backend returns and filters locally by the search query.
class SavedIdeasScreen extends ConsumerStatefulWidget {
  const SavedIdeasScreen({super.key});

  @override
  ConsumerState<SavedIdeasScreen> createState() => _SavedIdeasScreenState();
}

class _SavedIdeasScreenState extends ConsumerState<SavedIdeasScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ideasAsync = ref.watch(ideasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Ideas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search ideas',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: ideasAsync.when(
              data: (ideas) {
                final filtered = _query.isEmpty
                    ? ideas
                    : ideas
                        .where((i) =>
                            i.title.toLowerCase().contains(_query) ||
                            i.description.toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No saved ideas match.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final idea = filtered[i];
                    return AppCard(
                      onTap: () => context.push('/create-idea'),
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
                          if (idea.category != null) ...[
                            const SizedBox(height: 4),
                            Text(idea.category!,
                                style: const TextStyle(
                                    color: AppColors.accentBlue,
                                    fontSize: 12)),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(ideasProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-idea'),
        backgroundColor: AppColors.accentPink,
        child: const Icon(Icons.add),
      ),
    );
  }
}
