import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';

/// Create Idea (PRD screen 04). Title and description are required;
/// category is a dropdown; price is optional. The draft is held in a
/// provider and only sent to the backend at launch (config screen),
/// so validation failures never create phantom ideas.
class CreateIdeaScreen extends ConsumerStatefulWidget {
  const CreateIdeaScreen({super.key});

  @override
  ConsumerState<CreateIdeaScreen> createState() => _CreateIdeaScreenState();
}

class _CreateIdeaScreenState extends ConsumerState<CreateIdeaScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftIdeaProvider);
    _title = TextEditingController(text: draft.title);
    _description = TextEditingController(text: draft.description);
    _price = TextEditingController(text: draft.price ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftIdeaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Idea')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Idea title *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Idea title is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Description *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: draft.category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: kIdeaCategories
                    .map((c) =>
                        DropdownMenuItem<String>(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => ref
                    .read(draftIdeaProvider.notifier)
                    .state = draft.copyWith(category: v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Proposed price (optional)',
                  hintText: 'e.g. 999',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return double.tryParse(v.trim()) == null
                      ? 'Enter a number, or leave blank'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  ref.read(draftIdeaProvider.notifier).state =
                      draft.copyWith(
                    title: _title.text.trim(),
                    description: _description.text.trim(),
                    price: _price.text.trim().isEmpty
                        ? null
                        : _price.text.trim(),
                  );
                  context.push('/audience');
                },
                child: const Text('Next: Choose Audience'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
