import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/device_guard.dart';
import '../core/i18n.dart';
import '../core/repository.dart';
import '../core/theme.dart';

/// Activates a staff account from its invitation: the link (opened from the
/// e-mail) or the e-mail address + 8-character code. The person chooses
/// their own password; this phone becomes the account's only phone.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key, this.token});

  final String? token;

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), code = TextEditingController();
  final pass = TextEditingController(), pass2 = TextEditingController();
  bool busy = false, obscure = true, checking = false;
  String? message, name, invitedEmail;

  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) _check();
  }

  @override
  void dispose() {
    for (final c in [email, code, pass, pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _who() => widget.token != null
      ? {'token': widget.token}
      : {'email': email.text.trim().toLowerCase(), 'code': code.text.trim()};

  static String _state(String? s) => switch (s) {
    'expired' => tr('انتهت صلاحية الدعوة (24 ساعة). اطلب رابطاً جديداً من المسؤول.'),
    'used' => tr('هذه الدعوة استُعملت من قبل. سجّل الدخول بكلمة مرورك، أو اطلب رابطاً جديداً.'),
    'revoked' => tr('هذه الدعوة أُلغيت أو استُبدلت برابط أحدث. افتح آخر رسالة وصلتك.'),
    'locked' => tr('محاولات خاطئة كثيرة. اطلب رابطاً جديداً من المسؤول.'),
    'bad_code' => tr('البريد أو رمز التفعيل غير صحيح.'),
    'weak_password' => tr('كلمة المرور قصيرة: ثمانية أحرف على الأقل.'),
    _ => tr('الدعوة غير موجودة. تحقق من الرابط أو الرمز.'),
  };

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final res = await client.functions.invoke('staff-activate', body: body);
    final data = res.data;
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<void> _check() async {
    setState(() => checking = true);
    try {
      final r = await _call({'action': 'check', ..._who()});
      if (!mounted) return;
      setState(() {
        if (r['state'] == 'ok') {
          name = '${r['name'] ?? ''}';
          invitedEmail = '${r['email'] ?? ''}';
          message = null;
        } else {
          message = _state('${r['state']}');
        }
      });
    } catch (e) {
      if (mounted) setState(() => message = userError(e));
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _activate() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final device = await DeviceGuard.info();
      final r = await _call({
        'action': 'activate',
        ..._who(),
        'password': pass.text,
        'device': device.toJson(),
      });
      if (r['state'] != 'activated' || r['refresh_token'] == null) {
        if (mounted) setState(() => message = _state('${r['state']}'));
        return;
      }
      if (client.auth.currentSession != null) {
        await client.auth.signOut(scope: SignOutScope.local);
      }
      await client.auth.setSession('${r['refresh_token']}');
      // The password was chosen by the person: no "set your password" prompt.
      try {
        await client.auth.updateUser(UserAttributes(data: {'own_password': true}));
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text(tr('✅ تم تفعيل حسابك. هذا الهاتف هو هاتف حسابك.')),
      ));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => message = userError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byLink = widget.token != null;
    return Scaffold(
      appBar: AppBar(title: Text(tr('تفعيل الحساب'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SurfaceCard(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 46, color: AppColors.primarySoft),
                    const SizedBox(height: 10),
                    Text(
                      name != null && name!.isNotEmpty ? trf('مرحباً {0} 👋', [name]) : tr('مرحباً 👋'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('اختر كلمة المرور الخاصة بك. لا أحد غيرك يعرفها، والحساب سيعمل على هذا الهاتف فقط.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, height: 1.5),
                    ),
                    if (invitedEmail != null && invitedEmail!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(invitedEmail!, textAlign: TextAlign.center, textDirection: TextDirection.ltr),
                    ],
                    const SizedBox(height: 18),
                    if (checking) const LinearProgressIndicator(),
                    if (!byLink) ...[
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: tr('البريد الإلكتروني'),
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) => (v ?? '').contains('@') ? null : tr('أدخل بريداً إلكترونياً صالحاً'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: code,
                        textDirection: TextDirection.ltr,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: tr('رمز التفعيل (في الرسالة)'),
                          hintText: 'ABCD-EFGH',
                          prefixIcon: const Icon(Icons.pin_outlined),
                        ),
                        validator: (v) => (v ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length == 8
                            ? null
                            : tr('الرمز من 8 أحرف'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: pass,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: tr('كلمة المرور الجديدة'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (v) => (v?.length ?? 0) >= 8 ? null : tr('ثمانية أحرف على الأقل'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pass2,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: tr('أعد كتابة كلمة المرور'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (v) => v == pass.text ? null : tr('كلمتا المرور غير متطابقتين'),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 14),
                      Text(message!, style: const TextStyle(color: AppColors.danger, height: 1.5)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: busy ? null : _activate,
                      icon: busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check_rounded),
                      label: Text(tr('تفعيل الحساب')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
