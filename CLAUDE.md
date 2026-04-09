# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AiBlojka — a Flutter Web PWA for AI-powered video cover generation. Single-page app (no auth) that sends prompts through a Cloudflare Worker proxy to Cloudflare Workers AI. UI language is Russian; prompts to the AI model are in English.

## Development Commands

```bash
# Flutter is managed via FVM (pinned to 3.41.2 in .fvmrc)
fvm flutter run -d chrome          # Run in Chrome
fvm flutter build web --release    # Production build (output: build/web/)
fvm flutter test                   # Run all tests
fvm flutter test test/widget_test.dart  # Run a single test file
fvm flutter analyze                # Static analysis (uses flutter_lints)
fvm flutter pub get                # Install dependencies
```

## Architecture

**Data flow:** Flutter Web (GitHub Pages) → Cloudflare Worker (proxy) → Workers AI (`@cf/black-forest-labs/flux-2-klein-4b`)

**Config & analytics:** Firebase Remote Config (prompt templates, styles, kill switch) + Firebase Analytics → Flutter Web

**State management:** Riverpod with code generation.

**Design:** Dark theme "Solar Amber" with glow effects. Full color palette and requirements in PRD.md.

**Localization:** Russian by default. All user-facing strings go into arb files (intl).

## MCP Tools

- **context7**: Always use `mcp__context7__resolve-library-id` → `mcp__context7__query-docs` to fetch up-to-date documentation for any library/framework before writing code that depends on it (Flutter, Riverpod, Firebase, Cloudflare Workers, etc.). Prefer this over relying on training data.
- **dart**: Use `mcp__dart__*` tools instead of shell commands where possible — for running tests (`run_tests`), analyzing (`analyze_files`), formatting (`dart_format`), launching apps (`launch_app`), hot reload/restart, pub operations, and inspecting widget trees.

## Agent Memory

Agent memory files in `.claude/agent-memory/` **must be committed to git** — they carry cross-session context (API contracts, decisions, constraints) that subagents depend on. After any task that produces or updates memory files, stage and commit them together with the related code changes.

`.claude/settings.local.json` is local-only and should remain out of git.

## Git Workflow

- **NEVER push directly to `main`.** All changes go through feature branches and pull requests.
- Before starting any task, create a new branch from `main`: `git checkout -b <type>/<short-description>` (e.g., `feat/cover-generation`, `fix/proxy-timeout`, `chore/update-deps`).
- Commit often with clear messages.
- When work is complete, push the branch and create a PR into `main` using `gh pr create`.
- Do not use `git push origin main` or `git push --force` to `main` under any circumstances.

## Key Constraints

- Web-only target (PWA)
- See PRD.md for full product requirements, design specs, and prompt structure

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
* **Native-First:** Prefer `ValueNotifier`, `ChangeNotifier`, `ListenableBuilder`.
* **Restrictions:** Do NOT use Riverpod, Bloc, or GetX unless explicitly requested.
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