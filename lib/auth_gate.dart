import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_localizations.dart';

/// Shows the app only when Supabase has an authenticated session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.signedInChild});

  final Widget signedInChild;

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        return auth.currentSession == null
            ? const EmailAuthScreen()
            : signedInChild;
      },
    );
  }
}

/// Email/password sign-in and sign-up screen for Supabase Auth.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isSubmitting = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    final s = context.strings;
    final email = _emailController.text.trim().toLowerCase();
    try {
      if (_isRegistering) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: _passwordController.text,
        );
        // With email confirmation disabled, Supabase returns a session right
        // away. This app intentionally requires a separate sign-in step.
        if (response.session != null) {
          await Supabase.instance.client.auth.signOut();
        }
        if (!mounted) return;
        setState(() {
          _isError = false;
          _isRegistering = false;
          _passwordController.clear();
          _message = response.session == null
              ? s.t(
                  'Tài khoản đã tạo nhưng cần xác nhận email. Hãy tắt Confirm email trong Supabase để dùng email demo.',
                  'Account created but email confirmation is required. Turn off Confirm email in Supabase for demo emails.',
                )
              : s.t(
                  'Đăng ký thành công. Hãy đăng nhập để tiếp tục.',
                  'Registration successful. Please sign in to continue.',
                );
        });
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = s.t(
          'Không thể kết nối với Supabase. Vui lòng thử lại.',
          'Unable to connect to Supabase. Please try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final languageController = AppLanguageScope.controllerOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => languageController.changeTo(
                          s.isEnglish
                              ? AppLanguage.vietnamese
                              : AppLanguage.english,
                        ),
                        icon: const Icon(Icons.language_rounded),
                        label: Text(s.isEnglish ? 'Tiếng Việt' : 'English'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(
                        Icons.smart_toy_rounded,
                        size: 38,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isRegistering
                          ? s.t('Tạo tài khoản', 'Create an account')
                          : s.t('Chào mừng trở lại', 'Welcome back'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegistering
                          ? s.t(
                              'Đăng ký để lưu hành trình hướng nghiệp của bạn.',
                              'Sign up to save your career guidance journey.',
                            )
                          : s.t(
                              'Đăng nhập để tiếp tục với trợ lý hướng nghiệp AI.',
                              'Sign in to continue with your AI career assistant.',
                            ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: s.t('Email', 'Email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        final emailPattern = RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        );
                        if (!emailPattern.hasMatch(email)) {
                          return s.t(
                            'Nhập email hợp lệ.',
                            'Enter a valid email.',
                          );
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: [
                        _isRegistering
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: s.t('Mật khẩu', 'Password'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return s.t(
                            'Mật khẩu cần ít nhất 6 ký tự.',
                            'Password must have at least 6 characters.',
                          );
                        }
                        return null;
                      },
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isError
                              ? const Color(0xFFB42318)
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isRegistering
                                  ? s.t('Đăng ký', 'Sign up')
                                  : s.t('Đăng nhập', 'Sign in'),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                              _isRegistering = !_isRegistering;
                              _message = null;
                            }),
                      child: Text(
                        _isRegistering
                            ? s.t(
                                'Đã có tài khoản? Đăng nhập',
                                'Already have an account? Sign in',
                              )
                            : s.t(
                                'Chưa có tài khoản? Đăng ký',
                                'No account yet? Sign up',
                              ),
                      ),
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
