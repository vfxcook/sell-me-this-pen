import 'dart:math';

import 'package:dio/dio.dart';

/// Default backend base URL: Android emulator reaching the host machine.
/// Overridable in Settings (Profile tab); never hardcode a production URL.
const String kDefaultBackendUrl = 'http://10.0.2.2:8000';

/// Engine options — EXACTLY these three. The string values are sent to
/// the backend verbatim; do not rename them.
enum EngineOption { mirofish, direct, demo }

extension EngineOptionX on EngineOption {
  static EngineOption fromString(String? value) {
    switch (value) {
      case 'mirofish':
        return EngineOption.mirofish;
      case 'direct':
        return EngineOption.direct;
      case 'demo':
        return EngineOption.demo;
      default:
        return EngineOption.demo;
    }
  }

  String get value => name;

  String get description {
    switch (this) {
      case EngineOption.mirofish:
        return 'Full MiroFish engine (Twitter/Reddit social sim). '
            'Needs LLM key + Zep key.';
      case EngineOption.direct:
        return 'Direct multi-agent (LLM only, no Zep). Needs LLM key only.';
      case EngineOption.demo:
        return 'Labelled demo only. No keys. Sample data, clearly marked '
            'DEMO — never presented as real.';
    }
  }
}

/// Settings as returned by GET /api/v1/settings. Key values are NEVER
/// returned in full by the backend; only masked forms (e.g. ••••1234)
/// are stored here. The full keys exist only in the POST body, in
/// memory, for the duration of the save call — never logged, never
/// persisted on-device.
class AppSettings {
  final EngineOption engine;
  final String? llmKeyMasked;
  final String? llmBaseUrl;
  final String? llmModelName;
  final String? zepKeyMasked;

  const AppSettings({
    required this.engine,
    this.llmKeyMasked,
    this.llmBaseUrl,
    this.llmModelName,
    this.zepKeyMasked,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        engine: EngineOptionX.fromString(json['engine'] as String?),
        llmKeyMasked: json['llm_api_key_masked'] as String?,
        llmBaseUrl: json['llm_base_url'] as String?,
        llmModelName: json['llm_model_name'] as String?,
        zepKeyMasked: json['zep_api_key_masked'] as String?,
      );

  /// Per-engine status shown in Settings. Demo needs no keys.
  String get status {
    switch (engine) {
      case EngineOption.mirofish:
        final ok = (llmKeyMasked?.isNotEmpty ?? false) &&
            (zepKeyMasked?.isNotEmpty ?? false);
        return ok ? 'configured' : 'missing keys';
      case EngineOption.direct:
        return (llmKeyMasked?.isNotEmpty ?? false)
            ? 'configured'
            : 'missing keys';
      case EngineOption.demo:
        return 'configured';
    }
  }

  bool get canRunProductionSimulation => status == 'configured';
}

class Idea {
  final String id;
  final String title;
  final String description;
  final String? category;
  final String? priceText;
  final String? createdAt;

  const Idea({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    this.priceText,
    this.createdAt,
  });

  factory Idea.fromJson(Map<String, dynamic> json) {
    // Backend returns price_amount (+ price_currency); accept the
    // generic "price" key too so other backends still parse.
    String? priceText;
    if (json['price_amount'] != null) {
      priceText = '${json['price_amount']}';
      if (json['price_currency'] != null) {
        priceText = '$priceText ${json['price_currency']}';
      }
    } else if (json['price'] != null) {
      priceText = '${json['price']}';
    }
    return Idea(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? 'Untitled idea'}',
      description: '${json['description'] ?? ''}',
      category: json['category'] as String?,
      priceText: priceText,
      createdAt: json['created_at'] as String?,
    );
  }
}

class Simulation {
  final String id;
  final String status;
  final String? ideaTitle;
  final bool isDemo;
  final int? actualAgentCount;

  const Simulation({
    required this.id,
    required this.status,
    this.ideaTitle,
    this.isDemo = false,
    this.actualAgentCount,
  });

  factory Simulation.fromJson(Map<String, dynamic> json) => Simulation(
        id: '${json['id'] ?? ''}',
        status: '${json['status'] ?? 'unknown'}',
        ideaTitle: json['idea_title'] as String? ??
            (json['idea'] is Map
                ? (json['idea'] as Map)['title'] as String?
                : null),
        isDemo: json['is_demo'] == true,
        actualAgentCount: json['actual_agent_count'] as int?,
      );
}

/// One event from GET /api/v1/simulations/{id}/events.
/// Rendered verbatim from the backend. No conversation text is created
/// anywhere in this app — if the backend returns no events, the feed
/// shows an empty state, not invented dialogue.
class SimEvent {
  final String id;
  final String agentName;
  final String? persona;
  final String message;
  final String? classification;
  final int? simulationTimestamp;

  const SimEvent({
    required this.id,
    required this.agentName,
    required this.message,
    this.persona,
    this.classification,
    this.simulationTimestamp,
  });

  factory SimEvent.fromJson(Map<String, dynamic> json) => SimEvent(
        id: '${json['event_id'] ?? json['id'] ?? ''}',
        agentName: '${json['agent_name'] ?? json['agent_id'] ?? 'Agent'}',
        persona: json['persona'] as String? ??
            json['persona_category'] as String?,
        message: '${json['content'] ?? json['message'] ?? ''}',
        classification: (json['metadata'] is Map
                ? (json['metadata'] as Map)['classification']
                : json['classification'])
            as String?,
        simulationTimestamp: json['simulation_timestamp'] as int?,
      );
}

