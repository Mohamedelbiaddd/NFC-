import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';
import '../core/repository.dart';
import '../core/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final login = TextEditingController(),
      password = TextEditingController(),
      otp = TextEditingController();
  final form = GlobalKey<FormState>();
  bool signup = false, busy = false, verify = false, obscure = true;
  String? message;

  @override
  void dispose() {
    login.dispose();
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
          email: login.text.trim(),
          token: otp.text.trim(),
          type: OtpType.signup,
        );
      } else if (signup) {
        final result = await auth.signUp(
          email: login.text.trim(),
          password: password.text,
        );
        if (result.session == null && mounted) {
          setState(() {
            verify = true;
            message =
                'أكّد بريدك من الرسالة المرسلة إليك، أو أدخل رمز التأكيد.';
          });
        }
      } else {
        final email = AppConfig.loginEmail(login.text);
        if (email == null) throw const FormatException('أدخل بيانات الدخول.');
        await auth.signInWithPassword(email: email, password: password.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = e is FormatException
              ? e.message
              : e is AuthException && e.message == 'Invalid login credentials'
              ? 'بيانات الدخول غير صحيحة. تحقق من اسم المستخدم وكلمة المرور.'
              : userError(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = verify
        ? 'تأكيد الحساب'
        : signup
        ? 'إنشاء حساب جديد'
        : 'تسجيل الدخول';
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -160,
            right: -120,
            child: _Glow(
              color: AppColors.primary.withValues(alpha: 0.45),
              size: 420,
            ),
          ),
          Positioned(
            bottom: -190,
            left: -140,
            child: _Glow(
              color: AppColors.accent.withValues(alpha: 0.28),
              size: 420,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primarySoft,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.contactless_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'NFC Studio',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 26),
                        TextFormField(
                          controller: login,
                          readOnly: verify,
                          textDirection: TextDirection.ltr,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: signup
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: signup
                                ? 'البريد الإلكتروني'
                                : 'اسم المستخدم أو البريد',
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                            ),
                            helperText: signup
                                ? null
                                : 'عمال الميدان يدخلون باسم المستخدم الذي منحهم المدير.',
                          ),
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (signup || verify) {
                              return text.contains('@') && text.length > 3
                                  ? null
                                  : 'أدخل بريداً إلكترونياً صالحاً';
                            }
                            return text.length >= 3
                                ? null
                                : 'أدخل اسم المستخدم أو البريد';
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!verify)
                          TextFormField(
                            controller: password,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: obscure ? 'إظهار' : 'إخفاء',
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
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
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                            validator: (v) =>
                                (v?.trim().isNotEmpty ?? false)
                                ? null
                                : 'أدخل الرمز',
                          ),
                        if (message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                message!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  verify
                                      ? 'تأكيد الحساب'
                                      : signup
                                      ? 'إنشاء الحساب'
                                      : 'دخول',
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
                            signup
                                ? 'لديك حساب؟ تسجيل الدخول'
                                : 'إنشاء حساب جديد',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}
