# Sell Me This Pen — Flutter app

## Compile status: ANALYSED, APK BLOCKED (2026-10-28)

- Toolchain: `~/flutter-3.47.8` (tarball, SHA-verified). `flutter pub
  get` succeeds (64 deps); `flutter analyze` passes with 0 errors
  (11 info/warnings only).
- Android shell completed 2026-10-28 from a scratch `flutter create`
  template (wrapper, settings, gradle.properties, MainActivity,
  launcher icons, themes, debug/profile manifests) while keeping this
  app's custom `app/build.gradle.kts`, manifest, MainActivity and
  styles. SDK 36 (platform + build-tools 36.0.0, SHA1-verified)
  installed at `~/Android/Sdk`. Gradle 9.3.1 is used from a local zip
  (`~/workspace/gradle-9.3.1-all.zip`, wrapper `distributionUrl` is a
  `file://` URL) because the wrapper's Java downloader cannot tunnel
  through the egress proxy.
- **APK build BLOCKED on this VM:** the Gradle daemon cannot talk to
  its client — every build fails with "Could not dispatch a message
  to the daemon" (Broken pipe / Connection reset) while the daemon
  process itself is alive. Root cause, proven with a Java
  cross-process loopback test: the runtime blocks inter-process TCP
  (`other_tcp` permission = Deny) and intercepts the connection.
  Fix (user-side): Muse settings → Permissions → Direct network
  protocols → switch `other_tcp` from Deny to Ask, then retry
  `flutter build apk --debug`. Note: Gradle's user home here is
  `/root/.gradle` (Java user.home for root), not `~/.gradle`.
- Remaining known items:
- `lib/theme.dart` sets `fontFamily: 'Inter'`, but Inter font files are
  not bundled yet — the app falls back to the system sans-serif until
  the fonts are added under `assets/fonts/` and declared in pubspec.
- Release signing is deliberately absent (see `build.gradle.kts` TODO)
  — Phase 6 work, not something to improvise here.
- Cleartext HTTP to `http://10.0.2.2:8000` is a development-only
  default for the Android emulator. Production builds must use HTTPS.

## What is here

Stack per PRD: Flutter + Riverpod + GoRouter + Dio.

- `lib/main.dart` — app entry; loads the saved backend URL only.
- `lib/theme.dart` — PRD 6.1 tokens exactly: backgrounds `#06101F` /
  `#0B1B30`, pink `#FF008C`, blue `#287BFF`, positive `#13DB9A`,
  negative `#FF527A`, text `#FFFFFF` / `#A8B8CF`.
- `lib/api.dart` — Dio client for ideas, simulations, events, results,
  settings. Backend base URL default `http://10.0.2.2:8000`.
- `lib/providers.dart` — Riverpod providers, draft idea/audience/mode
  state, PRD audience presets.
- `lib/router.dart` — GoRouter with bottom-nav shell
  (Home / Simulations / Reports / Profile) and flow routes outside it.
- `lib/screens/` — Splash, Onboarding, Sign In (form present, auth
  not wired — Phase 2), Home/Idea Lab, Create Idea, Audience
  Selection, Simulation Configuration, Simulation Progress, Live
  Simulation, Results, Saved Ideas, Simulations, Reports, Settings.

## Settings — engine switch and keys (the key screen)

Profile tab → Settings offers exactly three engines:

1. `mirofish` — Full MiroFish engine (Twitter/Reddit social sim).
   Needs LLM key + Zep key.
2. `direct` — Direct multi-agent (LLM only, no Zep). Needs LLM key only.
3. `demo` — Labelled demo only. No keys. Sample data, clearly marked
   DEMO — never presented as real.

Save PUTs to `/api/v1/settings` (the brief said POST; the backend in
`services/api` implements PUT — the app follows the backend) with
`{engine, llm_api_key,
llm_base_url, llm_model_name, zep_api_key}`; empty key fields are
omitted so updates cannot wipe stored keys. Load uses
`GET /api/v1/settings` and shows masked values only (e.g. `••••1234`)
plus per-engine status: `configured` / `missing keys`. Keys are
obscured text fields, never logged, never stored on-device. Backend
URL is the only setting saved locally.

> Keys are stored server-side only, never in the app build.
> Production simulations will not run until the selected engine's
> keys are set.

## Honesty rules enforced in code

- **No hardcoded simulation conversations in production paths.** The
  live feed renders only `GET /api/v1/simulations/{id}/events`.
  Empty backend responses render empty states; errors render error
  states with retry.
- **DEMO banner only when the backend says `is_demo=true`.**
- **No invented prices, agent counts, or percentages.** Config shows
  estimated cost as `TBD until benchmarked`. Home credit balance is a
  placeholder `0` until Phase 5 billing. Results show a metric's
  denominator/method only when the backend supplies them.
- **No fake auth.** Sign-in states plainly that it is not connected
  yet; guest exploration is the working path until Phase 2.

## Backend endpoints used

`GET/POST /api/v1/ideas`, `GET/POST /api/v1/simulations`,
`GET /api/v1/simulations/{id}`, `GET /api/v1/simulations/{id}/events`,
`GET /api/v1/simulations/{id}/results`,
`POST /api/v1/simulations/{id}/cancel`,
`GET/PUT /api/v1/settings`. Simulation creation sends an
`Idempotency-Key` header so retries cannot double-run a job, with
body `{idea_id, audience_preset, audience, mode}` and idea creation
using `price_amount` (int) to match the backend's `IdeaIn` model.

## Next steps (in order)

1. Install Flutter 3.22+ and run `flutter pub get` + `flutter analyze`;
   fix whatever the toolchain reports — do not hand-edit around it.
2. Generate the full Android shell (`flutter create .` equivalents)
   and run on an emulator against a running backend.
3. Wire Phase 2 auth and Phase 3 real engine events end to end before
   any release claim.