class EventsResponse {
  final bool isDemo;
  final List<SimEvent> events;

  const EventsResponse({required this.isDemo, required this.events});
}

class ApiException implements Exception {
  final String message;
  final bool retryable;
  const ApiException(this.message, {this.retryable = false});

  @override
  String toString() => message;
}

class ApiClient {
  final Dio _dio;

  ApiClient(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ));

  Never _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      throw const ApiException(
          'Could not reach the backend. Check the backend URL in Settings '
          'and your connection, then retry.',
          retryable: true);
    }
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMessage;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) serverMessage = err['message'] as String?;
      serverMessage ??= data['message'] as String?;
    }
    if (status == 402) {
      throw ApiException(
          serverMessage ?? 'Insufficient credits for this simulation.');
    }
    if (status == 503 || status == 502) {
      throw ApiException(
          serverMessage ??
              'The simulation service is temporarily unavailable.',
          retryable: true);
    }
    throw ApiException(serverMessage ?? 'Request failed (HTTP $status).',
        retryable: status != null && status >= 500);
  }

  Future<List<Idea>> getIdeas() async {
    try {
      final res = await _dio.get('/api/v1/ideas');
      final data = res.data;
      final list = data is List
          ? data
          : (data is Map ? (data['ideas'] ?? data['items'] ?? []) : []);
      return (list as List)
          .whereType<Map>()
          .map((e) => Idea.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  Future<Idea> createIdea(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post('/api/v1/ideas', data: body);
      return Idea.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  Future<List<Simulation>> getSimulations() async {
    try {
      final res = await _dio.get('/api/v1/simulations');
      final data = res.data;
      final list = data is List
          ? data
          : (data is Map ? (data['simulations'] ?? data['items'] ?? []) : []);
      return (list as List)
          .whereType<Map>()
          .map((e) => Simulation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  /// Creates a simulation. The idempotency key is generated per launch
  /// so a retried tap does not double-charge or double-run (PRD FR-04).
  Future<Simulation> createSimulation({
    required String ideaId,
    required Map<String, dynamic> audience,
    required String mode,
  }) async {
    final key =
        'idem-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    try {
      // Backend SimIn shape: {idea_id, audience_preset, audience,
      // mode} — mode is top-level, not nested under "simulation".
      // audience_preset is sent verbatim (e.g. "Young Professionals");
      // the backend stores it and the engine adapter interprets it.
      final preset = audience['preset'] as String? ?? 'General Consumers';
      final res = await _dio.post(
        '/api/v1/simulations',
        data: {
          'idea_id': ideaId,
          'audience_preset': preset,
          'audience': audience,
          'mode': mode,
        },
        options: Options(headers: {'Idempotency-Key': key}),
      );
      return Simulation.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  Future<Simulation> getSimulation(String id) async {
    try {
      final res = await _dio.get('/api/v1/simulations/$id');
      return Simulation.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  Future<EventsResponse> getEvents(String simulationId) async {
    try {
      final res = await _dio.get('/api/v1/simulations/$simulationId/events');
      final data = res.data;
      if (data is List) {
        return EventsResponse(
          isDemo: false,
          events: data
              .whereType<Map>()
              .map((e) => SimEvent.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }
      final map = Map<String, dynamic>.from(data as Map);
      final list = (map['events'] ?? []) as List;
      return EventsResponse(
        isDemo: map['is_demo'] == true,
        events: list
            .whereType<Map>()
            .map((e) => SimEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getResults(String simulationId) async {
    try {
      final res = await _dio.get('/api/v1/simulations/$simulationId/results');
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  Future<void> cancelSimulation(String id) async {
    try {
      await _dio.post('/api/v1/simulations/$id/cancel');
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  Future<AppSettings> getSettings() async {
    try {
      final res = await _dio.get('/api/v1/settings');
      return AppSettings.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      _mapError(e);
    }
  }

  /// Saves settings. Empty key fields are OMITTED (never sent as empty
  /// strings) so an update cannot wipe a stored key. Key values are
  /// never printed, logged, or persisted on-device by this client.
  Future<AppSettings> saveSettings({
    required EngineOption engine,
    String? llmApiKey,
    String? llmBaseUrl,
    String? llmModelName,
    String? zepApiKey,
  }) async {
    final body = <String, dynamic>{'engine': engine.value};
    void addIfPresent(String key, String? value) {
      final v = value?.trim();
      if (v != null && v.isNotEmpty) body[key] = v;
    }

    addIfPresent('llm_api_key', llmApiKey);
    addIfPresent('llm_base_url', llmBaseUrl);
    addIfPresent('llm_model_name', llmModelName);
    addIfPresent('zep_api_key', zepApiKey);
    try {
      // NOTE: the build brief said POST, but the backend in
      // services/api implements settings update as PUT
      // (routers/settings.py: update_settings). PUT is used so the
      // save actually succeeds against that backend; flag any
      // contract change back to the backend owner if POST is intended.
      final res = await _dio.put('/api/v1/settings', data: body);
      return AppSettings.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      _mapError(e);
    }
  }
}
