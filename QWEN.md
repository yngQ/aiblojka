# QWEN.md — AiBlojka Project Context

## Project Overview

**AiBlojka** is a Flutter Web PWA (Progressive Web App) for AI-powered video cover generation. It's a single-page application (no authentication) that sends user prompts through a Cloudflare Worker proxy to Cloudflare Workers AI (`@cf/black-forest-labs/flux-2-klein-4b`). The UI is in Russian; prompts to the AI model are in English.

**Purpose:** Generate video thumbnails/covers for platforms like YouTube, TikTok, YouTube Shorts, and Instagram Reels using AI image generation.

**Hosting:** GitHub Pages (`https://yngq.github.io/aiblojka`)

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Client | Flutter Web (PWA) |
| Flutter Version | 3.41.2 (managed via FVM, see `.fvmrc`) |
| Dart SDK | ^3.11.0 |
| State Management | Riverpod (with code generation via `riverpod_generator`) |
| API Proxy | Cloudflare Workers |
| AI Model | Workers AI — `@cf/black-forest-labs/flux-2-klein-4b` |
| Configuration | Firebase Remote Config |
| Analytics | Firebase Analytics |
| Hosting | GitHub Pages |
| Linting | `flutter_lints` |
| Localization | `flutter_localizations` + `intl` (Russian default) |

---

## Architecture

### Data Flow

```
Flutter Web (GitHub Pages) → Cloudflare Worker (proxy) → Workers AI (FLUX.2 Klein 4B)
Firebase Remote Config + Analytics → Flutter Web
```

### Project Structure

```
lib/
├── main.dart                          # App entry point, Firebase + Riverpod init
├── firebase_options.dart              # Firebase configuration (auto-generated)
├── l10n/
│   ├── app_ru.arb                     # Russian localization strings
│   ├── app_localizations.dart         # Generated localization base
│   └── app_localizations_ru.dart      # Generated Russian translations
├── core/
│   ├── theme/
│   │   ├── app_colors.dart            # Solar Amber color palette
│   │   └── app_theme.dart             # MaterialApp theme configuration
│   ├── models/
│   │   └── history_entry.dart         # Data models (e.g., history entries)
│   ├── errors/
│   │   └── generation_errors.dart     # Typed exception classes
│   ├── services/
│   │   ├── generation_service.dart    # HTTP client for Cloudflare Worker proxy
│   │   ├── prompt_builder.dart        # Constructs AI prompts from templates
│   │   ├── remote_config_service.dart # Firebase Remote Config wrapper
│   │   ├── analytics_service.dart     # Firebase Analytics event tracking
│   │   └── history_service.dart       # Local history persistence (localStorage)
│   └── providers/
│       └── services_providers.dart    # Riverpod providers for service DI
└── features/
    └── generation/
        ├── providers/
        │   └── generation_provider.dart  # Riverpod state for generation flow
        └── presentation/
            └── generate_page.dart        # Main UI screen
```

### Key Services

- **`GenerationService`**: Sends POST requests to the Cloudflare Worker. Handles HTTP response mapping to typed `GenerationResult` or `GenerationException` subclasses (`QuotaExceededException`, `SafetyBlockException`, `NoImageGeneratedException`, `ServerException`, `NetworkException`).
- **`PromptBuilder`**: Assembles AI prompts from Remote Config templates + user input.
- **`RemoteConfigService`**: Fetches and caches Firebase Remote Config values (prompt templates, platform configs, styles, kill switch).
- **`AnalyticsService`**: Tracks Firebase Analytics events (generation, download, errors).
- **`HistoryService`**: Persists generation history in browser localStorage with FIFO eviction on quota exceeded.

---

## Design System — Solar Amber

### Color Palette

| Role | HEX | Usage |
|------|-----|-------|
| Background | `#0E0C08` | App background |
| Surface | `#181510` | Card/container surfaces |
| Card | `#231F14` | Individual card background |
| Accent | `#FFD54F` | Glow effects, highlights |
| Primary | `#FF8F00` | Primary buttons, active states |
| Text Primary | `#FFF8E1` | Main text |
| Text Secondary | `#A89F91` | Secondary/hint text |
| Disabled | `#3A3530` | Disabled elements |
| Error | `#FF5252` | Error states |

### Design Principles

- Dark theme, minimalism
- Glow effects on accent elements (buttons, loaders, icons)
- Single-screen layout, clean hierarchy
- Mobile-first responsive design

