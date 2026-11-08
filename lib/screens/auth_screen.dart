import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      otp = TextEditingController();
  final form = GlobalKey<FormState>();
  bool signup = false, busy = false, verify = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (verify) {
        await auth.verifyOTP(
          email: email.text.trim(),
          token: otp.text.trim(),
          type: OtpType.signup,
        );
      } else if (signup) {
        final result = await auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        if (result.session == null && mounted) {
          setState(() {
            verify = true;
            message =
                'افتح رسالة التأكيد أو أدخل الرمز المرسل إلى بريدك. قد يكون الرابط موجهاً إلى إعداد Site URL الحالي.';
          });
        }
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = userError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.contactless_rounded,
                      size: 58,
                      color: Color(0xFFB7A6FF),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'NFC Studio',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'منصة واحدة. هويات رقمية بلا حدود.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: email,
                      readOnly: verify,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                      validator: (v) => v != null && v.contains('@')
                          ? null
                          : 'أدخل بريداً صالحاً',
                    ),
                    const SizedBox(height: 14),
                    if (!verify)
                      TextFormField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                        ),
                        validator: (v) => (v?.length ?? 0) >= 8
                            ? null
                            : 'ثمانية أحرف على الأقل',
                      ),
                    if (verify)
                      TextFormField(
                        controller: otp,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'رمز التأكيد',
                        ),
                        validator: (v) => (v?.trim().isNotEmpty ?? false)
                            ? null
                            : 'أدخل الرمز',
                      ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(message!),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(
                        busy
                            ? 'جارٍ الاتصال…'
                            : verify
                            ? 'تأكيد الحساب'
                            : signup
                            ? 'إنشاء حساب'
                            : 'تسجيل الدخول',
                      ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              signup = !signup;
                              verify = false;
                              message = null;
                            }),
                      child: Text(
                        signup ? 'لديك حساب؟ تسجيل الدخول' : 'إنشاء حساب جديد',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
