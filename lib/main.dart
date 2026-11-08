import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard.dart';
import 'core/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAppLang();
  if (AppConfig.supabaseUrl.isEmpty || AppConfig.publishableKey.isEmpty) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              tr('شغّل: flutter run --dart-define-from-file=config.json'),
            ),
          ),
        ),
      ),
    );
    return;
  }
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.publishableKey,
    );
    runApp(const NfcStudio());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text(trf('فشل بدء الاتصال: {0}', [e])))),
      ),
    );
  }
}

class NfcStudio extends StatelessWidget {
  const NfcStudio({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: appLang,
    builder: (context, lang, _) => MaterialApp(
      key: ValueKey(lang),
      debugShowCheckedModeBanner: false,
      title: 'NFC Studio',
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.dark(),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) =>
            Supabase.instance.client.auth.currentSession == null
            ? const AuthScreen()
            : const Dashboard(),
      ),
    ),
  );
}