---

## Supported Cover Formats

| Format | Resolution | Aspect Ratio |
|--------|------------|-------------|
| Long video (YouTube) | 1920×1080 | 16:9 |
| Short video (TikTok, Shorts, Reels) | 1080×1920 | 9:16 |

---

## Building and Running

### Prerequisites

- Flutter SDK 3.41.2 (managed by FVM)
- Chrome browser (for web testing)

### Commands

```bash
# Install dependencies
fvm flutter pub get

# Run in Chrome (debug mode)
fvm flutter run -d chrome

# Build for production (output: build/web/)
fvm flutter build web --release

# Run all tests
fvm flutter test

# Run a single test file
fvm flutter test test/widget_test.dart

# Static analysis
fvm flutter analyze

# Generate Riverpod providers (after editing @riverpod-annotated files)
fvm dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
fvm dart run build_runner watch --delete-conflicting-outputs
```

---

## Development Conventions

### State Management

- **Riverpod with code generation** is the sole state management solution.
- Use `@riverpod` / `@Riverpod(keepAlive: true)` annotations on provider-generating functions.
- All providers live in `lib/core/providers/` (services) or co-located with features (`lib/features/*/providers/`).

### Code Style

- **Naming:** `PascalCase` for classes, `camelCase` for members/variables, `snake_case` for files.
- **Imports:** Always use package imports (`always_use_package_imports`).
- **Immutability:** Prefer `const` constructors and immutable data structures.
- **Functions:** Keep under 20 lines, single-purpose.
- **Logging:** Use `dart:developer` `log()` instead of `print()`.
- **Null Safety:** Write sound null-safe code. Avoid `!` unless safety is guaranteed.
- Use `final class` for concrete classes that shouldn't be extended.

### Localization

- All user-facing strings in `lib/l10n/app_ru.arb`.
- Russian is the default locale (`Locale('ru')`).
- Architecture supports adding more locales via additional `.arb` files.
- Access via `AppLocalizations.of(context)!` or `context.l10n`.

### Error Handling

| HTTP Code | Exception | User Message (RU) |
|-----------|-----------|-------------------|
| 429 | `QuotaExceededException` | Лимит генераций исчерпан, попробуйте завтра |
| 451 | `SafetyBlockException` | Контент заблокирован фильтром, измените запрос |
| 422 | `NoImageGeneratedException` | Не удалось сгенерировать обложку |
| 5xx | `ServerException` | Ошибка сервера, попробуйте позже |
| Network | `NetworkException` | Проверьте подключение к интернету |

### Testing

- Widget tests, unit tests, and integration tests supported.
- Test files mirror source structure under `test/`.
- Use mocked HTTP responses for `GenerationService` tests.

---

## Git Workflow

- **NEVER push directly to `main`.** All changes go through feature branches and pull requests.
- Create branches from `main`: `git checkout -b <type>/<short-description>` (e.g., `feat/cover-generation`, `fix/proxy-timeout`).
- Commit often with clear messages.
- Push branches and create PRs via `gh pr create`.
- Agent memory files in `.claude/agent-memory/` **must be committed to git**.
- `.claude/settings.local.json` is local-only — keep out of git.

---

## Key Constraints

- **Web-only target (PWA)** — no iOS/Android/Desktop builds
- **No authentication** — single-page app, no user accounts
- **Free tier limits** — Workers AI: 10,000 Neurons/day (~91 images), Cloudflare: 100,000 requests/day
- **Reference images** — up to 10 MB (JPEG, PNG, WebP), sent as base64 inline data
- **CORS** — Worker only accepts requests from `https://yngq.github.io`

---

## MCP Tools Available

- **`context7`**: Use `resolve-library-id` → `query-docs` to fetch up-to-date documentation for any library/framework (Flutter, Riverpod, Firebase, Cloudflare Workers, etc.).
- **`dart`**: Use `mcp__dart__*` tools for tests (`run_tests`), analysis (`analyze_files`), formatting (`dart_format`), launching apps (`launch_app`), hot reload/restart, pub operations, and widget tree inspection.

---

## Specialized Agents

For complex tasks, delegate to specialized agents:

