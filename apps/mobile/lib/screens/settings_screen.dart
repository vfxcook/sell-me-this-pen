import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Profile / Settings (PRD screen 15) — THE engine + keys screen.
/// Save uses PUT /api/v1/settings (see api.dart note: the brief said
/// POST, the backend implements PUT).
///
/// Rules enforced here, not just documented:
/// * Exactly three engine options, values sent verbatim to the backend.
/// * Key fields are obscured. They start EMPTY on every load: the
///   backend only ever returns masked values (e.g. ••••1234), which
///   are shown as helper text, never as editable values.
/// * Saving OMITS empty key fields, so an update cannot wipe a stored
///   key (see ApiClient.saveSettings).
/// * Keys are never printed, logged, or written to on-device storage.
///   Only the backend URL is saved locally (SharedPreferences).
/// * Until the selected engine reports "configured", production
///   simulations will not run — the backend enforces that, and this
///   screen states it plainly.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  EngineOption? _engine;
  bool _initialized = false;
  bool _saving = false;
  String? _message;
  String? _error;

  // Key fields intentionally start empty. Never pre-fill from masked
  // values — a masked value is not a key and must never be sent back.
  final _llmKey = TextEditingController();
  final _llmBaseUrl = TextEditingController();
  final _llmModel = TextEditingController();
  final _zepKey = TextEditingController();
  final _backendUrl = TextEditingController();

  @override
  void dispose() {
    _llmKey.dispose();
    _llmBaseUrl.dispose();
    _llmModel.dispose();
    _zepKey.dispose();
    _backendUrl.dispose();
    super.dispose();
  }

  void _initFrom(AppSettings settings, String currentBackendUrl) {
    if (_initialized) return;
    _initialized = true;
    _engine = settings.engine;
    _llmBaseUrl.text = settings.llmBaseUrl ?? '';
    _llmModel.text = settings.llmModelName ?? '';
    _backendUrl.text = currentBackendUrl;
  }

  /// Status for the currently selected engine, from SAVED masked keys.
  /// Demo needs no keys, so it is always "configured".
  String _statusFor(EngineOption engine, AppSettings saved) {
    switch (engine) {
      case EngineOption.mirofish:
        final ok = (saved.llmKeyMasked?.isNotEmpty ?? false) &&
            (saved.zepKeyMasked?.isNotEmpty ?? false);
        return ok ? 'configured' : 'missing keys';
      case EngineOption.direct:
        return (saved.llmKeyMasked?.isNotEmpty ?? false)
            ? 'configured'
            : 'missing keys';
      case EngineOption.demo:
        return 'configured';
    }
  }

  /// Rescue path: if the backend URL itself is wrong, GET /settings
  /// fails and the full form never loads. This lets the user fix the
  /// URL locally without needing a working backend connection first.
  Future<void> _saveBackendUrlOnly() async {
    final url = _backendUrl.text.trim();
    if (url.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', url);
    ref.read(backendUrlProvider.notifier).state = url;
    ref.invalidate(settingsProvider);
  }

  Future<void> _save() async {
    final engine = _engine;
    if (engine == null) return;
    setState(() {
      _saving = true;
      _message = null;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.saveSettings(
        engine: engine,
        llmApiKey: _llmKey.text,
        llmBaseUrl: _llmBaseUrl.text,
        llmModelName: _llmModel.text,
        zepApiKey: _zepKey.text,
      );
      // Backend URL is app-side only: persist locally, never as a key.
      final url = _backendUrl.text.trim();
      if (url.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('backend_url', url);
        ref.read(backendUrlProvider.notifier).state = url;
      }
      // Clear key fields after a successful save so keys do not linger
      // in memory-backed controllers any longer than necessary.
      _llmKey.clear();
      _zepKey.clear();
      ref.invalidate(settingsProvider);
      if (mounted) setState(() => _message = 'Settings saved.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _maskedHint(String? masked) {
    if (masked == null || masked.isEmpty) return const Text('Not set');
    return Text('Saved: $masked');
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final backendUrl = ref.watch(backendUrlProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: settingsAsync.when(
        data: (saved) {
          _initFrom(saved, backendUrl);
          final engine = _engine ?? saved.engine;
          final status = _statusFor(engine, saved);
          final statusOk = status == 'configured';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Account'),
                const AppCard(
                  child: Text(
                    'Guest exploration. Sign-in, subscriptions, and '
                    'billing arrive with Phase 2 / Phase 5 backend work.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SectionTitle('Simulation engine'),
                ...EngineOption.values.map((option) => AppCard(
                      onTap: () => setState(() => _engine = option),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Radio<EngineOption>(
                            value: option,
                            groupValue: engine,
                            onChanged: (v) =>
                                setState(() => _engine = v),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(option.value,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(option.description,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      Icon(
                        statusOk
                            ? Icons.check_circle
                            : Icons.warning_amber_outlined,
                        color: statusOk
                            ? AppColors.positive
                            : AppColors.negativeRed,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Engine "${engine.value}": $status',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('API keys'),
                TextField(
                  controller: _llmKey,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'LLM API key',
                    helper: _maskedHint(saved.llmKeyMasked),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _llmBaseUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'LLM base URL',
                    hintText: 'https://api.openai.com/v1',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _llmModel,
                  decoration: const InputDecoration(
                    labelText: 'LLM model name',
                    hintText: 'e.g. gpt-4o-mini',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _zepKey,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Zep API key',
                    helper: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _maskedHint(saved.zepKeyMasked),
                        const Text(
                            'Required only for the mirofish engine.'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Leave a key field blank to keep its saved value. '
                  'Blank key fields are never sent, so they cannot wipe '
                  'a stored key.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SectionTitle('Backend'),
                TextField(
                  controller: _backendUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Backend URL',
                    hintText: kDefaultBackendUrl,
                  ),
                ),
                const SizedBox(height: 16),
                const AppCard(
                  child: Text(
                    'Keys are stored server-side only, never in the app '
                    'build. Production simulations will not run until '
                    'the selected engine\'s keys are set.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!,
                      style: const TextStyle(color: AppColors.positive)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: const TextStyle(color: AppColors.negativeRed)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Save Settings'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/onboarding'),
                  child: const Text('Sign Out'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          // Backend-URL rescue form: the URL field stays editable even
          // when settings cannot load, so a wrong URL is fixable here.
          if (_backendUrl.text.isEmpty) _backendUrl.text = backendUrl;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ErrorState(
                  message: 'Could not load settings: $e',
                  onRetry: () => ref.invalidate(settingsProvider),
                ),
                const SizedBox(height: 16),
                const Text(
                  'If the backend URL is wrong, fix it here first — '
                  'keys and engine settings load once the backend '
                  'is reachable again.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _backendUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Backend URL',
                    hintText: kDefaultBackendUrl,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saveBackendUrlOnly,
                  child: const Text('Save Backend URL & Retry'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
