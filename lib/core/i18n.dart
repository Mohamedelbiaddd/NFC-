import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

/// App language: 'ar' (default), 'fr' or 'en'. The whole app rebuilds when it changes.
final appLang = ValueNotifier<String>('ar');

const appLanguages = <String, String>{'ar': 'العربية', 'fr': 'Français', 'en': 'English'};

const _prefKey = 'app_lang';

Future<void> loadAppLang() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && appLanguages.containsKey(saved)) appLang.value = saved;
  } catch (_) {}
}

Future<void> setAppLang(String lang) async {
  if (!appLanguages.containsKey(lang)) return;
  appLang.value = lang;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, lang);
  } catch (_) {}
}

TextDirection get appDirection =>
    appLang.value == 'ar' ? TextDirection.rtl : TextDirection.ltr;

/// Translates an Arabic source string into the current language.
String tr(String ar) {
  final l = appLang.value;
  if (l == 'ar') return ar;
  return (l == 'fr' ? frStrings : enStrings)[ar] ?? ar;
}

/// Like [tr] with positional {0}, {1}… placeholders.
String trf(String ar, List<Object?> args) {
  var s = tr(ar);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

/// Globe button that opens the language menu (Arabic / French / English).
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: tr('اللغة'),
    icon: const Icon(Icons.language_rounded),
    initialValue: appLang.value,
    onSelected: setAppLang,
    itemBuilder: (context) => [
      for (final e in appLanguages.entries)
        CheckedPopupMenuItem<String>(
          value: e.key,
          checked: e.key == appLang.value,
          child: Text(e.value),
        ),
    ],
  );
}
