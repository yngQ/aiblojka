---
name: Generated files excluded from git
description: .g.dart files are in .gitignore — never try to git add them, they are generated locally
type: feedback
---

All `*.g.dart` files (build_runner output) are excluded by `.gitignore` line 51. This is intentional — developers run `build_runner` locally.

**Why:** The project treats generated files as build artifacts, not source. Committing them would cause noise and merge conflicts.

**How to apply:** When staging files after build_runner, only `git add` the hand-written source files. Never use `git add -f` to force `.g.dart` into the index.
