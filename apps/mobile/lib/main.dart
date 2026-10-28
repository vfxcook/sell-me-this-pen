import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Backend URL is the only setting persisted on-device. API keys are
  // never stored here — see Settings (saveSettings in api.dart).
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('backend_url');
  runApp(
    ProviderScope(
      overrides: [
        if (savedUrl != null && savedUrl.isNotEmpty)
          backendUrlProvider.overrideWith((ref) => savedUrl),
      ],
      child: const SellMeThisPenApp(),
    ),
  );
}

class SellMeThisPenApp extends StatelessWidget {
  const SellMeThisPenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sell Me This Pen',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: buildRouter(),
    );
  }
}
