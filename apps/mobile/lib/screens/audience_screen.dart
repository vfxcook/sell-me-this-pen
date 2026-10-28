import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Audience Selection (PRD screen 05). Presets are the exact PRD list.
/// Custom audiences are saved as part of the simulation request; the
/// backend converts them for the engine (or disables unsupported
/// attributes) — the app never claims a preset maps 1:1 to engine
/// agents. Demographic choices here are synthetic modelling choices,
/// not verified population representations.
class AudienceScreen extends ConsumerStatefulWidget {
  const AudienceScreen({super.key});

  @override
  ConsumerState<AudienceScreen> createState() => _AudienceScreenState();
}

class _AudienceScreenState extends ConsumerState<AudienceScreen> {
  late final TextEditingController _custom;
  late final TextEditingController _age;
  late final TextEditingController _country;

  @override
  void initState() {
    super.initState();
    final a = ref.read(audienceProvider);
    _custom = TextEditingController(text: a.customDescription ?? '');
    _age = TextEditingController(text: a.ageRange ?? '');
    _country = TextEditingController(text: a.country ?? '');
  }

  @override
  void dispose() {
    _custom.dispose();
    _age.dispose();
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audience = ref.watch(audienceProvider);
    final isCustom = audience.preset == 'Custom';
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Audience')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Who should react to this idea? These are synthetic '
              'audience definitions for modelling — not verified '
              'population data.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...kAudiencePresets.map((preset) => AppCard(
                  onTap: () => ref.read(audienceProvider.notifier).state =
                      audience.copyWith(preset: preset),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(preset,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                      Radio<String>(
                        value: preset,
                        groupValue: audience.preset,
                        onChanged: (v) => ref
                            .read(audienceProvider.notifier)
                            .state = audience.copyWith(preset: v),
                      ),
                    ],
                  ),
                )),
            if (isCustom) ...[
              const SectionTitle('Custom audience'),
              TextFormField(
                controller: _custom,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Describe this audience',
                  hintText: 'e.g. First-time founders in small towns',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _age,
                decoration: const InputDecoration(
                    labelText: 'Age range (optional)',
                    hintText: 'e.g. 18–30'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _country,
                decoration: const InputDecoration(
                    labelText: 'Country / region (optional)',
                    hintText: 'e.g. India'),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(audienceProvider.notifier).state =
                    audience.copyWith(
                  customDescription:
                      _custom.text.trim().isEmpty ? null : _custom.text.trim(),
                  ageRange: _age.text.trim().isEmpty ? null : _age.text.trim(),
                  country: _country.text.trim().isEmpty
                      ? null
                      : _country.text.trim(),
                );
                context.push('/configure');
              },
              child: const Text('Next: Configure Simulation'),
            ),
          ],
        ),
      ),
    );
  }
}
