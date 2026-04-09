I need to analyze the entire conversation history and create a comprehensive project summary in markdown format focusing on the most important context, decisions, and progress for future sessions.# Project Summary

## Overall Goal
Generate a comprehensive QWEN.md context file for the AiBlojka project to serve as instructional reference for future development sessions.

## Key Knowledge
- **Project:** AiBlojka — Flutter Web PWA for AI-powered video cover generation (no auth, single-page)
- **Tech Stack:** Flutter 3.41.2 (via FVM), Dart ^3.11.0, Riverpod (code generation), Firebase (Remote Config + Analytics), Cloudflare Workers (proxy), Workers AI (`@cf/black-forest-labs/flux-2-klein-4b`)
- **Hosting:** GitHub Pages (`https://yngq.github.io/aiblojka`)
- **UI Language:** Russian (default); AI prompts in English
- **Design:** "Solar Amber" dark theme with glow effects (defined in `lib/core/theme/app_colors.dart`)
- **Architecture:** `lib/core/` (services, providers, models, errors, theme) + `lib/features/generation/` (UI + feature state)
- **Key Services:** `GenerationService` (HTTP to Worker), `PromptBuilder`, `RemoteConfigService`, `AnalyticsService`, `HistoryService` (localStorage with FIFO eviction)
- **Supported Formats:** 1920×1080 (YouTube 16:9) and 1080×1920 (TikTok/Shorts/Reels 9:16)
- **Build Commands:** `fvm flutter pub get`, `fvm flutter run -d chrome`, `fvm flutter build web --release`, `fvm dart run build_runner build`
- **Git Workflow:** Feature branches only, never push to main directly, use `gh pr create` for PRs
- **Agent Memory:** `.claude/agent-memory/` files must be committed; `.claude/settings.local.json` stays local
- **MCP Tools:** `context7` (docs lookup), `dart` (test/run/analyze/format)
- **Specialized Agents:** `aiblojka-architect`, `aiblojka-flutter-dev`, `aiblojka-qa-engineer`, `aiblojka-ui-designer`, `flutter-backend-dev`

## Recent Actions
1. **[DONE]** Analyzed project structure — explored `lib/` directory (16 Dart files), localization (Russian `.arb`), Firebase config, PRD.md
2. **[DONE]** Reviewed key source files — `main.dart`, `app_colors.dart`, `generation_service.dart` — confirming Riverpod DI, Solar Amber palette, and typed error handling
3. **[DONE]** Checked git history — recent commits include history persistence, mobile-first PWA redesign, Workers AI multipart support, quota eviction fixes
4. **[DONE]** Generated comprehensive `QWEN.md` file covering: project overview, tech stack, architecture, design system, build/run commands, development conventions, git workflow, key constraints, and available agents/tools

## Current Plan
1. [DONE] Explore and document project context
2. [DONE] Generate QWEN.md as persistent instructional reference
3. [TODO] Await user's next development task

---

## Summary Metadata
**Update time**: 2026-04-09T21:12:48.344Z 