| Agent | Use For |
|-------|---------|
| `aiblojka-architect` | Architectural guidance, structural decisions, codebase exploration |
| `aiblojka-flutter-dev` | Implementing Flutter code — business logic, Riverpod providers, services, UI widgets, localization |
| `aiblojka-qa-engineer` | Writing tests (widget, unit, integration) for new code |
| `aiblojka-ui-designer` | Visual layer — Solar Amber theme, glow effects, animations, responsive layouts, PWA assets |
| `flutter-backend-dev` | Backend work — Cloudflare Worker, Workers AI, Firebase Remote Config, API design |

# AI Rules for Flutter

You are an expert Flutter and Dart developer. Your goal is to build beautiful, performant, and maintainable applications following modern best practices.

## Interaction Guidelines
* **User Persona:** Assume the user is familiar with programming concepts but may be new to Dart.
* **Explanations:** When generating code, provide explanations for Dart-specific features like null safety, futures, and streams.
* **Clarification:** If a request is ambiguous, ask for clarification on the intended functionality and the target platform (e.g., command-line, web, server).
* **Dependencies:** When suggesting new dependencies from `pub.dev`, explain their benefits. Use `pub_dev_search` if available.
* **Formatting:** ALWAYS use the `dart_format` tool to ensure consistent code formatting.
* **Fixes:** Use the `dart_fix` tool to automatically fix many common errors.
* **Linting:** Use the Dart linter with `flutter_lints` to catch common issues.

## Flutter Style Guide
* **SOLID Principles:** Apply SOLID principles throughout the codebase.
* **Concise and Declarative:** Write concise, modern, technical Dart code. Prefer functional and declarative patterns.
* **Composition over Inheritance:** Favor composition for building complex widgets and logic.
* **Immutability:** Prefer immutable data structures. Widgets (especially `StatelessWidget`) should be immutable.
* **State Management:** Separate ephemeral state and app state. Use a state management solution for app state.
* **Widgets are for UI:** Everything in Flutter's UI is a widget. Compose complex UIs from smaller, reusable widgets.

## Package Management
* **Pub Tool:** Use `pub` or `flutter pub add`.
* **Dev Dependencies:** Use `flutter pub add dev:<package>`.
* **Overrides:** Use `flutter pub add override:<package>:<version>`.
* **Removal:** `dart pub remove <package>`.

## Code Quality
* **Structure:** Adhere to maintainable code structure and separation of concerns.
* **Naming:** Avoid abbreviations. Use `PascalCase` (classes), `camelCase` (members), `snake_case` (files).
* **Conciseness:** Functions should be short (<20 lines) and single-purpose.
* **Error Handling:** Anticipate and handle potential errors. Don't let code fail silently.
* **Logging:** Use `dart:developer` `log` instead of `print`.

## Dart Best Practices
* **Effective Dart:** Follow official guidelines.
* **Async/Await:** Use `Future`, `async`, `await` for operations. Use `Stream` for events.
* **Null Safety:** Write sound null-safe code. Avoid `!` operator unless guaranteed.
* **Pattern Matching:** Use switch expressions and pattern matching.
* **Records:** Use records for multiple return values.
* **Exception Handling:** Use custom exceptions for specific situations.
* **Arrow Functions:** Use `=>` for one-line functions.

## Flutter Best Practices
* **Immutability:** Widgets are immutable. Rebuild, don't mutate.
* **Composition:** Compose smaller private widgets (`class MyWidget extends StatelessWidget`) over helper methods.
* **Lists:** Use `ListView.builder` or `SliverList` for performance.
* **Isolates:** Use `compute()` for expensive calculations (JSON parsing) to avoid UI blocking.
* **Const:** Use `const` constructors everywhere possible to reduce rebuilds.
* **Build Methods:** Avoid expensive ops (network) in `build()`.

## State Management
* **This project uses Riverpod** (explicitly requested). Use `@riverpod` / `@Riverpod(keepAlive: true)` with code generation for all app state.
* **Native-First (non-Riverpod projects):** Prefer `ValueNotifier`, `ChangeNotifier`, `ListenableBuilder`.
* **ChangeNotifier:** For state that is more complex or shared across multiple widgets, use `ChangeNotifier`.
* **MVVM:** When a more robust solution is needed, structure the app using the Model-View-ViewModel (MVVM) pattern.
* **Dependency Injection:** Use simple manual constructor dependency injection to make a class's dependencies explicit in its API, and to manage dependencies between different layers of the application.

```dart
// Simple Local State
final ValueNotifier<int> _counter = ValueNotifier<int>(0);
ValueListenableBuilder<int>(
  valueListenable: _counter,
  builder: (context, value, child) => Text('Count: $value'),
);
```

