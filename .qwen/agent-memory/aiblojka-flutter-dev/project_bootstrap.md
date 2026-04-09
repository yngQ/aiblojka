---
name: Project Bootstrap Decisions
description: Key non-obvious decisions made during initial project setup that affect future work
type: project
---

Локализация настроена через `l10n.yaml` в корне проекта с `template-arb-file: app_ru.arb` (не `app_en.arb`), потому что UI только русский. Без этого файла `flutter gen-l10n` падает с ошибкой о несуществующем `app_en.arb`.

**Why:** Проект русскоязычный, английский ARB не нужен. `l10n.yaml` переопределяет дефолтное поведение Flutter.

**How to apply:** При добавлении новых строк локализации — только в `lib/l10n/app_ru.arb`. После изменения ARB запускать `fvm flutter gen-l10n` (не `build_runner`).

---

Firebase инициализируется в `main()` с заглушкой `FirebaseOptions` и обёрнута в `try/catch`. Без реального `google-services.json` / `firebase_options.dart` Firebase бросает исключение, но приложение продолжает работать.

**Why:** Firebase-конфиг будет подключён позже отдельным PR. Заглушка позволяет запускать приложение в dev без Firebase.

**How to apply:** Когда придёт время подключать Firebase — заменить `FirebaseOptions` на сгенерированный `DefaultFirebaseOptions.currentPlatform` из `firebase_options.dart`.

---

`test/widget_test.dart` переписан с нуля — бойлерплейт counter-теста удалён, заменён на smoke-тест `GeneratePage`.
