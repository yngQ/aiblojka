# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AiBlojka — a Flutter Web PWA for AI-powered video cover generation. Single-page app (no auth) that sends prompts through a Cloudflare Worker proxy to Gemini API. UI language is Russian; prompts to Gemini are in English.

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

**Data flow:** Flutter Web (GitHub Pages) → Cloudflare Worker (proxy, holds API key) → Gemini 2.5 Flash Image API

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