## Routing (GoRouter)
Use `go_router` for all navigation needs (deep linking, web). Ensure users are redirected to login when unauthorized.

```dart
final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'details/:id',
          builder: (context, state) {
            final String id = state.pathParameters['id']!;
            return DetailScreen(id: id);
          },
        ),
      ],
    ),
  ],
);
MaterialApp.router(routerConfig: _router);
```

## Data Handling & Serialization
* **JSON:** Use `json_serializable` and `json_annotation`.
* **Naming:** Use `fieldRename: FieldRename.snake` for consistency.

```dart
@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  final String firstName;
  final String lastName;
  User({required this.firstName, required this.lastName});
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

## Visual Design & Theming (Material 3)
* **Visual Design:** Build beautiful and intuitive user interfaces that follow modern design guidelines.
* **Typography:** Stress and emphasize font sizes to ease understanding, e.g., hero text, section headlines.
* **Background:** Apply subtle noise texture to the main background to add a premium, tactile feel.
* **Shadows:** Multi-layered drop shadows create a strong sense of depth; cards have a soft, deep shadow to look "lifted."
* **Icons:** Incorporate icons to enhance the user’s understanding and the logical navigation of the app.
* **Interactive Elements:** Buttons, checkboxes, sliders, lists, charts, graphs, and other interactive elements have a shadow with elegant use of color to create a "glow" effect.
* **Centralized Theme:** Define a centralized `ThemeData` object to ensure a consistent application-wide style.
* **Light and Dark Themes:** Implement support for both light and dark themes using `theme` and `darkTheme`.
* **Color Scheme Generation:** Generate harmonious color palettes from a single color using `ColorScheme.fromSeed`.

```dart
final ThemeData lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.outfitTextTheme(),
);
```

## Layout Best Practices
* **Expanded:** Use to make a child widget fill the remaining available space along the main axis.
* **Flexible:** Use when you want a widget to shrink to fit, but not necessarily grow. Don't combine `Flexible` and `Expanded` in the same `Row` or `Column`.
* **Wrap:** Use when you have a series of widgets that would overflow a `Row` or `Column`, and you want them to move to the next line.
* **SingleChildScrollView:** Use when your content is intrinsically larger than the viewport, but is a fixed size.
* **ListView / GridView:** For long lists or grids of content, always use a builder constructor (`.builder`).
* **FittedBox:** Use to scale or fit a single child widget within its parent.
* **LayoutBuilder:** Use for complex, responsive layouts to make decisions based on the available space.
* **Positioned:** Use to precisely place a child within a `Stack` by anchoring it to the edges.
* **OverlayPortal:** Use to show UI elements (like custom dropdowns or tooltips) "on top" of everything else.

```dart
// Network Image with Error Handler
Image.network(
  'https://example.com/img.png',
  errorBuilder: (ctx, err, stack) => const Icon(Icons.error),
  loadingBuilder: (ctx, child, prog) => prog == null ? child : const CircularProgressIndicator(),
);
```

## Documentation Philosophy
* **Comment wisely:** Use comments to explain why the code is written a certain way, not what the code does. The code itself should be self-explanatory.
* **Document for the user:** Write documentation with the reader in mind. If you had a question and found the answer, add it to the documentation where you first looked.
* **No useless documentation:** If the documentation only restates the obvious from the code's name, it's not helpful.
* **Consistency is key:** Use consistent terminology throughout your documentation.
* **Use `///` for doc comments:** This allows documentation generation tools to pick them up.
* **Start with a single-sentence summary:** The first sentence should be a concise, user-centric summary ending with a period.
* **Avoid redundancy:** Don't repeat information that's obvious from the code's context, like the class name or signature.
* **Public APIs are a priority:** Always document public APIs.

## Accessibility
* **Contrast:** Ensure text has a contrast ratio of at least **4.5:1** against its background.
* **Dynamic Text Scaling:** Test your UI to ensure it remains usable when users increase the system font size.
* **Semantic Labels:** Use the `Semantics` widget to provide clear, descriptive labels for UI elements.
* **Screen Reader Testing:** Regularly test your app with TalkBack (Android) and VoiceOver (iOS).

## Analysis Options
Strictly follow `flutter_lints`.

```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    avoid_print: true
    prefer_single_quotes: true
    always_use_package_imports: true
```