import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/device_guard.dart';
import '../core/i18n.dart';
import '../core/repository.dart';
import '../core/theme.dart';

/// Message shown on the login screen after the app ended a session.
final authNotice = ValueNotifier<String?>(null);

/// Lets a staff account in only on its approved phone. Another phone waits
/// here until the approved phone (or the manager) accepts it. On the
/// approved phone, new requests pop up for approval.
class DeviceGate extends StatefulWidget {
  const DeviceGate({super.key, required this.child});

  final Widget child;

  @override
  State<DeviceGate> createState() => _DeviceGateState();
}

class _DeviceGateState extends State<DeviceGate> with WidgetsBindingObserver {
  String status = 'checking';
  String? activeModel, error;
  Timer? poll;
  final _shown = <String>{};
  bool _asking = false;

  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hello();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _hello(quiet: true);
  }

  Future<void> _hello({bool quiet = false}) async {
    if (!quiet && status != 'checking') setState(() => status = 'checking');
    try {
      final r = await DeviceGuard.hello(client);
      if (!mounted) return;
      final s = '${r['status']}';
      if (s == 'ended') {
        authNotice.value = tr('انتهت الجلسة على هذا الهاتف لأن هاتفاً آخر أصبح هاتف الحساب.');
        await client.auth.signOut(scope: SignOutScope.local);
        return;
      }
      setState(() {
        status = s;
        activeModel = r['active_model'] as String?;
        error = null;
      });
      _schedule();
      if (s == 'active' && r['exempt'] != true) _askOwnPassword();
    } catch (e) {
      if (!mounted) return;
      // Offline: keep an approved phone working; the server still checks.
      if (status == 'active') return;
      setState(() {
        status = 'error';
        error = userError(e);
      });
    }
  }

  void _schedule() {
    poll?.cancel();
    if (status == 'pending') {
      poll = Timer.periodic(const Duration(seconds: 6), (_) => _hello(quiet: true));
    } else if (status == 'active') {
      _requests();
      poll = Timer.periodic(const Duration(seconds: 45), (_) => _requests());
    }
  }

  bool _passwordAsked = false;

  /// Invited staff: on login, offer to set their own password (can be skipped;
  /// asked again at the next login until they set one).
  Future<void> _askOwnPassword() async {
    final user = client.auth.currentUser;
    if (_passwordAsked || user == null || user.userMetadata?['own_password'] == true) return;
    _passwordAsked = true;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final pass = TextEditingController(), pass2 = TextEditingController();
    final form = GlobalKey<FormState>();
    var busy = false, obscure = true;
    String? err;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          icon: const Icon(Icons.password_rounded, size: 40),
          title: Text(tr('أضف كلمة المرور الخاصة بك')),
          content: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('اختر كلمة مرور لا يعرفها أحد غيرك، واستعملها في كل دخول.'),
                  style: const TextStyle(color: AppColors.muted, height: 1.5)),
              const SizedBox(height: 12),
              TextFormField(
                controller: pass,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: tr('كلمة المرور الجديدة'),
                  suffixIcon: IconButton(
                    onPressed: () => setLocal(() => obscure = !obscure),
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (v) => (v?.length ?? 0) >= 8 ? null : tr('ثمانية أحرف على الأقل'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: pass2,
                obscureText: obscure,
                decoration: InputDecoration(labelText: tr('أعد كتابة كلمة المرور')),
                validator: (v) => v == pass.text ? null : tr('كلمتا المرور غير متطابقتين'),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err!, style: const TextStyle(color: AppColors.danger)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: Text(tr('تخطي'))),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setLocal(() {
                        busy = true;
                        err = null;
                      });
                      try {
                        await client.auth.updateUser(UserAttributes(password: pass.text, data: {'own_password': true}));
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                            backgroundColor: AppColors.success,
                            content: Text(tr('✅ حُفظت كلمة المرور الخاصة بك.')),
                          ));
                        }
                      } catch (e) {
                        setLocal(() {
                          busy = false;
                          err = userError(e);
                        });
                      }
                    },
              child: Text(tr('حفظ')),
            ),
          ],
        ),
      ),
    );
    pass.dispose();
    pass2.dispose();
  }

  /// On the approved phone: another phone asks to use the account.
  Future<void> _requests() async {
    if (_asking) return;
    try {
      final value = await client.rpc('nfc_device_requests');
      if (value is! List || !mounted) return;
      for (final d in value.whereType<Map>()) {
        final id = '${d['id']}';
        if (_shown.contains(id)) continue;
        _shown.add(id);
        _asking = true;
        final approve = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.phonelink_lock_rounded, size: 40),
            title: Text(tr('هاتف آخر يحاول الدخول إلى حسابك')),
            content: Text(trf(
              '{0}\n\nإذا وافقت سيصبح هذا الهاتف الجديد هو هاتف حسابك، وسيُغلق الحساب على هذا الهاتف فوراً.\nإذا لم تكن أنت، اضغط «رفض».',
              ['${d['model'] ?? ''}'],
            )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('رفض'))),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('موافقة'))),
            ],
          ),
        );
        _asking = false;
        if (approve == null) continue;
        await client.rpc('nfc_device_decide', params: {'p_id': id, 'p_approve': approve});
        if (approve) {
          authNotice.value = tr('تم نقل حسابك إلى الهاتف الجديد.');
          await client.auth.signOut(scope: SignOutScope.local);
          return;
        }
      }
    } catch (_) {
      _asking = false;
    }
  }

  Future<void> _signOut() async {
    poll?.cancel();
    await client.auth.signOut(scope: SignOutScope.local);
  }

  Widget _screen({required IconData icon, required String title, required String text, Color? color, List<Widget> actions = const []}) =>
      Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 64, color: color ?? AppColors.primarySoft),
                    const SizedBox(height: 18),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.6)),
                    const SizedBox(height: 22),
                    ...actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'active':
        return widget.child;
      case 'checking':
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case 'pending':
        return _screen(
          icon: Icons.phonelink_lock_rounded,
          title: tr('هذا الحساب مرتبط بهاتف آخر'),
          text: trf(
            'أرسلنا طلب موافقة إلى هاتف الحساب{0}. افتح التطبيق عليه واضغط «موافقة»، أو اطلب من المسؤول السماح بهذا الهاتف.\nبعد الموافقة يُغلق الحساب على الهاتف القديم.',
            [activeModel == null || activeModel!.isEmpty ? '' : ' ($activeModel)'],
          ),
          actions: [
            const LinearProgressIndicator(),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout_rounded), label: Text(tr('تسجيل الخروج'))),
          ],
        );
      case 'blocked':
        return _screen(
          icon: Icons.gpp_bad_rounded,
          color: AppColors.danger,
          title: tr('نسخة غير موثوقة'),
          text: tr('هذه النسخة من التطبيق ليست النسخة الأصلية. نزّل التطبيق من رابط الدعوة الذي أرسله لك المسؤول.'),
          actions: [
            OutlinedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout_rounded), label: Text(tr('تسجيل الخروج'))),
          ],
        );
      default:
        return _screen(
          icon: Icons.cloud_off_rounded,
          color: AppColors.warning,
          title: tr('تعذّر التحقق من الهاتف'),
          text: error ?? tr('تحقق من الاتصال بالإنترنت ثم أعد المحاولة.'),
          actions: [
            FilledButton.icon(onPressed: () => _hello(), icon: const Icon(Icons.refresh_rounded), label: Text(tr('إعادة المحاولة'))),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout_rounded), label: Text(tr('تسجيل الخروج'))),
          ],
        );
    }
  }
}

/// Refuses to run a modified app, a rooted phone or an emulator.
class IntegrityGate extends StatelessWidget {
  const IntegrityGate({super.key, required this.child});

  final Widget child;

  static final _check = DeviceGuard.integrityProblem();

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _check,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final problem = snap.data;
      if (problem == null) return child;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.gpp_bad_rounded, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(problem, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.6)),
            ]),
          ),
        ),
      );
    },
  );
}
