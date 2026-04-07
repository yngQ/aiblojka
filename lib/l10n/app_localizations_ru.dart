// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'AiBlojka';

  @override
  String get formatLong => 'Длинные видео';

  @override
  String get formatLongSubtitle => 'YouTube 1920×1080';

  @override
  String get formatShort => 'Короткие видео';

  @override
  String get formatShortSubtitle => 'TikTok, Shorts, Reels 1080×1920';

  @override
  String get styleLabel => 'Стиль (необязательно)';

  @override
  String get styleGaming => 'Геймплей';

  @override
  String get styleVlog => 'Влог';

  @override
  String get styleEducation => 'Обучение';

  @override
  String get styleBusiness => 'Бизнес';

  @override
  String get styleEntertainment => 'Развлечения';

  @override
  String get promptLabel => 'Описание обложки';

  @override
  String get promptHint => 'Опишите что хотите получить...';

  @override
  String get referenceLabel => 'Референс (необязательно)';

  @override
  String get referenceButton => 'Загрузить изображение';

  @override
  String get generateButton => 'Сгенерировать';

  @override
  String get downloadButton => 'Скачать';

  @override
  String get regenerateButton => 'Сгенерировать ещё раз';

  @override
  String get errorLimitExceeded =>
      'Лимит генераций исчерпан, попробуйте завтра';

  @override
  String get errorSafetyBlock =>
      'Контент заблокирован фильтром, измените запрос';

  @override
  String get errorServer => 'Ошибка сервера, попробуйте позже';

  @override
  String get errorNetwork => 'Проверьте подключение к интернету';

  @override
  String get errorFileSize => 'Файл должен быть JPEG, PNG или WebP, до 10 МБ';

  @override
  String get generatingLabel => 'Генерация...';

  @override
  String get generatingIndicatorLabel => 'Генерация обложки...';

  @override
  String get noStyleOption => 'Без стиля';

  @override
  String get errorGenerationDisabled =>
      'Генерация временно недоступна, попробуйте позже';

  @override
  String get errorWorkerNotConfigured =>
      'Сервис генерации не настроен, обратитесь к администратору';
}
