import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard.dart';
import 'screens/activation_screen.dart';
import 'screens/device_gate.dart';
import 'core/device_guard.dart';
import 'core/i18n.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Opens the activation screen for a tapmaroc://activate?t=... link.
void _openInvite(String link) {
  final token = DeviceGuard.tokenOf(link);
  if (token == null) return;
  navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => ActivationScreen(token: token)));
}

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
    DeviceGuard.onLink(_openInvite);
    final link = await DeviceGuard.initialLink();
    if (link != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInvite(link));
    }
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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'TapMaroc',
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.dark(),
      home: IntegrityGate(
        child: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            final session = Supabase.instance.client.auth.currentSession;
            return session == null
                ? const AuthScreen()
                // A new key per login: the phone check runs again.
                : DeviceGate(key: ValueKey(session.user.id), child: const Dashboard());
          },
        ),
      ),
    ),
  );
}
