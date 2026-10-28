import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// Backend base URL. Default is the Android-emulator host address.
/// Overridden at startup from saved preferences (main.dart) and from
/// Settings. Keys are never stored in any provider here.
final backendUrlProvider = StateProvider<String>((ref) => kDefaultBackendUrl);

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(backendUrlProvider);
  return ApiClient(baseUrl);
});

final ideasProvider = FutureProvider<List<Idea>>((ref) async {
  return ref.watch(apiClientProvider).getIdeas();
});

final simulationsProvider = FutureProvider<List<Simulation>>((ref) async {
  return ref.watch(apiClientProvider).getSimulations();
});

final settingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(apiClientProvider).getSettings();
});

// Families (not factory functions): a factory would create a new
// provider instance on every build and break caching/invalidation.
final simulationProvider =
    FutureProvider.family<Simulation, String>((ref, id) async {
  return ref.watch(apiClientProvider).getSimulation(id);
});

final eventsProvider =
    FutureProvider.family<EventsResponse, String>((ref, simulationId) async {
  return ref.watch(apiClientProvider).getEvents(simulationId);
});

final resultsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, simulationId) async {
  return ref.watch(apiClientProvider).getResults(simulationId);
});

/// Draft idea being built across Create → Audience → Configure.
/// Persisted to the backend only when the user launches a simulation
/// (see config_screen.dart), so a failed backend never creates a
/// phantom idea in the list.
class DraftIdea {
  final String title;
  final String description;
  final String? category;
  final String? price;

  const DraftIdea({
    this.title = '',
    this.description = '',
    this.category,
    this.price,
  });

  DraftIdea copyWith({
    String? title,
    String? description,
    String? category,
    String? price,
  }) =>
      DraftIdea(
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        price: price ?? this.price,
      );
}

final draftIdeaProvider = StateProvider<DraftIdea>((ref) => const DraftIdea());

/// Audience presets, PRD section 4 step 3 — exact list.
const List<String> kAudiencePresets = [
  'General Consumers',
  'Students',
  'Young Professionals',
  'Parents',
  'Fitness Enthusiasts',
  'Technology Enthusiasts',
  'Small Business Owners',
  'Startup Investors',
  'Custom',
];

class AudienceConfig {
  final String preset;
  final String? customDescription;
  final String? ageRange;
  final String? country;

  const AudienceConfig({
    this.preset = 'General Consumers',
    this.customDescription,
    this.ageRange,
    this.country,
  });

  AudienceConfig copyWith({
    String? preset,
    String? customDescription,
    String? ageRange,
    String? country,
  }) =>
      AudienceConfig(
        preset: preset ?? this.preset,
        customDescription: customDescription ?? this.customDescription,
        ageRange: ageRange ?? this.ageRange,
        country: country ?? this.country,
      );

  Map<String, dynamic> toJson() => {
        'preset': preset,
        if (customDescription != null &&
            customDescription!.trim().isNotEmpty)
          'custom_description': customDescription,
        if (ageRange != null && ageRange!.trim().isNotEmpty)
          'age_range': ageRange,
        if (country != null && country!.trim().isNotEmpty)
          'country': country,
      };
}

final audienceProvider =
    StateProvider<AudienceConfig>((ref) => const AudienceConfig());

/// Simulation modes, PRD section 4 step 4. No agent counts or prices
/// are attached here — those are TBD until MiroFish benchmarking.
enum SimulationMode { quick, standard, deep }

extension SimulationModeX on SimulationMode {
  String get value => name;
  String get label {
    switch (this) {
      case SimulationMode.quick:
        return 'Quick Test';
      case SimulationMode.standard:
        return 'Standard Test';
      case SimulationMode.deep:
        return 'Deep Test';
    }
  }

  String get description {
    switch (this) {
      case SimulationMode.quick:
        return 'Small audience, fast exploratory feedback.';
      case SimulationMode.standard:
        return 'Medium audience, more varied discussion.';
      case SimulationMode.deep:
        return 'Larger audience, longer interaction horizon.';
    }
  }
}

final simulationModeProvider =
    StateProvider<SimulationMode>((ref) => SimulationMode.standard);

/// Idea categories for the Create Idea dropdown. Free-text category is
/// intentionally not offered — the backend normalises these values.
const List<String> kIdeaCategories = [
  'Consumer product',
  'Service',
  'App / Software',
  'Food / Menu item',
  'Campaign / Ad concept',
  'Content / Digital product',
  'Other',
];
